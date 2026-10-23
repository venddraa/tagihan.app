import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:tagihan_vendra/data/local/app_database.dart';
import 'package:tagihan_vendra/data/sync/local_sync_access.dart';
import 'package:tagihan_vendra/data/sync/pairing_admin_client.dart';
import 'package:tagihan_vendra/data/sync/pinned_sync_transport.dart';
import 'package:tagihan_vendra/data/sync/sync_credential_store.dart';
import 'package:tagihan_vendra/data/sync/sync_http.dart';
import 'package:tagihan_vendra/domain/entity_id.dart';

typedef PairingTransport = SyncHTTPRequest Function(Uri endpoint, String pin);

// Seluruh profil ini disimpan di keyring, termasuk token undangan sementara.
// SQLite hanya menyimpan hubBinding yang tidak rahasia.
final class PairingProfile {
  const PairingProfile({
    required this.deviceId,
    required this.hubId,
    required this.endpoint,
    required this.fingerprint,
    required this.credential,
    required this.requestId,
    required this.name,
    required this.status,
    this.invitationCode,
  });

  final String deviceId,
      hubId,
      fingerprint,
      credential,
      requestId,
      name,
      status;
  final Uri endpoint;
  final String? invitationCode;
  String get binding => 'paired|$hubId|$fingerprint';
  bool get paired => status == 'paired';

  PairingProfile withStatus(String next) => PairingProfile(
    deviceId: deviceId,
    hubId: hubId,
    endpoint: endpoint,
    fingerprint: fingerprint,
    credential: credential,
    requestId: requestId,
    name: name,
    status: next,
    invitationCode: next == 'paired' ? null : invitationCode,
  );

  String encode() => jsonEncode({
    'profile_version': 1,
    'device_id': deviceId,
    'hub_id': hubId,
    'endpoint': endpoint.toString(),
    'certificate_sha256': fingerprint,
    'credential': credential,
    'request_id': requestId,
    'name': name,
    'status': status,
    'invitation_code': invitationCode,
  });

  factory PairingProfile.decode(String encoded) {
    try {
      if (encoded.length > 8192) throw const FormatException();
      final json = jsonDecode(encoded) as Map;
      final profile = PairingProfile(
        deviceId: json['device_id'] as String,
        hubId: json['hub_id'] as String,
        endpoint: Uri.parse(json['endpoint'] as String),
        fingerprint: json['certificate_sha256'] as String,
        credential: json['credential'] as String,
        requestId: json['request_id'] as String,
        name: json['name'] as String,
        status: json['status'] as String,
        invitationCode: json['invitation_code'] as String?,
      );
      for (final id in [profile.deviceId, profile.hubId, profile.requestId]) {
        if (EntityId.fromString(id).value != id) throw const FormatException();
      }
      if (json['profile_version'] != 1 ||
          !isPrivateHTTPSUri(profile.endpoint) ||
          !RegExp(r'^[0-9a-f]{64}$').hasMatch(profile.fingerprint) ||
          !isDeviceCredential(profile.credential) ||
          !_validName(profile.name) ||
          !{
            'pending',
            'approving',
            'paired',
            'rejected',
            'expired',
            'cancelled',
          }.contains(profile.status)) {
        throw const FormatException();
      }
      if (!profile.paired) {
        final invitation = PairingInvitation.fromCode(profile.invitationCode!);
        if (invitation.hubId != profile.hubId ||
            invitation.endpoint != profile.endpoint ||
            invitation.fingerprint != profile.fingerprint) {
          throw const FormatException();
        }
      } else if (profile.invitationCode != null) {
        throw const FormatException();
      }
      return profile;
    } on Object {
      // Jangan sertakan input JSON yang berisi credential dalam exception.
      throw const SyncAuthorizationException(
        'Profil pairing di keyring tidak valid. Credential tidak diganti otomatis.',
      );
    }
  }
}

bool _validName(String value) =>
    value == value.trim() &&
    value.isNotEmpty &&
    value.runes.length <= 80 &&
    !value.runes.any((rune) => rune < 32 || (rune >= 127 && rune <= 159));

final class PairingReceiver {
  PairingReceiver({
    required this.database,
    required this.credentials,
    PairingTransport? transport,
  }) : _transport =
           transport ??
           ((endpoint, pin) => createPinnedSyncRequest(endpoint, pin));

  static const profileService = 'tagihan-vendra-pairing-v1';
  final AppDatabase database;
  final SyncCredentialStore credentials;
  final PairingTransport _transport;
  bool _busy = false;
  bool get busy => _busy;

  // Membaca keyring hanya ketika user menekan tombol, bukan saat app dibuka.
  Future<PairingProfile?> readProfile() async {
    final device = (await database.getLocalSyncState()).deviceId.value;
    final encoded = await credentials.read(profileService, device);
    if (encoded == null) return null;
    final profile = PairingProfile.decode(encoded);
    if (profile.deviceId != device) {
      throw const SyncAuthorizationException(
        'Identitas profil berbeda dari database perangkat.',
      );
    }
    return profile;
  }

  Future<T> _exclusive<T>(Future<T> Function() action) async {
    if (_busy) {
      throw const SyncAuthorizationException(
        'Operasi pairing masih berjalan. Tunggu sampai selesai.',
      );
    }
    _busy = true;
    try {
      return await action();
    } finally {
      _busy = false;
    }
  }

  Future<PairingProfile> begin(String code, String name) =>
      _exclusive(() async {
        final invitation = PairingInvitation.fromCode(code);
        name = name.trim();
        if (!_validName(name)) {
          throw const FormatException(
            'Nama perangkat harus berisi 1–80 karakter tanpa karakter kontrol.',
          );
        }
        if (await readProfile() != null) {
          throw const SyncAuthorizationException(
            'Lanjutkan atau batalkan sesi pairing yang sudah tersimpan.',
          );
        }
        await database.checkPairingEligibility();
        final random = Random.secure();
        final profile = PairingProfile(
          deviceId: (await database.getLocalSyncState()).deviceId.value,
          hubId: invitation.hubId,
          endpoint: invitation.endpoint,
          fingerprint: invitation.fingerprint,
          credential: base64Url
              .encode(List.generate(32, (_) => random.nextInt(256)))
              .replaceAll('=', ''),
          requestId: EntityId.generate().value,
          name: name,
          status: 'pending',
          invitationCode: invitation.code,
        );
        // Wajib durable sebelum jaringan. Timeout tidak membuat identitas baru.
        await _save(profile);
        return _submit(profile);
      });

  Future<PairingProfile> resume() => _exclusive(() async {
    final profile = await _required();
    // Approval mungkin sudah durable, tetapi sesi hilang setelah Go restart.
    if (await _identity(profile)) return _finish(profile);
    if (profile.paired) throw const SyncAuthorizationException();
    final response = await _call(
      profile,
      '/v1/pairing/requests/${profile.requestId}',
    );
    if (response.statusCode == 410) return _submit(profile);
    return _apply(profile, response);
  });

  Future<PairingProfile> requirePaired() => _exclusive(() async {
    final profile = await _required();
    if (!profile.paired) {
      throw const SyncAuthorizationException(
        'Pairing belum selesai. Periksa status persetujuan dahulu.',
      );
    }
    final state = await database.getLocalSyncState();
    if (state.hubBinding != profile.binding) {
      throw const SyncAuthorizationException(
        'Binding hub tidak sesuai database. Cursor tidak direset otomatis.',
      );
    }
    if (!await _identity(profile)) throw const SyncAuthorizationException();
    return profile;
  });

  // Pembatalan diserialisasi dengan approval di hub. Jangan membuang token
  // ketika approval masih ambigu, offline, atau hub sudah terikat di SQLite.
  Future<void> cancel() => _exclusive(() async {
    final profile = await _required();
    if (profile.paired ||
        (await database.getLocalSyncState()).hubBinding != null) {
      throw const SyncAuthorizationException(
        'Perangkat sudah terikat ke hub. Unpair belum tersedia; jangan hapus credential.',
      );
    }
    final response = await _call(
      profile,
      '/v1/pairing/requests/${profile.requestId}/cancel',
      method: 'POST',
    );
    if (response.statusCode == 410) {
      if (await _identity(profile)) {
        await _finish(profile);
        throw const SyncAuthorizationException(
          'Perangkat sudah diizinkan. Pairing diselesaikan; credential tetap disimpan.',
        );
      }
    } else {
      final entry = _entry(profile, response);
      if (!{'cancelled', 'expired', 'rejected'}.contains(entry.status)) {
        throw const SyncProtocolException(
          'Pembatalan belum dikonfirmasi oleh hub.',
        );
      }
    }
    await credentials.delete(profileService, profile.deviceId);
  });

  Future<PairingProfile> _required() async =>
      await readProfile() ??
      (throw const SyncAuthorizationException(
        'Belum ada profil pairing. Masukkan undangan dari Fedora dahulu.',
      ));
  Future<void> _save(PairingProfile profile) =>
      credentials.write(profileService, profile.deviceId, profile.encode());

  Future<PairingProfile> _submit(PairingProfile profile) async {
    final invitation = PairingInvitation.fromCode(profile.invitationCode!);
    final response = await _call(
      profile,
      '/v1/pairing/requests',
      method: 'POST',
      token: invitation.token,
      body: jsonEncode({
        'protocol_version': 1,
        'invitation_id': invitation.id,
        'request_id': profile.requestId,
        'device_id': profile.deviceId,
        'name': profile.name,
        'credential': profile.credential,
      }),
    );
    if (response.statusCode == 410) {
      final expired = profile.withStatus('expired');
      await _save(expired);
      return expired;
    }
    return _apply(profile, response);
  }

  Future<PairingProfile> _apply(
    PairingProfile profile,
    SyncHTTPResponse response,
  ) async {
    final entry = _entry(profile, response);
    if (entry.status == 'approved') {
      if (!await _identity(profile)) throw const SyncAuthorizationException();
      return _finish(profile);
    }
    final next = profile.withStatus(entry.status);
    await _save(next);
    return next;
  }

  PairingRequestEntry _entry(
    PairingProfile profile,
    SyncHTTPResponse response,
  ) {
    final json = _json(response);
    try {
      final entry = PairingRequestEntry.fromJson(
        (json['request'] as Map).cast(),
      );
      if (entry.id != profile.requestId ||
          entry.deviceId != profile.deviceId ||
          entry.name != profile.name) {
        throw const FormatException();
      }
      return entry;
    } on Object {
      throw const SyncProtocolException(
        'Identitas request pairing tidak sesuai.',
      );
    }
  }

  Future<bool> _identity(PairingProfile profile) async {
    final response = await _call(profile, '/v1/pairing/identity');
    if (response.statusCode == 401) return false;
    final json = _json(response);
    if (json['hub_id'] != profile.hubId ||
        json['device_id'] != profile.deviceId) {
      throw const SyncAuthorizationException(
        'Identitas hub atau perangkat berbeda dari undangan.',
      );
    }
    return true;
  }

  Future<PairingProfile> _finish(PairingProfile profile) async {
    // Jika penulisan keyring gagal setelah binding, resume tetap memakai sesi
    // lama. Binding tidak pernah dibersihkan untuk mencoba hub yang berbeda.
    await database.bindSyncHub(profile.binding, paired: true);
    final paired = profile.withStatus('paired');
    await _save(paired);
    return paired;
  }

  Future<SyncHTTPResponse> _call(
    PairingProfile profile,
    String path, {
    String method = 'GET',
    String? body,
    String? token,
  }) => _transport(profile.endpoint, profile.fingerprint)(
    profile.endpoint.resolve(path),
    method: method,
    body: method == 'POST' ? body ?? '{}' : null,
    headers: {
      HttpHeaders.authorizationHeader: 'Bearer ${token ?? profile.credential}',
    },
  );

  Map<String, dynamic> _json(SyncHTTPResponse response) {
    checkSyncAuthorization(response);
    if (response.statusCode == 409) {
      throw const SyncAuthorizationException(
        'Request sudah diizinkan, sedang diproses, atau identitas sudah dipakai. Periksa status; credential tetap disimpan.',
      );
    }
    if (response.statusCode == 410) {
      throw const SyncProtocolException('Sesi pairing sudah berakhir.');
    }
    if (response.statusCode == 429) {
      throw const SyncUnavailableException(
        'Terlalu banyak request. Tunggu satu menit sebelum mencoba lagi.',
      );
    }
    if (response.statusCode != 200) {
      throw const SyncUnavailableException(
        'Hub belum dapat memproses pairing. Coba lagi nanti.',
      );
    }
    try {
      final json = (jsonDecode(response.body) as Map).cast<String, dynamic>();
      if (json['protocol_version'] != 1) throw const FormatException();
      return json;
    } on Object {
      throw const SyncProtocolException('Response pairing tidak valid.');
    }
  }
}
