import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tagihan_vendra/data/local/app_database.dart';
import 'package:tagihan_vendra/data/local/sync_operation.dart';
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

  test('tidak memanggil service ketika outbox kosong', () async {
    var called = false;
    final client = SyncPushClient(
      database: database,
      serviceBaseUri: Uri.parse('http://127.0.0.1:8787'),
      postJSON: (uri, body) async {
        called = true;
        throw StateError('Tidak boleh dipanggil.');
      },
    );

    final summary = await client.pushPending();

    expect(called, isFalse);
    expect(summary.hadWork, isFalse);
    expect(summary.completed, 0);
  });

  test('menghapus hanya operation accepted dan duplicate', () async {
    final firstBill = _bill(
      id: '0199e7d0-0000-7000-8000-000000000010',
      name: 'Spotify',
    );
    final secondBill = _bill(
      id: '0199e7d0-0000-7000-8000-000000000011',
      name: 'Internet',
    );
    await database.insertBill(firstBill);
    await database.updateBill(
      _copyBill(
        firstBill,
        name: 'Spotify Premium',
        updatedAt: DateTime.utc(2026, 10, 2),
        version: 2,
      ),
    );
    await database.insertBill(secondBill);
    final before = await database.getPendingSyncOperations();

    final client = SyncPushClient(
      database: database,
      serviceBaseUri: Uri.parse('http://127.0.0.1:8787'),
      postJSON: (uri, body) async {
        expect(uri.toString(), 'http://127.0.0.1:8787/v1/sync/push');
        final request = jsonDecode(body) as Map<String, dynamic>;
        expect(request['protocol_version'], 1);
        expect(request['device_id'], isA<String>());
        final operations = request['operations'] as List<dynamic>;
        expect(operations, hasLength(3));
        expect(
          (operations.first as Map<String, dynamic>)['operation_type'],
          'bill.create',
        );
        expect(
          (operations.first as Map<String, dynamic>)['payload'],
          containsPair('name', 'Spotify'),
        );

        return SyncHTTPResponse(
          statusCode: 200,
          body: jsonEncode({
            'protocol_version': 1,
            'results': [
              {
                'operation_id': before[0].operationId.value,
                'status': 'accepted',
                'server_sequences': [1],
              },
              {
                'operation_id': before[1].operationId.value,
                'status': 'conflict',
                'server_sequences': <int>[],
                'error_code': 'version_conflict',
              },
              {
                'operation_id': before[2].operationId.value,
                'status': 'duplicate',
                'server_sequences': [2],
              },
            ],
          }),
        );
      },
    );

    final summary = await client.pushPending();

    expect(summary.sent, 3);
    expect(summary.completed, 2);
    expect(summary.conflicts, 1);
    expect(summary.rejected, 0);
    final remaining = await database.getPendingSyncOperations();
    expect(remaining, hasLength(1));
    expect(remaining.single.operationId, before[1].operationId);
    expect(remaining.single.operationType, SyncOperationType.billUpdate);
  });

  test('network failure mempertahankan seluruh outbox', () async {
    await database.insertBill(
      _bill(id: '0199e7d0-0000-7000-8000-000000000010', name: 'Spotify'),
    );
    final client = SyncPushClient(
      database: database,
      serviceBaseUri: Uri.parse('http://127.0.0.1:8787'),
      postJSON: (uri, body) async => throw const SyncUnavailableException(),
    );

    await expectLater(
      client.pushPending(),
      throwsA(isA<SyncUnavailableException>()),
    );

    expect(await database.getPendingSyncOperations(), hasLength(1));
  });

  test('response tidak lengkap tidak menghapus outbox', () async {
    await database.insertBill(
      _bill(id: '0199e7d0-0000-7000-8000-000000000010', name: 'Spotify'),
    );
    final client = SyncPushClient(
      database: database,
      serviceBaseUri: Uri.parse('http://127.0.0.1:8787'),
      postJSON: (uri, body) async => const SyncHTTPResponse(
        statusCode: 200,
        body: '{"protocol_version":1,"results":[]}',
      ),
    );

    await expectLater(
      client.pushPending(),
      throwsA(isA<SyncProtocolException>()),
    );

    expect(await database.getPendingSyncOperations(), hasLength(1));
  });
}

Bill _bill({required String id, required String name}) {
  return Bill(
    id: EntityId.fromString(id),
    name: name,
    category: null,
    amount: Money(minorUnits: 59990, currency: Currency.idr),
    billingCycle: BillingCycle.monthly,
    nextDueDate: CalendarDate(2026, 10, 25),
    startDate: CalendarDate(2026, 1, 25),
    status: BillStatus.active,
    notes: null,
    createdAt: DateTime.utc(2026, 10, 1),
    updatedAt: DateTime.utc(2026, 10, 1),
    version: 1,
  );
}

Bill _copyBill(
  Bill source, {
  required String name,
  required DateTime updatedAt,
  required int version,
}) {
  return Bill(
    id: source.id,
    name: name,
    category: source.category,
    amount: source.amount,
    billingCycle: source.billingCycle,
    nextDueDate: source.nextDueDate,
    startDate: source.startDate,
    status: source.status,
    notes: source.notes,
    createdAt: source.createdAt,
    updatedAt: updatedAt,
    version: version,
  );
}
