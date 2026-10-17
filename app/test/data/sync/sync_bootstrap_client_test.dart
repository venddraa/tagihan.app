import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tagihan_vendra/data/local/app_database.dart';
import 'package:tagihan_vendra/data/sync/sync_bootstrap_client.dart';
import 'package:tagihan_vendra/data/sync/sync_push_client.dart';
import 'package:tagihan_vendra/domain/bill.dart';
import 'package:tagihan_vendra/domain/calendar_date.dart';
import 'package:tagihan_vendra/domain/entity_id.dart';
import 'package:tagihan_vendra/domain/money.dart';

void main() {
  late AppDatabase database;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() => database.close());

  test('mengirim snapshot dan menyelesaikan bootstrap lokal', () async {
    await database.insertBill(
      _bill(id: '0199e7d0-0000-7000-8000-000000000010', name: 'Spotify'),
    );
    final client = SyncBootstrapClient(
      database: database,
      serviceBaseUri: Uri.parse('http://127.0.0.1:8787'),
      postJSON: (uri, body) async {
        expect(uri.toString(), 'http://127.0.0.1:8787/v1/sync/bootstrap');
        final request = jsonDecode(body) as Map<String, dynamic>;
        expect(request['protocol_version'], 1);
        expect(request['device_id'], isA<String>());
        expect(request['bills'], hasLength(1));
        expect(request['payments'], isEmpty);
        return SyncHTTPResponse(
          statusCode: 200,
          body: jsonEncode({
            'protocol_version': 1,
            'bootstrap_id': request['bootstrap_id'],
            'status': 'accepted',
            'server_sequences': [1],
          }),
        );
      },
    );

    final result = await client.bootstrapIfNeeded();

    expect(result.status, SyncBootstrapStatus.accepted);
    expect(result.serverSequences, [1]);
    expect(await database.getPendingSyncOperations(), isEmpty);
    expect((await database.getLocalSyncState()).lastPulledSequence, 1);
  });

  test(
    'retry memakai payload sama dan menjaga perubahan setelah snapshot',
    () async {
      await database.insertBill(
        _bill(id: '0199e7d0-0000-7000-8000-000000000010', name: 'Spotify'),
      );
      String? firstRequestBody;
      final failingClient = SyncBootstrapClient(
        database: database,
        serviceBaseUri: Uri.parse('http://127.0.0.1:8787'),
        postJSON: (uri, body) async {
          firstRequestBody = body;
          throw const SyncUnavailableException();
        },
      );
      await expectLater(
        failingClient.bootstrapIfNeeded(),
        throwsA(isA<SyncUnavailableException>()),
      );
      await database.insertBill(
        _bill(id: '0199e7d0-0000-7000-8000-000000000011', name: 'Internet'),
      );

      final retryClient = SyncBootstrapClient(
        database: database,
        serviceBaseUri: Uri.parse('http://127.0.0.1:8787'),
        postJSON: (uri, body) async {
          expect(body, firstRequestBody);
          final request = jsonDecode(body) as Map<String, dynamic>;
          return SyncHTTPResponse(
            statusCode: 200,
            body: jsonEncode({
              'protocol_version': 1,
              'bootstrap_id': request['bootstrap_id'],
              'status': 'duplicate',
              'server_sequences': [1],
            }),
          );
        },
      );

      final result = await retryClient.bootstrapIfNeeded();

      expect(result.status, SyncBootstrapStatus.duplicate);
      final pending = await database.getPendingSyncOperations();
      expect(pending, hasLength(1));
      expect(pending.single.entityId.value, endsWith('11'));
    },
  );

  test('bootstrap yang sudah selesai tidak memanggil service lagi', () async {
    final prepared = await database.prepareSyncBootstrap(
      now: DateTime.utc(2026, 10, 17),
    );
    await database.completeSyncBootstrap(
      bootstrapId: prepared!.bootstrapId,
      serverSequences: const [],
    );
    var called = false;
    final client = SyncBootstrapClient(
      database: database,
      serviceBaseUri: Uri.parse('http://127.0.0.1:8787'),
      postJSON: (uri, body) async {
        called = true;
        throw StateError('Tidak boleh dipanggil.');
      },
    );

    final result = await client.bootstrapIfNeeded();

    expect(called, isFalse);
    expect(result.status, SyncBootstrapStatus.alreadyCompleted);
  });

  test('response tidak valid mempertahankan snapshot dan outbox', () async {
    await database.insertBill(
      _bill(id: '0199e7d0-0000-7000-8000-000000000010', name: 'Spotify'),
    );
    final client = SyncBootstrapClient(
      database: database,
      serviceBaseUri: Uri.parse('http://127.0.0.1:8787'),
      postJSON: (uri, body) async => const SyncHTTPResponse(
        statusCode: 200,
        body: '{"protocol_version":1,"status":"accepted"}',
      ),
    );

    await expectLater(
      client.bootstrapIfNeeded(),
      throwsA(isA<SyncProtocolException>()),
    );

    expect(await database.getPendingSyncOperations(), hasLength(1));
    final state = await database.select(database.syncStates).getSingle();
    expect(state.bootstrapPayloadJson, isNotNull);
    expect(state.bootstrapCompletedAtMs, isNull);
  });

  test('hub yang sudah terisi dilaporkan tanpa membuang snapshot', () async {
    final client = SyncBootstrapClient(
      database: database,
      serviceBaseUri: Uri.parse('http://127.0.0.1:8787'),
      postJSON: (uri, body) async => const SyncHTTPResponse(
        statusCode: 409,
        body: '{"error":{"code":"hub_not_empty"}}',
      ),
    );

    await expectLater(
      client.bootstrapIfNeeded(),
      throwsA(isA<SyncBootstrapRejectedException>()),
    );

    final state = await database.select(database.syncStates).getSingle();
    expect(state.bootstrapPayloadJson, isNotNull);
    expect(state.bootstrapCompletedAtMs, isNull);
  });
}

Bill _bill({required String id, required String name}) {
  return Bill(
    id: EntityId.fromString(id),
    name: name,
    amount: Money(minorUnits: 59990, currency: Currency.idr),
    billingCycle: BillingCycle.monthly,
    nextDueDate: CalendarDate(2026, 10, 25),
    startDate: CalendarDate(2026, 1, 25),
    status: BillStatus.active,
    createdAt: DateTime.utc(2026, 10, 1),
    updatedAt: DateTime.utc(2026, 10, 1),
    version: 1,
  );
}
