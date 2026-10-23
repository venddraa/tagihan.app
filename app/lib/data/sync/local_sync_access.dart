import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:tagihan_vendra/data/local/app_database.dart';
import 'package:tagihan_vendra/data/sync/sync_credential_store.dart';
import 'package:tagihan_vendra/data/sync/sync_http.dart';

bool isLocalSyncBaseUri(Uri uri) =>
    uri.scheme == 'http' &&
    (uri.host == '127.0.0.1' || uri.host == 'localhost' || uri.host == '::1') &&
    (uri.path.isEmpty || uri.path == '/') &&
    uri.userInfo.isEmpty &&
    !uri.hasQuery &&
    !uri.hasFragment;

bool isDeviceCredential(String credential) {
  if (!RegExp(r'^[A-Za-z0-9_-]{43}$').hasMatch(credential)) return false;
  try {
    final bytes = base64Url.decode('$credential=');
    return bytes.length == 32 &&
        base64Url.encode(bytes).replaceAll('=', '') == credential;
  } on FormatException {
    return false;
  }
}

// Satu instance per coordinator; semua persiapan dilakukan saat user meminta sync.
final class LocalSyncAccess {
  LocalSyncAccess({
    required this.database,
    required this.serviceBaseUri,
    required this.adminBaseUri,
    required this.credentials,
    Future<String> Function()? readAdminCredential,
    SyncHTTPRequest? request,
  }) : _readAdminCredential = readAdminCredential ?? readLocalAdminCredential,
       _request = request ?? requestSyncJSONWithDartIO;

  final AppDatabase database;
  final Uri serviceBaseUri;
  final Uri adminBaseUri;
  final SyncCredentialStore credentials;
  final Future<String> Function() _readAdminCredential;
  final SyncHTTPRequest _request;
  String? _deviceCredential;

  void _validateConfiguration() {
    if (!isLocalSyncBaseUri(serviceBaseUri) ||
        !isLocalSyncBaseUri(adminBaseUri)) {
      throw const SyncAuthorizationException(
        'Sync jaringan belum diaktifkan. Gunakan hub localhost sampai pairing tersedia.',
      );
    }
  }

  Future<void> prepare() async {
    _validateConfiguration();
    if (_deviceCredential != null) return;
    final adminToken = await _readAdminCredential();
    if (!isDeviceCredential(adminToken)) {
      throw const SyncAuthorizationException(
        'File credential admin tidak valid. Periksa Go sync service.',
      );
    }
    final state = await database.getLocalSyncState();
    var credential = await credentials.read(
      serviceBaseUri.origin,
      state.deviceId.value,
    );
    if (credential == null) {
      final random = Random.secure();
      credential = base64Url
          .encode(List.generate(32, (_) => random.nextInt(256)))
          .replaceAll('=', '');
      // Simpan dahulu agar retry sesudah response hilang memakai token yang sama.
      await credentials.write(
        serviceBaseUri.origin,
        state.deviceId.value,
        credential,
      );
    }
    if (!isDeviceCredential(credential)) {
      throw const SyncAuthorizationException(
        'Credential keyring tidak valid. Registrasi ulang perlu dilakukan secara eksplisit.',
      );
    }
    final response = await _request(
      adminBaseUri.resolve('/v1/admin/devices'),
      method: 'POST',
      headers: {HttpHeaders.authorizationHeader: 'Bearer $adminToken'},
      body: jsonEncode({
        'protocol_version': 1,
        'device_id': state.deviceId.value,
        'name': 'Fedora',
        'credential': credential,
      }),
    );
    checkSyncAuthorization(response);
    if (response.statusCode == HttpStatus.conflict) {
      throw const SyncAuthorizationException(
        'Perangkat sudah memakai credential lain atau akses telah dicabut. Credential tidak diganti otomatis.',
      );
    }
    if (response.statusCode != HttpStatus.ok &&
        response.statusCode != HttpStatus.created) {
      throw const SyncUnavailableException(
        'Registrasi perangkat lokal belum dapat diproses.',
      );
    }
    try {
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final device = decoded['device'] as Map<String, dynamic>;
      if (decoded['protocol_version'] != 1 ||
          device['device_id'] != state.deviceId.value ||
          device['revoked_at'] != null) {
        throw const FormatException();
      }
    } on Object {
      throw const SyncProtocolException(
        'Response registrasi perangkat tidak valid.',
      );
    }
    _deviceCredential = credential;
  }

  Future<SyncHTTPResponse> get(Uri uri) => _send(uri, method: 'GET');
  Future<SyncHTTPResponse> post(Uri uri, String body) =>
      _send(uri, method: 'POST', body: body);

  Future<SyncHTTPResponse> _send(
    Uri uri, {
    required String method,
    String? body,
  }) async {
    _validateConfiguration();
    if (uri.origin != serviceBaseUri.origin ||
        uri.userInfo.isNotEmpty ||
        uri.hasFragment) {
      throw const SyncAuthorizationException(
        'Tujuan sync tidak sesuai konfigurasi hub.',
      );
    }
    await prepare();
    var endpoint = uri;
    var token = _deviceCredential!;
    if (uri.path == '/v1/sync/bootstrap') {
      endpoint = adminBaseUri.resolve('/v1/sync/bootstrap');
      token = await _readAdminCredential();
      if (!isDeviceCredential(token)) throw const SyncAuthorizationException();
    }
    final response = await _request(
      endpoint,
      method: method,
      body: body,
      headers: {HttpHeaders.authorizationHeader: 'Bearer $token'},
    );
    checkSyncAuthorization(response);
    return response;
  }
}

Future<String> readLocalAdminCredential() async {
  const configured = String.fromEnvironment('TAGIHAN_SYNC_ADMIN_TOKEN_FILE');
  final dataDirectory = Platform.environment['XDG_DATA_HOME'];
  final userHomeDirectory = Platform.environment['HOME'];
  if (configured.isEmpty &&
      (dataDirectory == null || dataDirectory.isEmpty) &&
      (userHomeDirectory == null || userHomeDirectory.isEmpty)) {
    throw const SyncAuthorizationException(
      'Lokasi credential admin tidak ditemukan.',
    );
  }
  final base = dataDirectory != null && dataDirectory.isNotEmpty
      ? dataDirectory
      : '$userHomeDirectory/.local/share';
  final file = File(
    configured.isNotEmpty
        ? configured
        : '$base/tagihan-vendra/sync/admin.token',
  );
  try {
    final type = await FileSystemEntity.type(file.path, followLinks: false);
    final stat = await file.stat();
    if (type != FileSystemEntityType.file ||
        stat.mode & 0x1ff != 0x180 ||
        stat.size != 43) {
      throw const SyncAuthorizationException(
        'Permission file credential admin harus 0600.',
      );
    }
    return await file.readAsString();
  } on FileSystemException {
    throw const SyncAuthorizationException(
      'Credential admin belum tersedia. Jalankan Go sync service terbaru dahulu.',
    );
  }
}
