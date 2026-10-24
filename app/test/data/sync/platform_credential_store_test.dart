import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tagihan_vendra/data/sync/platform_credential_store.dart';
import 'package:tagihan_vendra/data/sync/sync_credential_store.dart';
import 'package:tagihan_vendra/data/sync/sync_http.dart';

const keychainChannel = MethodChannel(
  'plugins.it_nomads.com/flutter_secure_storage',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late List<MethodCall> calls;
  late Map<String, String> values;
  late Future<Object?> Function(MethodCall call) respond;

  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    calls = [];
    values = {};
    respond = (call) async {
      final args = call.arguments as Map;
      final key = args['key'] as String;
      switch (call.method) {
        case 'read':
          return values[key];
        case 'write':
          values[key] = args['value'] as String;
          return null;
        case 'delete':
          values.remove(key);
          return null;
        default:
          throw StateError(
            'Operasi Keychain tidak diizinkan dalam test: ${call.method}',
          );
      }
    };
    messenger.setMockMethodCallHandler(keychainChannel, (call) async {
      calls.add(call);
      final args = call.arguments as Map;
      final options = args['options'] as Map;
      expect(options['accountName'], 'tagihan-vendra.sync.v1');
      expect(options['accessibility'], 'unlocked_this_device');
      expect(options['synchronizable'], 'false');
      expect(options['useSecureEnclave'], 'false');
      expect(options.containsKey('groupId'), isFalse);
      expect(options.containsKey('accessControlFlags'), isFalse);
      return respond(call);
    });
  });
  tearDown(() {
    messenger.setMockMethodCallHandler(keychainChannel, null);
    debugDefaultTargetPlatformOverride = null;
  });

  test(
    'pemilihan store mengikuti OS native dan tidak melakukan I/O saat dibuat',
    () async {
      expect(
        createDefaultSyncCredentialStore(operatingSystem: 'linux'),
        isA<LinuxKeyringCredentialStore>(),
      );
      expect(
        createDefaultSyncCredentialStore(operatingSystem: 'ios'),
        isA<IOSKeychainCredentialStore>(),
      );
      if (Platform.isLinux) {
        // Theme iOS pada widget test tidak mengubah credential Fedora.
        expect(
          createDefaultSyncCredentialStore(),
          isA<LinuxKeyringCredentialStore>(),
        );
      }
      final unsupported = createDefaultSyncCredentialStore(
        operatingSystem: 'unknown',
      );
      await expectLater(
        unsupported.read('service', 'device'),
        throwsA(isA<SyncAuthorizationException>()),
      );
      await expectLater(
        unsupported.write('service', 'device', 'secret'),
        throwsA(isA<SyncAuthorizationException>()),
      );
      await expectLater(
        unsupported.delete('service', 'device'),
        throwsA(isA<SyncAuthorizationException>()),
      );
      expect(calls, isEmpty);
    },
  );

  test('read/write/delete memakai opsi device-only dan menjaga pemisahan service/perangkat', () async {
    final store = IOSKeychainCredentialStore();
    expect(await store.read('service:a', 'b'), isNull);
    await store.write('service:a', 'b', 'opaque-profile-secret\n');
    await store.write('service', 'a:b', 'other-service');
    await store.write('service:a', 'other-device', 'other-device');
    expect(await store.read('service:a', 'b'), 'opaque-profile-secret\n');
    expect(await store.read('service', 'a:b'), 'other-service');
    expect(await store.read('service:a', 'other-device'), 'other-device');
    expect(values, hasLength(3));
    for (final call in calls) {
      expect(
        (call.arguments as Map)['key'],
        isNot(contains('opaque-profile-secret')),
      );
    }
    await store.delete('service:a', 'b');
    expect(await store.read('service:a', 'b'), isNull);
    expect(values, hasLength(2));
    expect(calls.map((call) => call.method), isNot(contains('deleteAll')));
  });

  test('item tidak ditemukan berbeda dari Keychain terkunci dan detail error disembunyikan', () async {
    final store = IOSKeychainCredentialStore();
    expect(await store.read('pairing', 'device'), isNull);
    respond = (_) async => throw PlatformException(
      code: '-25308',
      message: 'secret-value',
      details: 'secret-profile',
    );
    for (final action in [
      () => store.read('pairing', 'device'),
      () => store.write('pairing', 'device', 'credential'),
      () => store.delete('pairing', 'device'),
    ]) {
      await expectLater(
        action(),
        throwsA(
          isA<SyncAuthorizationException>().having(
            (error) => error.toString(),
            'redacted',
            allOf(
              isNot(contains('secret-value')),
              isNot(contains('secret-profile')),
            ),
          ),
        ),
      );
    }
    expect(values, isEmpty);
    expect(calls.map((call) => call.method), [
      'read',
      'read',
      'write',
      'delete',
    ]);
  });

  test('plugin hilang atau response malformed gagal aman tanpa membuat credential baru', () async {
    final store = IOSKeychainCredentialStore();
    respond = (_) async => throw MissingPluginException('secret-native-detail');
    await expectLater(
      store.read('pairing', 'device'),
      throwsA(
        isA<SyncAuthorizationException>().having(
          (error) => error.message,
          'redacted',
          isNot(contains('secret-native-detail')),
        ),
      ),
    );
    respond = (_) async => 123;
    await expectLater(
      store.read('pairing', 'device'),
      throwsA(isA<SyncAuthorizationException>()),
    );
    respond = (_) async => '';
    await expectLater(
      store.read('pairing', 'device'),
      throwsA(isA<SyncAuthorizationException>()),
    );
    expect(calls.map((call) => call.method), everyElement('read'));
  });

  test(
    'write yang diakui plugin tetapi tidak tersimpan ditolak setelah read-back',
    () async {
      respond = (_) async => null;
      await expectLater(
        IOSKeychainCredentialStore().write('pairing', 'device', 'secret'),
        throwsA(isA<SyncAuthorizationException>()),
      );
      expect(calls.map((call) => call.method), ['write', 'read']);
      expect(values, isEmpty);
    },
  );

  test('timeout write tidak melakukan retry/delete dan hasil native yang terlambat dapat dibaca', () async {
    final completed = Completer<void>();
    respond = (call) async {
      final args = call.arguments as Map;
      if (call.method == 'write') {
        await completed.future;
        values[args['key'] as String] = args['value'] as String;
        return null;
      }
      return values[args['key'] as String];
    };
    final timed = IOSKeychainCredentialStore(
      timeout: const Duration(milliseconds: 1),
    );
    await expectLater(
      timed.write('pairing', 'device', 'durable-profile'),
      throwsA(isA<SyncAuthorizationException>()),
    );
    completed.complete();
    await Future<void>.delayed(Duration.zero);
    final store = IOSKeychainCredentialStore();
    expect(await store.read('pairing', 'device'), 'durable-profile');
    expect(calls.where((call) => call.method == 'write'), hasLength(1));
    expect(
      calls.where(
        (call) => call.method == 'delete' || call.method == 'deleteAll',
      ),
      isEmpty,
    );
  });

  test(
    'metadata atau credential kosong ditolak sebelum platform dipanggil',
    () async {
      final store = IOSKeychainCredentialStore();
      await expectLater(store.read('', 'device'), throwsArgumentError);
      await expectLater(
        store.write('service', '', 'secret'),
        throwsArgumentError,
      );
      await expectLater(
        store.write('service', 'device', ''),
        throwsArgumentError,
      );
      expect(calls, isEmpty);
    },
  );

  test('adapter iOS tidak memanggil plugin pada platform lain', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    await expectLater(
      IOSKeychainCredentialStore().read('pairing', 'device'),
      throwsA(isA<SyncAuthorizationException>()),
    );
    expect(calls, isEmpty);
  });
}
