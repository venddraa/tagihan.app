import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tagihan_vendra/data/local/app_database.dart';
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

  test('snapshot bootstrap disimpan dan aman diulang', () async {
    await database.insertBill(
      _bill(id: '0199e7d0-0000-7000-8000-000000000010', name: 'Spotify'),
    );
    final first = await database.prepareSyncBootstrap(
      now: DateTime.utc(2026, 10, 17),
    );
    await database.insertBill(
      _bill(id: '0199e7d0-0000-7000-8000-000000000011', name: 'Internet'),
    );
    final retry = await database.prepareSyncBootstrap(
      now: DateTime.utc(2026, 10, 18),
    );

    expect(retry!.bootstrapId, first!.bootstrapId);
    expect(retry.requestBody, first.requestBody);
    final request = jsonDecode(first.requestBody) as Map<String, dynamic>;
    expect(request['protocol_version'], 1);
    expect(request['bootstrap_id'], first.bootstrapId.value);
    expect(request['device_id'], isA<String>());
    expect(request['created_at'], '2026-10-17T00:00:00.000Z');
    final bills = request['bills'] as List<dynamic>;
    expect(bills, hasLength(1));
    expect(
      bills.single as Map<String, dynamic>,
      containsPair('name', 'Spotify'),
    );
  });

  test('selesai bootstrap hanya membersihkan outbox dalam snapshot', () async {
    await database.insertBill(
      _bill(id: '0199e7d0-0000-7000-8000-000000000010', name: 'Spotify'),
    );
    final prepared = await database.prepareSyncBootstrap(
      now: DateTime.utc(2026, 10, 17),
    );
    await database.insertBill(
      _bill(id: '0199e7d0-0000-7000-8000-000000000011', name: 'Internet'),
    );

    await database.completeSyncBootstrap(
      bootstrapId: prepared!.bootstrapId,
      serverSequences: const [1, 4, 3],
      completedAt: DateTime.utc(2026, 10, 17, 1),
    );

    final pending = await database.getPendingSyncOperations();
    expect(pending, hasLength(1));
    expect(pending.single.entityId.value, endsWith('11'));
    expect((await database.getLocalSyncState()).lastPulledSequence, 4);
    expect(await database.prepareSyncBootstrap(), isNull);
    final row = await database.select(database.syncStates).getSingle();
    expect(row.bootstrapId, prepared.bootstrapId.value);
    expect(row.bootstrapPayloadJson, isNull);
    expect(row.bootstrapOutboxSequence, isNull);
    expect(row.bootstrapCompletedAtMs, isNotNull);
  });
}

Bill _bill({required String id, required String name}) {
  return Bill(
    id: EntityId.fromString(id),
    name: name,
    category: 'Langganan',
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
