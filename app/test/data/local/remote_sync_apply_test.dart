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
const secondPaymentId = '0199e7d0-0000-7000-8000-000000000012';
const operationId = '0199e7d0-0000-7000-8000-000000000020';
const secondOperationId = '0199e7d0-0000-7000-8000-000000000021';

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

  test('memilih versi hub membuang operation lokal yang berbenturan', () async {
    final local = _bill(name: 'Spotify Lokal');
    await database.insertBill(local);
    final remote = _bill(name: 'Spotify Remote');
    await database.applyRemoteSyncPage(
      changes: [
        _change(1, SyncEntityType.bill, remote.id, 1, _billMap(remote)),
      ],
      nextCursor: 1,
    );
    final groups = await database.watchUnresolvedSyncConflicts().first;

    expect(groups, hasLength(1));
    expect(groups.single.entries.single.localPayload, isNotNull);
    await database.resolveSyncConflict(
      operationId: groups.single.operationId,
      resolution: SyncConflictResolution.useRemote,
      resolvedAt: DateTime.utc(2026, 10, 18),
    );

    expect((await database.findBillById(local.id))!.name, 'Spotify Remote');
    expect(await database.getPendingSyncOperations(), isEmpty);
    expect(await database.countUnresolvedSyncConflicts(), 0);
  });

  test(
    'memilih versi lokal membuat operation baru di atas versi hub',
    () async {
      final local = _bill(name: 'Spotify Lokal');
      await database.insertBill(local);
      final originalOperation =
          (await database.getPendingSyncOperations()).single;
      final remote = _bill(name: 'Spotify Remote');
      await database.applyRemoteSyncPage(
        changes: [
          _change(1, SyncEntityType.bill, remote.id, 1, _billMap(remote)),
        ],
        nextCursor: 1,
      );
      final group =
          (await database.watchUnresolvedSyncConflicts().first).single;

      await database.resolveSyncConflict(
        operationId: group.operationId,
        resolution: SyncConflictResolution.keepLocal,
        resolvedAt: DateTime.utc(2026, 10, 18),
      );

      final resolved = (await database.findBillById(local.id))!;
      expect(resolved.name, 'Spotify Lokal');
      expect(resolved.version, 2);
      final pending = await database.getPendingSyncOperations();
      expect(pending, hasLength(1));
      expect(pending.single.operationId, isNot(originalOperation.operationId));
      expect(pending.single.operationType, SyncOperationType.billUpdate);
      expect(pending.single.baseVersion, 1);
      expect(await database.countUnresolvedSyncConflicts(), 0);
    },
  );

  test('snapshot lokal tanpa outbox tetap dapat direbase', () async {
    final initial = _bill();
    await database.applyRemoteSyncPage(
      changes: [
        _change(1, SyncEntityType.bill, initial.id, 1, _billMap(initial)),
      ],
      nextCursor: 1,
    );
    final local = _bill(name: 'Spotify Lokal', version: 2);
    await database.updateBill(local);
    final localOperation = (await database.getPendingSyncOperations()).single;
    await database.acknowledgeSyncOperations([localOperation.operationId]);
    final remote = _bill(name: 'Spotify Remote', version: 2);
    await database.applyRemoteSyncPage(
      changes: [
        _change(
          2,
          SyncEntityType.bill,
          remote.id,
          2,
          _billMap(remote),
          remoteOperationId: secondOperationId,
        ),
      ],
      nextCursor: 2,
    );
    final group = (await database.watchUnresolvedSyncConflicts().first).single;

    await database.resolveSyncConflict(
      operationId: group.operationId,
      resolution: SyncConflictResolution.keepLocal,
      resolvedAt: DateTime.utc(2026, 10, 18),
    );

    final resolved = (await database.findBillById(local.id))!;
    expect(resolved.name, 'Spotify Lokal');
    expect(resolved.version, 3);
    final pending = await database.getPendingSyncOperations();
    expect(pending.single.baseVersion, 2);
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

  test('payment lokal direbase tanpa memajukan tagihan dua kali', () async {
    final initialBill = _bill();
    await database.applyRemoteSyncPage(
      changes: [
        _change(
          1,
          SyncEntityType.bill,
          initialBill.id,
          1,
          _billMap(initialBill),
        ),
      ],
      nextCursor: 1,
    );
    final localPayment = _payment(
      id: EntityId.fromString(secondPaymentId),
      dueDate: CalendarDate(2026, 10, 25),
    );
    await database.recordPayment(localPayment);
    final remoteBill = _bill(
      version: 2,
      nextDueDate: CalendarDate(2026, 11, 25),
    );
    final remotePayment = _payment(dueDate: CalendarDate(2026, 10, 25));

    final summary = await database.applyRemoteSyncPage(
      changes: [
        _change(
          2,
          SyncEntityType.payment,
          remotePayment.id,
          1,
          _paymentMap(remotePayment),
          remoteOperationId: secondOperationId,
        ),
        _change(
          3,
          SyncEntityType.bill,
          remoteBill.id,
          2,
          _billMap(remoteBill),
          remoteOperationId: secondOperationId,
        ),
      ],
      nextCursor: 3,
    );
    expect(summary.conflicts, 2);
    expect(await database.countUnresolvedSyncConflicts(), 1);
    final group = (await database.watchUnresolvedSyncConflicts().first).single;

    await database.resolveSyncConflict(
      operationId: group.operationId,
      resolution: SyncConflictResolution.keepLocal,
      resolvedAt: DateTime.utc(2026, 10, 18),
    );

    expect(
      (await database.findBillById(initialBill.id))!.nextDueDate,
      CalendarDate(2026, 11, 25),
    );
    expect(await database.findPaymentById(remotePayment.id), isNotNull);
    expect(await database.findPaymentById(localPayment.id), isNotNull);
    final pending = await database.getPendingSyncOperations();
    expect(pending, hasLength(1));
    expect(pending.single.entityId, localPayment.id);
    final payload = pending.single.decodePayload();
    expect(payload['bill_base_version'], 2);
    expect((payload['bill'] as Map<String, dynamic>)['version'], 2);
    expect(await database.countUnresolvedSyncConflicts(), 0);
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
  Map<String, Object?> payload, {
  String remoteOperationId = operationId,
}) {
  return RemoteSyncChange(
    serverSequence: sequence,
    operationId: EntityId.fromString(remoteOperationId),
    entityType: entityType,
    entityId: entityId,
    version: version,
    payload: payload,
    createdAt: DateTime.utc(2026, 10, 17),
  );
}

Bill _bill({
  String name = 'Spotify',
  int version = 1,
  CalendarDate? nextDueDate,
}) {
  return Bill(
    id: EntityId.fromString(billId),
    name: name,
    category: 'Hiburan',
    amount: Money(minorUnits: 59990, currency: Currency.idr),
    billingCycle: BillingCycle.monthly,
    nextDueDate: nextDueDate ?? CalendarDate(2026, 10, 25),
    startDate: CalendarDate(2026, 1, 25),
    status: BillStatus.active,
    createdAt: DateTime.utc(2026, 10, 1),
    updatedAt: DateTime.utc(2026, 10, version),
    version: version,
  );
}

Payment _payment({
  EntityId? id,
  EntityId? bill,
  CalendarDate? dueDate,
  int version = 1,
}) {
  return Payment(
    id: id ?? EntityId.fromString(paymentId),
    billId: bill ?? EntityId.fromString(billId),
    amount: Money(minorUnits: 59990, currency: Currency.idr),
    dueDate: dueDate ?? CalendarDate(2026, 9, 25),
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
