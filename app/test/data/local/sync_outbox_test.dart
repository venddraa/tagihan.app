import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tagihan_vendra/data/local/app_database.dart';
import 'package:tagihan_vendra/data/local/sync_operation.dart';
import 'package:tagihan_vendra/domain/bill.dart';
import 'package:tagihan_vendra/domain/calendar_date.dart';
import 'package:tagihan_vendra/domain/entity_id.dart';
import 'package:tagihan_vendra/domain/money.dart';
import 'package:tagihan_vendra/domain/payment.dart';

void main() {
  test(
    'device ID dibuat sekali dan bertahan setelah database dibuka ulang',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'tagihan-sync-state-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final file = File('${directory.path}/tagihan.sqlite');

      final firstDatabase = AppDatabase(NativeDatabase(file));
      final firstState = await firstDatabase.getLocalSyncState();
      await firstDatabase.close();

      final secondDatabase = AppDatabase(NativeDatabase(file));
      addTearDown(secondDatabase.close);
      final secondState = await secondDatabase.getLocalSyncState();

      expect(secondState.deviceId, firstState.deviceId);
      expect(secondState.createdAt, firstState.createdAt);
      expect(secondState.lastPulledSequence, 0);
    },
  );

  test('create, update, dan archive masuk outbox secara berurutan', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final source = _bill(billingCycle: BillingCycle.oneTime);

    await database.insertBill(source);
    final updated = _copyBill(
      source,
      name: 'Lisensi diperbarui',
      updatedAt: DateTime.utc(2026, 10, 2),
      version: 2,
    );
    await database.updateBill(updated);
    await database.archiveBill(updated.id, DateTime.utc(2026, 10, 3));

    final operations = await database.getPendingSyncOperations();
    expect(operations.map((operation) => operation.localSequence), [1, 2, 3]);
    expect(operations.map((operation) => operation.operationType), [
      SyncOperationType.billCreate,
      SyncOperationType.billUpdate,
      SyncOperationType.billArchive,
    ]);
    expect(operations.map((operation) => operation.baseVersion), [0, 1, 2]);
    expect(
      operations.map((operation) => operation.operationId).toSet(),
      hasLength(3),
    );
    expect(operations.last.decodePayload(), containsPair('status', 'archived'));
    expect(operations.last.decodePayload(), containsPair('version', 3));
    expect(
      operations.first.decodePayload(),
      containsPair('billing_cycle', 'one_time'),
    );
  });

  test(
    'record payment membuat satu operasi atomik berisi dua snapshot',
    () async {
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      final bill = _bill();
      final payment = Payment(
        id: EntityId.fromString('01890f47-3d7a-7a41-8585-2ec0a6634f2a'),
        billId: bill.id,
        amount: bill.amount,
        dueDate: bill.nextDueDate,
        paidAt: DateTime.utc(2026, 10, 15),
        notes: 'Dibayar manual',
        createdAt: DateTime.utc(2026, 10, 15),
        updatedAt: DateTime.utc(2026, 10, 15),
        version: 1,
      );

      await database.insertBill(bill);
      await database.recordPayment(payment);

      final operations = await database.getPendingSyncOperations();
      expect(operations, hasLength(2));
      final operation = operations.last;
      expect(operation.operationType, SyncOperationType.paymentRecord);
      expect(operation.entityType, SyncEntityType.payment);
      expect(operation.entityId, payment.id);
      expect(operation.baseVersion, 0);
      final payload = operation.decodePayload();
      final paymentSnapshot = Map<String, dynamic>.from(
        payload['payment']! as Map,
      );
      final billSnapshot = Map<String, dynamic>.from(payload['bill']! as Map);
      expect(payload['bill_base_version'], 1);
      expect(paymentSnapshot['id'], payment.id.value);
      expect(billSnapshot['next_due_date'], '2026-11-25');
      expect(billSnapshot['version'], 2);
    },
  );

  test('mutation dibatalkan jika penulisan outbox gagal', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    await database.getLocalSyncState();
    await database.customStatement('''
      CREATE TRIGGER reject_sync_outbox
      BEFORE INSERT ON sync_outbox
      BEGIN
        SELECT RAISE(ABORT, 'reject outbox');
      END
    ''');
    final bill = _bill();

    await expectLater(database.insertBill(bill), throwsA(isA<Exception>()));

    expect(await database.findBillById(bill.id), isNull);
    expect(await database.getPendingSyncOperations(), isEmpty);
  });

  test(
    'update dengan version tidak berurutan tidak mengubah data atau outbox',
    () async {
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      final bill = _bill();
      await database.insertBill(bill);
      final invalidUpdate = _copyBill(
        bill,
        name: 'Versi terlewat',
        updatedAt: DateTime.utc(2026, 10, 3),
        version: 3,
      );

      await expectLater(
        database.updateBill(invalidUpdate),
        throwsA(isA<StateError>()),
      );

      expect((await database.findBillById(bill.id))!.name, bill.name);
      expect(await database.getPendingSyncOperations(), hasLength(1));
    },
  );
}

Bill _bill({BillingCycle billingCycle = BillingCycle.monthly}) {
  return Bill(
    id: EntityId.fromString('01890f47-3d7a-7c53-bb3c-9d6ec2f1a6b0'),
    name: 'Spotify',
    category: 'Hiburan',
    amount: Money(minorUnits: 59990, currency: Currency.idr),
    billingCycle: billingCycle,
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
