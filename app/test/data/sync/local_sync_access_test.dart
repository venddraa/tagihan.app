import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tagihan_vendra/data/local/app_database.dart';
import 'package:tagihan_vendra/data/sync/local_sync_access.dart';
import 'package:tagihan_vendra/data/sync/sync_bootstrap_client.dart';
import 'package:tagihan_vendra/data/sync/sync_credential_store.dart';
import 'package:tagihan_vendra/data/sync/sync_pull_client.dart';
import 'package:tagihan_vendra/data/sync/sync_push_client.dart';
import 'package:tagihan_vendra/domain/bill.dart';
import 'package:tagihan_vendra/domain/calendar_date.dart';
import 'package:tagihan_vendra/domain/entity_id.dart';
import 'package:tagihan_vendra/domain/money.dart';

final _syncUri = Uri.parse('http://127.0.0.1:8787');
final _adminUri = Uri.parse('http://127.0.0.1:8788');
final _adminToken = List.filled(43, 'A').join();

void main() {
  late AppDatabase database;
  late _MemoryCredentials credentials;
  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    credentials = _MemoryCredentials();
  });
  tearDown(() => database.close());

  test('registrasi menyimpan credential sebelum network dan memisahkan token admin', () async {
    final requests =
        <({Uri uri, String method, Map<String, String> headers})>[];
    final access = LocalSyncAccess(
      database: database,
      serviceBaseUri: _syncUri,
      adminBaseUri: _adminUri,
      credentials: credentials,
      readAdminCredential: () async => _adminToken,
      request: (uri, {required method, body, headers = const {}}) async {
        expect(credentials.value, isNotNull);
        requests.add((uri: uri, method: method, headers: headers));
        if (uri.path == '/v1/admin/devices') {
          expect(headers['authorization'], 'Bearer $_adminToken');
          final input = jsonDecode(body!) as Map<String, dynamic>;
          expect(input['credential'], credentials.value);
          expect(isDeviceCredential(input['credential'] as String), isTrue);
          return _registeredResponse(body);
        }
        if (uri.path == '/v1/sync/bootstrap') {
          expect(uri.origin, _adminUri.origin);
          expect(headers['authorization'], 'Bearer $_adminToken');
        } else {
          expect(uri.origin, _syncUri.origin);
          expect(headers['authorization'], 'Bearer ${credentials.value}');
          expect(headers['authorization'], isNot('Bearer $_adminToken'));
        }
        return const SyncHTTPResponse(statusCode: 200, body: '{}');
      },
    );
    await access.prepare();
    await access.get(_syncUri.resolve('/v1/sync/pull?after=0'));
    await access.post(_syncUri.resolve('/v1/sync/push'), '{}');
    await access.post(_syncUri.resolve('/v1/sync/bootstrap'), '{}');
    expect(credentials.writes, 1);
    expect(requests.map((value) => value.uri.path), [
      '/v1/admin/devices',
      '/v1/sync/pull',
      '/v1/sync/push',
      '/v1/sync/bootstrap',
    ]);
  });

  test(
    'retry registrasi setelah timeout memakai token keyring yang sama',
    () async {
      var calls = 0;
      String? firstToken;
      final access = LocalSyncAccess(
        database: database,
        serviceBaseUri: _syncUri,
        adminBaseUri: _adminUri,
        credentials: credentials,
        readAdminCredential: () async => _adminToken,
        request: (uri, {required method, body, headers = const {}}) async {
          calls++;
          final input = jsonDecode(body!) as Map<String, dynamic>;
          if (calls == 1) {
            firstToken = input['credential'] as String;
            throw const SyncUnavailableException();
          }
          expect(input['credential'], firstToken);
          return _registeredResponse(body, status: 200);
        },
      );
      await expectLater(
        access.prepare(),
        throwsA(isA<SyncUnavailableException>()),
      );
      await access.prepare();
      expect(credentials.writes, 1);
      expect(calls, 2);
    },
  );

  test(
    'gagal menyimpan keyring menghentikan registrasi tanpa mengirim request',
    () async {
      credentials.failWrite = true;
      var requests = 0;
      final access = LocalSyncAccess(
        database: database,
        serviceBaseUri: _syncUri,
        adminBaseUri: _adminUri,
        credentials: credentials,
        readAdminCredential: () async => _adminToken,
        request: (uri, {required method, body, headers = const {}}) async {
          requests++;
          return _registeredResponse(body!);
        },
      );
      await expectLater(
        access.prepare(),
        throwsA(isA<SyncAuthorizationException>()),
      );
      expect(requests, 0);
    },
  );

  test('credential revoked atau berbeda tidak diganti otomatis', () async {
    credentials.value = base64Url
        .encode(List.filled(32, 1))
        .replaceAll('=', '');
    final original = credentials.value;
    final access = LocalSyncAccess(
      database: database,
      serviceBaseUri: _syncUri,
      adminBaseUri: _adminUri,
      credentials: credentials,
      readAdminCredential: () async => _adminToken,
      request: (uri, {required method, body, headers = const {}}) async =>
          const SyncHTTPResponse(statusCode: 409, body: '{}'),
    );
    await expectLater(
      access.prepare(),
      throwsA(isA<SyncAuthorizationException>()),
    );
    expect(credentials.value, original);
    expect(credentials.writes, 0);
  });

  test(
    'target asing dan LAN ditolak sebelum credential dibaca atau dikirim',
    () async {
      var reads = 0;
      var requests = 0;
      LocalSyncAccess create(Uri syncUri) => LocalSyncAccess(
        database: database,
        serviceBaseUri: syncUri,
        adminBaseUri: _adminUri,
        credentials: credentials,
        readAdminCredential: () async {
          reads++;
          return _adminToken;
        },
        request: (uri, {required method, body, headers = const {}}) async {
          requests++;
          return const SyncHTTPResponse(statusCode: 200, body: '{}');
        },
      );
      await expectLater(
        create(Uri.parse('http://192.168.1.10:8787')).prepare(),
        throwsA(isA<SyncAuthorizationException>()),
      );
      await expectLater(
        create(_syncUri).get(Uri.parse('http://example.com/v1/sync/pull')),
        throwsA(isA<SyncAuthorizationException>()),
      );
      expect(reads, 0);
      expect(requests, 0);
    },
  );

  test('registrasi dengan identity response berbeda tidak dipercaya', () async {
    final access = LocalSyncAccess(
      database: database,
      serviceBaseUri: _syncUri,
      adminBaseUri: _adminUri,
      credentials: credentials,
      readAdminCredential: () async => _adminToken,
      request: (uri, {required method, body, headers = const {}}) async =>
          const SyncHTTPResponse(
            statusCode: 201,
            body: '{"protocol_version":1,"device":{"device_id":"other","revoked_at":null}}',
          ),
    );
    await expectLater(access.prepare(), throwsA(isA<SyncProtocolException>()));
  });

  test(
    'push 401 mempertahankan outbox, pull 403 tidak memajukan cursor',
    () async {
      await database.insertBill(_bill());
      final push = SyncPushClient(
        database: database,
        serviceBaseUri: _syncUri,
        postJSON: (_, _) async =>
            const SyncHTTPResponse(statusCode: 401, body: '{}'),
      );
      await expectLater(
        push.pushPending(),
        throwsA(isA<SyncAuthorizationException>()),
      );
      expect(await database.countPendingSyncOperations(), 1);
      final pull = SyncPullClient(
        database: database,
        serviceBaseUri: _syncUri,
        getJSON: (_) async =>
            const SyncHTTPResponse(statusCode: 403, body: '{}'),
      );
      await expectLater(
        pull.pullAndApplyAvailable(),
        throwsA(isA<SyncAuthorizationException>()),
      );
      expect((await database.getLocalSyncState()).lastPulledSequence, 0);
    },
  );

  test('bootstrap 401 tidak menyelesaikan snapshot lokal', () async {
    await database.insertBill(_bill());
    final client = SyncBootstrapClient(
      database: database,
      serviceBaseUri: _syncUri,
      postJSON: (_, _) async =>
          const SyncHTTPResponse(statusCode: 401, body: '{}'),
    );
    await expectLater(
      client.bootstrapIfNeeded(),
      throwsA(isA<SyncAuthorizationException>()),
    );
    expect(await database.prepareSyncBootstrap(), isNotNull);
    expect(await database.countPendingSyncOperations(), 1);
  });
}

SyncHTTPResponse _registeredResponse(String body, {int status = 201}) {
  final input = jsonDecode(body) as Map<String, dynamic>;
  return SyncHTTPResponse(
    statusCode: status,
    body: jsonEncode({
      'protocol_version': 1,
      'device': {'device_id': input['device_id'], 'revoked_at': null},
    }),
  );
}

final class _MemoryCredentials implements SyncCredentialStore {
  String? value;
  int writes = 0;
  bool failWrite = false;

  @override
  Future<String?> read(String service, String deviceId) async => value;
  @override
  Future<void> write(String service, String deviceId, String credential) async {
    if (failWrite) throw const SyncAuthorizationException('Keyring gagal.');
    writes++;
    value = credential;
  }
}

Bill _bill() => Bill(
  id: EntityId.fromString('0199e7d0-0000-7000-8000-000000000001'),
  name: 'Spotify',
  amount: Money(minorUnits: 59990, currency: Currency.idr),
  billingCycle: BillingCycle.monthly,
  nextDueDate: CalendarDate(2026, 10, 25),
  startDate: CalendarDate(2026, 1, 25),
  status: BillStatus.active,
  createdAt: DateTime.utc(2026, 10, 1),
  updatedAt: DateTime.utc(2026, 10, 1),
  version: 1,
);
