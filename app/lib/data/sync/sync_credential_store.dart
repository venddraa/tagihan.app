import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:tagihan_vendra/data/sync/sync_http.dart';

abstract interface class SyncCredentialStore {
  Future<String?> read(String service, String deviceId);
  Future<void> write(String service, String deviceId, String credential);
}

final class SecretToolResult {
  const SecretToolResult(this.exitCode, this.output, this.errorOutput);

  final int exitCode;
  final String output;
  final String errorOutput;
}

typedef SecretToolCommand = Future<SecretToolResult> Function(
  List<String> arguments,
  String? input,
);

// Adapter Fedora: credential masuk stdin, bukan argumen proses atau SQLite.
final class LinuxKeyringCredentialStore implements SyncCredentialStore {
  LinuxKeyringCredentialStore({SecretToolCommand? command})
    : _command = command ?? _runSecretTool;

  final SecretToolCommand _command;

  List<String> _attributes(String service, String deviceId) => [
    'application',
    'tagihan-vendra',
    'service',
    service,
    'device_id',
    deviceId,
  ];

  @override
  Future<String?> read(String service, String deviceId) async {
    final result = await _command([
      'lookup',
      ..._attributes(service, deviceId),
    ], null);
    if (result.exitCode == 1 &&
        result.output.isEmpty &&
        result.errorOutput.isEmpty) {
      return null;
    }
    if (result.exitCode != 0 || result.output.isEmpty) {
      throw const SyncAuthorizationException(
        'Keyring Fedora belum dapat dibaca. Periksa apakah keyring login terbuka.',
      );
    }
    return result.output;
  }

  @override
  Future<void> write(String service, String deviceId, String credential) async {
    final result = await _command([
      'store',
      '--label=Tagihan Vendra — sinkronisasi',
      ..._attributes(service, deviceId),
    ], credential);
    if (result.exitCode != 0) {
      throw const SyncAuthorizationException(
        'Credential sync belum dapat disimpan ke keyring Fedora.',
      );
    }
  }
}

Future<SecretToolResult> _runSecretTool(
  List<String> arguments,
  String? input,
) async {
  Process? process;
  try {
    if (!Platform.isLinux) {
      throw const SyncAuthorizationException(
        'Penyimpanan credential untuk perangkat ini belum disiapkan.',
      );
    }
    final running = await Process.start('/usr/bin/secret-tool', arguments);
    process = running;
    final output = utf8.decoder.bind(running.stdout).join();
    final errors = utf8.decoder.bind(running.stderr).join();
    final result = () async {
      if (input != null) running.stdin.write(input);
      await running.stdin.close();
      final code = await running.exitCode;
      return SecretToolResult(code, await output, await errors);
    }();
    return await result.timeout(const Duration(seconds: 20));
  } on ProcessException {
    throw const SyncAuthorizationException(
      'secret-tool belum tersedia. Pasang paket libsecret untuk menggunakan keyring Fedora.',
    );
  } on TimeoutException {
    process?.kill(ProcessSignal.sigkill);
    throw const SyncAuthorizationException(
      'Keyring belum merespons. Buka keyring login lalu coba lagi.',
    );
  }
}
