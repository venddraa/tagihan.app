import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:tagihan_vendra/data/sync/sync_credential_store.dart';
import 'package:tagihan_vendra/data/sync/sync_http.dart';

// Pemilihan berdasarkan OS asli, bukan platform theme yang dapat diubah UI.
// Pembuatan adapter tidak membaca credential atau membuka koneksi apa pun.
SyncCredentialStore createDefaultSyncCredentialStore({
  String? operatingSystem,
}) => switch (operatingSystem ?? Platform.operatingSystem) {
  'linux' => LinuxKeyringCredentialStore(),
  'ios' => IOSKeychainCredentialStore(),
  _ => const _UnsupportedCredentialStore(),
};

final class IOSKeychainCredentialStore implements SyncCredentialStore {
  IOSKeychainCredentialStore({this.timeout = const Duration(seconds: 20)});

  static const _options = IOSOptions(
    accountName: 'tagihan-vendra.sync.v1',
    accessibility: KeychainAccessibility.unlocked_this_device,
    synchronizable: false,
    useSecureEnclave: false,
  );
  static const _storage = FlutterSecureStorage();
  final Duration timeout;

  String _key(String service, String deviceId) {
    if (service.isEmpty || deviceId.isEmpty) {
      throw ArgumentError(
        'Service dan identitas perangkat tidak boleh kosong.',
      );
    }
    // Array JSON mencegah collision delimiter. Kunci hanya mengandung metadata,
    // sedangkan token/profil tetap menjadi value Keychain yang terpisah.
    return 'sync.v1.${base64Url.encode(utf8.encode(jsonEncode([service, deviceId]))).replaceAll('=', '')}';
  }

  @override
  Future<String?> read(String service, String deviceId) => _run(() async {
    final value = await _storage.read(
      key: _key(service, deviceId),
      iOptions: _options,
    );
    if (value != null && value.isEmpty) {
      throw const SyncAuthorizationException(
        'Credential di Keychain kosong. Credential tidak diganti otomatis.',
      );
    }
    return value;
  });

  @override
  Future<void> write(String service, String deviceId, String credential) =>
      _run(() async {
        if (credential.isEmpty) {
          throw ArgumentError('Credential tidak boleh kosong.');
        }
        await _storage.write(
          key: _key(service, deviceId),
          value: credential,
          iOptions: _options,
        );
        final stored = await _storage.read(
          key: _key(service, deviceId),
          iOptions: _options,
        );
        if (stored != credential) {
          throw const SyncAuthorizationException(
            'Penyimpanan credential di Keychain belum terkonfirmasi. Periksa sesi pairing sebelum mencoba lagi.',
          );
        }
      });

  @override
  Future<void> delete(String service, String deviceId) => _run(
    () => _storage.delete(key: _key(service, deviceId), iOptions: _options),
  );

  Future<T> _run<T>(Future<T> Function() action) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) {
      throw const SyncAuthorizationException(
        'Adapter Keychain hanya tersedia pada iPhone.',
      );
    }
    try {
      return await action().timeout(timeout);
    } on MissingPluginException {
      throw const SyncAuthorizationException(
        'Plugin Keychain belum tersedia. Periksa konfigurasi build iOS.',
      );
    } on PlatformException {
      // Pesan/detail platform dapat memuat secret; jangan diteruskan ke UI/log.
      throw const SyncAuthorizationException(
        'Keychain iPhone belum dapat diakses. Buka kunci perangkat lalu coba lagi; jika tetap gagal, periksa konfigurasi build iOS.',
      );
    } on TimeoutException {
      // Timeout tidak membatalkan operasi native. Jangan retry write/delete
      // otomatis: lanjutkan melalui pemeriksaan sesi yang sudah ada.
      throw const SyncAuthorizationException(
        'Hasil operasi Keychain belum terkonfirmasi. Periksa sesi pairing sebelum mencoba lagi.',
      );
    } on TypeError {
      throw const SyncAuthorizationException(
        'Response plugin Keychain tidak sesuai. Periksa konfigurasi build iOS.',
      );
    }
  }
}

final class _UnsupportedCredentialStore implements SyncCredentialStore {
  const _UnsupportedCredentialStore();
  static const _error = SyncAuthorizationException(
    'Penyimpanan credential belum didukung pada platform ini. Data lokal tetap dapat digunakan.',
  );
  @override
  Future<String?> read(String service, String deviceId) async => throw _error;
  @override
  Future<void> write(
    String service,
    String deviceId,
    String credential,
  ) async => throw _error;
  @override
  Future<void> delete(String service, String deviceId) async => throw _error;
}
