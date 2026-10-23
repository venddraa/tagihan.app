import 'dart:convert';
import 'dart:io';

import 'package:tagihan_vendra/data/sync/local_sync_access.dart';
import 'package:tagihan_vendra/data/sync/sync_http.dart';

final _pairingID = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-7[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
);

bool isPrivateHTTPSUri(Uri uri) {
  if (uri.scheme != 'https' ||
      uri.userInfo.isNotEmpty ||
      uri.hasQuery ||
      uri.hasFragment ||
      (uri.path.isNotEmpty && uri.path != '/') ||
      uri.port < 1) {
    return false;
  }
  final address = InternetAddress.tryParse(uri.host);
  if (address == null) return false;
  if (address.isLoopback) return true;
  final bytes = address.rawAddress;
  if (bytes.length == 4) {
    return bytes[0] == 10 ||
        (bytes[0] == 172 && bytes[1] >= 16 && bytes[1] <= 31) ||
        (bytes[0] == 192 && bytes[1] == 168);
  }
  return bytes.length == 16 && bytes[0] & 0xfe == 0xfc;
}

final class PairingInvitation {
  PairingInvitation.fromJson(Map<String, dynamic> json)
    : hubId = json['hub_id'] as String,
      endpoint = Uri.parse(json['endpoint'] as String),
      fingerprint = json['certificate_sha256'] as String,
      id = json['invitation_id'] as String,
      token = json['invitation_token'] as String,
      expiresAt = DateTime.parse(json['expires_at'] as String) {
    if (json['protocol_version'] != 1 ||
        !_pairingID.hasMatch(hubId) ||
        !_pairingID.hasMatch(id) ||
        !isPrivateHTTPSUri(endpoint) ||
        !RegExp(r'^[0-9a-f]{64}$').hasMatch(fingerprint) ||
        !isDeviceCredential(token)) {
      throw const FormatException('Undangan pairing tidak valid.');
    }
  }

  factory PairingInvitation.fromCode(String code) {
    const prefix = 'tagihan-pairing-v1:';
    final trimmed = code.trim();
    if (!trimmed.startsWith(prefix) || trimmed.length > 4096) {
      throw const FormatException('Format undangan tidak dikenali.');
    }
    try {
      final payload = utf8.decode(
        base64Url.decode(base64Url.normalize(trimmed.substring(prefix.length))),
      );
      return PairingInvitation.fromJson(
        (jsonDecode(payload) as Map).cast<String, dynamic>(),
      );
    } on Object {
      throw const FormatException('Isi undangan pairing tidak valid.');
    }
  }

  final String hubId;
  final Uri endpoint;
  final String fingerprint;
  final String id;
  final String token;
  final DateTime expiresAt;

  String get code =>
      'tagihan-pairing-v1:${base64Url.encode(utf8.encode(jsonEncode({'protocol_version': 1, 'hub_id': hubId, 'endpoint': endpoint.toString(), 'certificate_sha256': fingerprint, 'invitation_id': id, 'invitation_token': token, 'expires_at': expiresAt.toUtc().toIso8601String()}))).replaceAll('=', '')}';
}

final class PairingRequestEntry {
  PairingRequestEntry.fromJson(Map<String, dynamic> json)
    : id = json['request_id'] as String,
      deviceId = json['device_id'] as String,
      name = json['name'] as String,
      status = json['status'] as String,
      expiresAt = DateTime.parse(json['expires_at'] as String) {
    if (!_pairingID.hasMatch(id) ||
        !_pairingID.hasMatch(deviceId) ||
        !{
          'pending',
          'approving',
          'approved',
          'rejected',
          'expired',
          'cancelled',
        }.contains(status)) {
      throw const FormatException();
    }
  }
  final String id, deviceId, name, status;
  final DateTime expiresAt;
}

final class HubDeviceEntry {
  HubDeviceEntry.fromJson(Map<String, dynamic> json)
    : id = json['device_id'] as String,
      name = json['name'] as String,
      revoked = json['revoked_at'] != null {
    if (!_pairingID.hasMatch(id)) throw const FormatException();
  }
  final String id, name;
  final bool revoked;
}

final class PairingOverview {
  const PairingOverview({
    required this.enabled,
    required this.endpoint,
    required this.requests,
    required this.devices,
    this.activeInvitationId,
  });
  final bool enabled;
  final String? endpoint;
  final List<PairingRequestEntry> requests;
  final List<HubDeviceEntry> devices;
  final String? activeInvitationId;
}

final class PairingAdminClient {
  PairingAdminClient({
    Uri? baseUri,
    Future<String> Function()? readCredential,
    SyncHTTPRequest? request,
  }) : _baseUri =
           baseUri ??
           Uri.parse(
             const String.fromEnvironment(
               'TAGIHAN_SYNC_ADMIN_URL',
               defaultValue: 'http://127.0.0.1:8788',
             ),
           ),
       _readCredential = readCredential ?? readLocalAdminCredential,
       _request = request ?? requestSyncJSONWithDartIO;
  final Uri _baseUri;
  final Future<String> Function() _readCredential;
  final SyncHTTPRequest _request;

  Future<PairingOverview> refresh() async {
    final pairing = await _call('/v1/admin/pairing');
    final devices = await _call('/v1/admin/devices');
    try {
      final info = pairing['info'] as Map;
      return PairingOverview(
        activeInvitationId:
            (pairing['active_invitation'] as Map?)?['invitation_id'] as String?,
        enabled: info['enabled'] as bool,
        endpoint: info['endpoint'] as String?,
        requests: (pairing['requests'] as List)
            .map((value) => PairingRequestEntry.fromJson((value as Map).cast()))
            .toList(),
        devices: (devices['devices'] as List)
            .map((value) => HubDeviceEntry.fromJson((value as Map).cast()))
            .toList(),
      );
    } on Object {
      throw const SyncProtocolException(
        'Daftar perangkat dari hub tidak valid.',
      );
    }
  }

  Future<PairingInvitation> createInvitation() async {
    final response = await _call(
      '/v1/admin/pairing/invitations',
      method: 'POST',
    );
    try {
      return PairingInvitation.fromJson((response['invitation'] as Map).cast());
    } on Object {
      throw const SyncProtocolException('Undangan dari hub tidak valid.');
    }
  }

  Future<void> decide(String id, {required bool approve}) async {
    _validateID(id);
    await _call(
      '/v1/admin/pairing/requests/$id/${approve ? 'approve' : 'reject'}',
      method: 'POST',
    );
  }

  Future<void> cancel(String id) async {
    _validateID(id);
    await _call('/v1/admin/pairing/invitations/$id/cancel', method: 'POST');
  }

  Future<void> revoke(String id) async {
    _validateID(id);
    await _call('/v1/admin/devices/$id/revoke', method: 'POST');
  }

  void _validateID(String id) {
    if (!_pairingID.hasMatch(id)) {
      throw const SyncProtocolException(
        'Identitas perangkat/request tidak valid.',
      );
    }
  }

  Future<Map<String, dynamic>> _call(
    String path, {
    String method = 'GET',
  }) async {
    if (!isLocalSyncBaseUri(_baseUri)) {
      throw const SyncAuthorizationException(
        'Kontrol admin harus melalui localhost.',
      );
    }
    final token = await _readCredential();
    if (!isDeviceCredential(token)) throw const SyncAuthorizationException();
    final response = await _request(
      _baseUri.resolve(path),
      method: method,
      body: method == 'POST' ? '{}' : null,
      headers: {HttpHeaders.authorizationHeader: 'Bearer $token'},
    );
    checkSyncAuthorization(response);
    if (response.statusCode == 409 || response.statusCode == 410) {
      throw const SyncProtocolException(
        'Request sudah berubah atau kedaluwarsa. Perbarui daftar perangkat.',
      );
    }
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw const SyncUnavailableException(
        'Kontrol pairing belum tersedia. Periksa Go sync service terbaru.',
      );
    }
    try {
      final json = (jsonDecode(response.body) as Map).cast<String, dynamic>();
      if (json['protocol_version'] != 1) throw const FormatException();
      return json;
    } on Object {
      throw const SyncProtocolException(
        'Response kontrol pairing tidak valid.',
      );
    }
  }
}
