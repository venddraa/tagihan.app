import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tagihan_vendra/data/local/app_database.dart';
import 'package:tagihan_vendra/data/local/sync_operation.dart';
import 'package:tagihan_vendra/domain/bill.dart';
import 'package:tagihan_vendra/domain/calendar_date.dart';
import 'package:tagihan_vendra/domain/entity_id.dart';
import 'package:tagihan_vendra/domain/money.dart';
import 'package:tagihan_vendra/domain/payment.dart';

const billId = '0199e7d0-0000-7000-8000-000000000010';
const paymentId = '0199e7d0-0000-7000-8000-000000000011';
const operationId = '0199e7d0-0000-7000-8000-000000000020';

void main() {
  late AppDatabase database;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() => database.close());

  test(
    'menerapkan Bill dan Payment dengan operation sama secara atomik',
    () async {
      final bill = _bill(version: 4);
      final payment = _payment(version: 2);

      final summary = await database.applyRemoteSyncPage(
        changes: [
          _change(
            1,
            SyncEntityType.bill,
            bill.id,
            bill.version,
            _billMap(bill),
          ),
          _change(
            2,
            SyncEntityType.payment,
            payment.id,
            payment.version,
            _paymentMap(payment),
          ),
        ],
        nextCursor: 2,
        appliedAt: DateTime.utc(2026, 10, 17, 1),
      );

      expect(summary.applied, 2);
      expect(summary.ignored, 0);
      expect(summary.conflicts, 0);
      expect((await database.findBillById(bill.id))!.version, 4);
      expect((await database.findPaymentById(payment.id))!.version, 2);
      expect(
        await database.select(database.appliedOperations).get(),
        hasLength(2),
      );
      expect(await database.select(database.syncConflicts).get(), isEmpty);
      expect((await database.getLocalSyncState()).lastPulledSequence, 2);
      expect(await database.getPendingSyncOperations(), isEmpty);
    },
  );

  test('menerapkan update remote dengan version berikutnya', () async {
    final first = _bill();
    await database.applyRemoteSyncPage(
      changes: [_change(1, SyncEntityType.bill, first.id, 1, _billMap(first))],
      nextCursor: 1,
    );
    final second = _bill(name: 'Spotify Premium', version: 2);

    final summary = await database.applyRemoteSyncPage(
      changes: [
        _change(2, SyncEntityType.bill, second.id, 2, _billMap(second)),
      ],
      nextCursor: 2,
    );

    expect(summary.applied, 1);
    expect((await database.findBillById(first.id))!.name, 'Spotify Premium');
    expect(await database.getPendingSyncOperations(), isEmpty);
  });

  test('conflict outbox lokal disimpan tanpa menimpa Bill', () async {
    final local = _bill(name: 'Spotify Lokal');
    await database.insertBill(local);
    final remote = _bill(name: 'Spotify Remote');

    final summary = await database.applyRemoteSyncPage(
      changes: [
        _change(1, SyncEntityType.bill, remote.id, 1, _billMap(remote)),
      ],
      nextCursor: 1,
      appliedAt: DateTime.utc(2026, 10, 17, 2),
    );

    expect(summary.conflicts, 1);
    expect((await database.findBillById(local.id))!.name, 'Spotify Lokal');
    expect(await database.getPendingSyncOperations(), hasLength(1));
    final conflicts = await database.select(database.syncConflicts).get();
    expect(conflicts, hasLength(1));
    expect(conflicts.single.reason, 'pending_local_change');
    expect(conflicts.single.localVersion, 1);
    expect(conflicts.single.remoteVersion, 1);
    expect((await database.getLocalSyncState()).lastPulledSequence, 1);
  });

  test('conflict satu bagian menahan seluruh operation pembayaran', () async {
    final localBill = _bill(name: 'Spotify Lokal');
    await database.insertBill(localBill);
    final remoteBill = _bill(name: 'Spotify Remote');
    final remotePayment = _payment();

    final summary = await database.applyRemoteSyncPage(
      changes: [
        _change(
          1,
          SyncEntityType.payment,
          remotePayment.id,
          1,
          _paymentMap(remotePayment),
        ),
        _change(2, SyncEntityType.bill, remoteBill.id, 1, _billMap(remoteBill)),
      ],
      nextCursor: 2,
    );

    expect(summary.applied, 0);
    expect(summary.conflicts, 2);
    expect(await database.findPaymentById(remotePayment.id), isNull);
    expect((await database.findBillById(localBill.id))!.name, 'Spotify Lokal');
    final conflicts = await database.select(database.syncConflicts).get();
    expect(conflicts, hasLength(2));
    expect(
      conflicts.map((conflict) => conflict.reason),
      containsAll(['operation_conflict', 'pending_local_change']),
    );
    expect((await database.getLocalSyncState()).lastPulledSequence, 2);
  });

  test(
    'echo operation lokal yang sudah punya update berikutnya diabaikan',
    () async {
      final original = _bill();
      await database.insertBill(original);
      final firstOperation = (await database.getPendingSyncOperations()).first;
      final updated = _bill(name: 'Spotify Lokal', version: 2);
      await database.updateBill(updated);

      final summary = await database.applyRemoteSyncPage(
        changes: [
          RemoteSyncChange(
            serverSequence: 1,
            operationId: firstOperation.operationId,
            entityType: SyncEntityType.bill,
            entityId: original.id,
            version: 1,
            payload: _billMap(original),
            createdAt: DateTime.utc(2026, 10, 17),
          ),
        ],
        nextCursor: 1,
      );

      expect(summary.ignored, 1);
      expect(summary.conflicts, 0);
      expect((await database.findBillById(original.id))!.version, 2);
      expect(await database.select(database.syncConflicts).get(), isEmpty);
    },
  );

  test(
    'kegagalan satu change membatalkan seluruh halaman dan cursor',
    () async {
      final validBill = _bill();
      final missingBillPayment = _payment(
        bill: EntityId.fromString('0199e7d0-0000-7000-8000-000000000099'),
      );

      await expectLater(
        database.applyRemoteSyncPage(
          changes: [
            _change(
              1,
              SyncEntityType.bill,
              validBill.id,
              1,
              _billMap(validBill),
            ),
            _change(
              2,
              SyncEntityType.payment,
              missingBillPayment.id,
              1,
              _paymentMap(missingBillPayment),
            ),
          ],
          nextCursor: 2,
        ),
        throwsA(isA<StateError>()),
      );

      expect(await database.findBillById(validBill.id), isNull);
      expect(await database.findPaymentById(missingBillPayment.id), isNull);
      expect(await database.select(database.appliedOperations).get(), isEmpty);
      expect((await database.getLocalSyncState()).lastPulledSequence, 0);
    },
  );
}

RemoteSyncChange _change(
  int sequence,
  SyncEntityType entityType,
  EntityId entityId,
  int version,
  Map<String, Object?> payload,
) {
  return RemoteSyncChange(
    serverSequence: sequence,
    operationId: EntityId.fromString(operationId),
    entityType: entityType,
    entityId: entityId,
    version: version,
    payload: payload,
    createdAt: DateTime.utc(2026, 10, 17),
  );
}

Bill _bill({String name = 'Spotify', int version = 1}) {
  return Bill(
    id: EntityId.fromString(billId),
    name: name,
    category: 'Hiburan',
    amount: Money(minorUnits: 59990, currency: Currency.idr),
    billingCycle: BillingCycle.monthly,
    nextDueDate: CalendarDate(2026, 10, 25),
    startDate: CalendarDate(2026, 1, 25),
    status: BillStatus.active,
    createdAt: DateTime.utc(2026, 10, 1),
    updatedAt: DateTime.utc(2026, 10, version),
    version: version,
  );
}

Payment _payment({EntityId? bill, int version = 1}) {
  return Payment(
    id: EntityId.fromString(paymentId),
    billId: bill ?? EntityId.fromString(billId),
    amount: Money(minorUnits: 59990, currency: Currency.idr),
    dueDate: CalendarDate(2026, 9, 25),
    paidAt: DateTime.utc(2026, 9, 20),
    createdAt: DateTime.utc(2026, 9, 20),
    updatedAt: DateTime.utc(2026, 9, 20 + version - 1),
    version: version,
  );
}

Map<String, Object?> _billMap(Bill bill) =>
    (jsonDecode(encodeBillSnapshot(bill)) as Map<String, dynamic>).cast();

Map<String, Object?> _paymentMap(Payment payment) =>
    (jsonDecode(encodePaymentSnapshot(payment)) as Map<String, dynamic>).cast();
