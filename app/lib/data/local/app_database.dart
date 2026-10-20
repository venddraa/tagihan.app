// ignore_for_file: recursive_getters

import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:tagihan_vendra/domain/bill.dart';
import 'package:tagihan_vendra/domain/billing_schedule.dart';
import 'package:tagihan_vendra/domain/calendar_date.dart';
import 'package:tagihan_vendra/domain/entity_id.dart';
import 'package:tagihan_vendra/domain/money.dart';
import 'package:tagihan_vendra/domain/payment.dart';

import 'app_database.steps.dart';
import 'sync_operation.dart';

part 'app_database.g.dart';

@DataClassName('BillRow')
@TableIndex(
  name: 'bills_status_next_due_date',
  columns: {#status, #nextDueDate},
)
@TableIndex(name: 'bills_deleted_at_ms', columns: {#deletedAtMs})
class Bills extends Table {
  TextColumn get id => text()();

  TextColumn get name => text()();

  TextColumn get category => text().nullable()();

  IntColumn get amountMinorUnits =>
      integer().check(amountMinorUnits.isBiggerOrEqualValue(0))();

  TextColumn get currency =>
      text().check(currency.isIn(const ['IDR', 'USD', 'EUR']))();

  TextColumn get billingCycle => text().check(
    billingCycle.isIn(const ['one_time', 'weekly', 'monthly', 'yearly']),
  )();

  TextColumn get nextDueDate => text()();

  TextColumn get startDate => text()();

  TextColumn get status =>
      text().check(status.isIn(const ['active', 'paused', 'archived']))();

  TextColumn get notes => text().nullable()();

  IntColumn get createdAtMs => integer()();

  IntColumn get updatedAtMs => integer()();

  IntColumn get deletedAtMs => integer().nullable()();

  IntColumn get version => integer().check(version.isBiggerOrEqualValue(1))();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('PaymentRow')
@TableIndex(name: 'payments_bill_id_due_date', columns: {#billId, #dueDate})
@TableIndex(name: 'payments_paid_at_ms', columns: {#paidAtMs})
@TableIndex(name: 'payments_deleted_at_ms', columns: {#deletedAtMs})
class Payments extends Table {
  TextColumn get id => text()();

  TextColumn get billId => text().references(Bills, #id)();

  IntColumn get amountMinorUnits =>
      integer().check(amountMinorUnits.isBiggerOrEqualValue(0))();

  TextColumn get currency =>
      text().check(currency.isIn(const ['IDR', 'USD', 'EUR']))();

  TextColumn get dueDate => text()();

  IntColumn get paidAtMs => integer()();

  TextColumn get notes => text().nullable()();

  IntColumn get createdAtMs => integer()();

  IntColumn get updatedAtMs => integer()();

  IntColumn get deletedAtMs => integer().nullable()();

  IntColumn get version => integer().check(version.isBiggerOrEqualValue(1))();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('SyncOutboxRow')
@TableIndex(name: 'sync_outbox_entity', columns: {#entityType, #entityId})
class SyncOutbox extends Table {
  IntColumn get localSequence => integer().autoIncrement()();

  TextColumn get operationId => text().unique()();

  TextColumn get entityType =>
      text().check(entityType.isIn(const ['bill', 'payment']))();

  TextColumn get entityId => text()();

  TextColumn get operationType => text().check(
    operationType.isIn(const [
      'bill.create',
      'bill.update',
      'bill.archive',
      'payment.record',
    ]),
  )();

  IntColumn get baseVersion =>
      integer().check(baseVersion.isBiggerOrEqualValue(0))();

  TextColumn get payloadJson => text()();

  IntColumn get createdAtMs => integer()();

  @override
  String get tableName => 'sync_outbox';
}

@DataClassName('SyncStateRow')
class SyncStates extends Table {
  IntColumn get id =>
      integer().withDefault(const Constant(1)).check(id.equals(1))();

  TextColumn get deviceId => text()();

  IntColumn get lastPulledSequence => integer()
      .withDefault(const Constant(0))
      .check(lastPulledSequence.isBiggerOrEqualValue(0))();

  IntColumn get createdAtMs => integer()();

  TextColumn get bootstrapId => text().nullable()();

  TextColumn get bootstrapPayloadJson => text().nullable()();

  IntColumn get bootstrapOutboxSequence => integer().nullable()();

  IntColumn get bootstrapCreatedAtMs => integer().nullable()();

  IntColumn get bootstrapCompletedAtMs => integer().nullable()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  String get tableName => 'sync_state';
}

@DataClassName('AppliedOperationRow')
@TableIndex(name: 'applied_operations_operation', columns: {#operationId})
class AppliedOperations extends Table {
  TextColumn get operationId => text()();

  IntColumn get serverSequence =>
      integer().check(serverSequence.isBiggerOrEqualValue(1))();

  TextColumn get entityType =>
      text().check(entityType.isIn(const ['bill', 'payment']))();

  TextColumn get entityId => text()();

  IntColumn get version => integer().check(version.isBiggerOrEqualValue(1))();

  IntColumn get appliedAtMs => integer()();

  @override
  Set<Column> get primaryKey => {serverSequence};
}

@DataClassName('SyncConflictRow')
@TableIndex(
  name: 'sync_conflicts_entity',
  columns: {#entityType, #entityId, #resolvedAtMs},
)
class SyncConflicts extends Table {
  IntColumn get serverSequence =>
      integer().check(serverSequence.isBiggerOrEqualValue(1))();

  TextColumn get operationId => text()();

  TextColumn get entityType =>
      text().check(entityType.isIn(const ['bill', 'payment']))();

  TextColumn get entityId => text()();

  TextColumn get reason => text().check(
    reason.isIn(const [
      'pending_local_change',
      'same_version_different_payload',
      'version_gap',
      'operation_conflict',
    ]),
  )();

  IntColumn get localVersion => integer().nullable()();

  IntColumn get remoteVersion =>
      integer().check(remoteVersion.isBiggerOrEqualValue(1))();

  TextColumn get localPayloadJson => text().nullable()();

  TextColumn get remotePayloadJson => text()();

  IntColumn get detectedAtMs => integer()();

  IntColumn get resolvedAtMs => integer().nullable()();

  @override
  Set<Column> get primaryKey => {serverSequence};

  @override
  String get tableName => 'sync_conflicts';
}

final class PaymentHistoryEntry {
  const PaymentHistoryEntry({required this.payment, required this.billName});

  final Payment payment;
  final String billName;
}

@DriftDatabase(
  tables: [
    Bills,
    Payments,
    SyncOutbox,
    SyncStates,
    AppliedOperations,
    SyncConflicts,
  ],
)
final class AppDatabase extends _$AppDatabase {
  AppDatabase(super.executor);

  @override
  int get schemaVersion => 5;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (migrator) => migrator.createAll(),
    onUpgrade: stepByStep(
      from1To2: (migrator, schema) async {
        await migrator.createTable(schema.payments);
        await migrator.createIndex(schema.paymentsBillIdDueDate);
        await migrator.createIndex(schema.paymentsPaidAtMs);
        await migrator.createIndex(schema.paymentsDeletedAtMs);
      },
      from2To3: (migrator, schema) async {
        await migrator.createTable(schema.syncOutbox);
        await migrator.createIndex(schema.syncOutboxEntity);
        await migrator.createTable(schema.syncState);
        await migrator.createTable(schema.appliedOperations);
      },
      from3To4: (migrator, schema) async {
        await migrator.addColumn(
          schema.syncState,
          schema.syncState.bootstrapId,
        );
        await migrator.addColumn(
          schema.syncState,
          schema.syncState.bootstrapPayloadJson,
        );
        await migrator.addColumn(
          schema.syncState,
          schema.syncState.bootstrapOutboxSequence,
        );
        await migrator.addColumn(
          schema.syncState,
          schema.syncState.bootstrapCreatedAtMs,
        );
        await migrator.addColumn(
          schema.syncState,
          schema.syncState.bootstrapCompletedAtMs,
        );
      },
      from4To5: (migrator, schema) async {
        // Belum ada code sebelum v5 yang menulis tabel ini. Tabel dibuat ulang
        // agar satu operation dapat mencatat beberapa server sequence.
        await migrator.deleteTable('applied_operations');
        await migrator.createTable(schema.appliedOperations);
        await migrator.createIndex(schema.appliedOperationsOperation);
        await migrator.createTable(schema.syncConflicts);
        await migrator.createIndex(schema.syncConflictsEntity);
      },
    ),
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
      if (details.versionNow < 3) {
        return;
      }
      final now = DateTime.now().toUtc();
      await into(syncStates).insert(
        SyncStatesCompanion.insert(
          deviceId: EntityId.generate(now: now).value,
          createdAtMs: now.millisecondsSinceEpoch,
        ),
        mode: InsertMode.insertOrIgnore,
      );
    },
  );

  Future<void> insertBill(Bill bill) async {
    await transaction(() async {
      await into(bills).insert(_billToCompanion(bill));
      await _enqueueOperation(
        entityType: SyncEntityType.bill,
        entityId: bill.id,
        operationType: SyncOperationType.billCreate,
        baseVersion: 0,
        payloadJson: encodeBillSnapshot(bill),
        createdAt: bill.updatedAt,
      );
    });
  }

  Future<Bill?> findBillById(EntityId id) async {
    final row = await (select(
      bills,
    )..where((table) => table.id.equals(id.value))).getSingleOrNull();

    return row == null ? null : _billFromRow(row);
  }

  Future<List<Bill>> getActiveBills() async {
    final rows =
        await (select(bills)
              ..where(
                (table) =>
                    table.status.equals('active') & table.deletedAtMs.isNull(),
              )
              ..orderBy([
                (table) => OrderingTerm.asc(table.nextDueDate),
                (table) => OrderingTerm.asc(table.name),
              ]))
            .get();

    return rows.map(_billFromRow).toList(growable: false);
  }

  Stream<List<Bill>> watchActiveBills() {
    final query = select(bills)
      ..where(
        (table) => table.status.equals('active') & table.deletedAtMs.isNull(),
      )
      ..orderBy([
        (table) => OrderingTerm.asc(table.nextDueDate),
        (table) => OrderingTerm.asc(table.name),
      ]);

    return query.watch().map(
      (rows) => rows.map(_billFromRow).toList(growable: false),
    );
  }

  Future<List<Bill>> getOverdueBills(CalendarDate today) async {
    final activeBills = await getActiveBills();
    return activeBills
        .where((bill) => isBillOverdue(bill, today))
        .toList(growable: false);
  }

  Future<List<Bill>> getUpcomingBills(
    CalendarDate today, {
    int withinDays = 30,
  }) async {
    final activeBills = await getActiveBills();
    return activeBills
        .where((bill) => isBillUpcoming(bill, today, withinDays: withinDays))
        .toList(growable: false);
  }

  Future<void> updateBill(Bill bill) async {
    await transaction(() async {
      final current = await findBillById(bill.id);
      if (current == null || current.isDeleted) {
        throw StateError('Tagihan yang akan diperbarui tidak ditemukan.');
      }
      if (bill.version != current.version + 1) {
        throw StateError('Version tagihan tidak berurutan.');
      }

      await _updateBillRow(bill);
      await _enqueueOperation(
        entityType: SyncEntityType.bill,
        entityId: bill.id,
        operationType: SyncOperationType.billUpdate,
        baseVersion: current.version,
        payloadJson: encodeBillSnapshot(bill),
        createdAt: bill.updatedAt,
      );
    });
  }

  Future<void> archiveBill(EntityId id, DateTime archivedAt) async {
    if (!archivedAt.isUtc) {
      throw ArgumentError.value(
        archivedAt,
        'archivedAt',
        'Waktu archive harus menggunakan UTC.',
      );
    }

    await transaction(() async {
      final current = await findBillById(id);
      if (current == null || current.isDeleted) {
        throw StateError('Tagihan yang akan diarsipkan tidak ditemukan.');
      }

      final archived = Bill(
        id: current.id,
        name: current.name,
        category: current.category,
        amount: current.amount,
        billingCycle: current.billingCycle,
        nextDueDate: current.nextDueDate,
        startDate: current.startDate,
        status: BillStatus.archived,
        notes: current.notes,
        createdAt: current.createdAt,
        updatedAt: archivedAt,
        deletedAt: current.deletedAt,
        version: current.version + 1,
      );

      await _updateBillRow(archived);
      await _enqueueOperation(
        entityType: SyncEntityType.bill,
        entityId: archived.id,
        operationType: SyncOperationType.billArchive,
        baseVersion: current.version,
        payloadJson: encodeBillSnapshot(archived),
        createdAt: archivedAt,
      );
    });
  }

  Future<void> recordPayment(Payment payment) async {
    await transaction(() async {
      final bill = await findBillById(payment.billId);
      if (bill == null || bill.isDeleted) {
        throw StateError('Tagihan untuk pembayaran tidak ditemukan.');
      }
      if (payment.amount.currency != bill.amount.currency) {
        throw ArgumentError(
          'Currency pembayaran harus sama dengan currency tagihan.',
        );
      }

      await into(payments).insert(_paymentToCompanion(payment));
      var resultingBill = bill;
      if (bill.isActive && payment.dueDate == bill.nextDueDate) {
        final nextDueDate = calculateNextDueDate(bill);
        final changedAt = payment.createdAt.isAfter(bill.updatedAt)
            ? payment.createdAt
            : bill.updatedAt;
        resultingBill = Bill(
          id: bill.id,
          name: bill.name,
          category: bill.category,
          amount: bill.amount,
          billingCycle: bill.billingCycle,
          nextDueDate: nextDueDate ?? bill.nextDueDate,
          startDate: bill.startDate,
          status: nextDueDate == null ? BillStatus.archived : bill.status,
          notes: bill.notes,
          createdAt: bill.createdAt,
          updatedAt: changedAt,
          deletedAt: bill.deletedAt,
          version: bill.version + 1,
        );
        await _updateBillRow(resultingBill);
      }

      await _enqueueOperation(
        entityType: SyncEntityType.payment,
        entityId: payment.id,
        operationType: SyncOperationType.paymentRecord,
        baseVersion: 0,
        payloadJson: encodePaymentRecord(
          payment: payment,
          bill: resultingBill,
          billBaseVersion: bill.version,
        ),
        createdAt: payment.createdAt,
      );
    });
  }

  Future<LocalSyncState> getLocalSyncState() async {
    final row = await select(syncStates).getSingle();
    return LocalSyncState(
      deviceId: EntityId.fromString(row.deviceId),
      lastPulledSequence: row.lastPulledSequence,
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        row.createdAtMs,
        isUtc: true,
      ),
    );
  }

  Future<PreparedSyncBootstrap?> prepareSyncBootstrap({DateTime? now}) {
    final createdAt = (now ?? DateTime.now()).toUtc();
    return transaction(() async {
      final state = await select(syncStates).getSingle();
      if (state.bootstrapCompletedAtMs != null) {
        return null;
      }
      if (state.bootstrapId != null && state.bootstrapPayloadJson != null) {
        return PreparedSyncBootstrap(
          bootstrapId: EntityId.fromString(state.bootstrapId!),
          requestBody: state.bootstrapPayloadJson!,
        );
      }

      final billRows = await (select(
        bills,
      )..orderBy([(table) => OrderingTerm.asc(table.id)])).get();
      final paymentRows = await (select(
        payments,
      )..orderBy([(table) => OrderingTerm.asc(table.id)])).get();
      final lastOutboxRow =
          await (select(syncOutbox)
                ..orderBy([(table) => OrderingTerm.desc(table.localSequence)])
                ..limit(1))
              .getSingleOrNull();
      final bootstrapId = EntityId.generate(now: createdAt);
      final requestBody = jsonEncode({
        'protocol_version': syncProtocolVersion,
        'bootstrap_id': bootstrapId.value,
        'device_id': state.deviceId,
        'bills': billRows
            .map(_billFromRow)
            .map(encodeBillSnapshot)
            .map(jsonDecode)
            .toList(growable: false),
        'payments': paymentRows
            .map(_paymentFromRow)
            .map(encodePaymentSnapshot)
            .map(jsonDecode)
            .toList(growable: false),
        'created_at': createdAt.toIso8601String(),
      });

      await (update(syncStates)..where((table) => table.id.equals(1))).write(
        SyncStatesCompanion(
          bootstrapId: Value(bootstrapId.value),
          bootstrapPayloadJson: Value(requestBody),
          bootstrapOutboxSequence: Value(lastOutboxRow?.localSequence),
          bootstrapCreatedAtMs: Value(createdAt.millisecondsSinceEpoch),
        ),
      );
      return PreparedSyncBootstrap(
        bootstrapId: bootstrapId,
        requestBody: requestBody,
      );
    });
  }

  Future<void> completeSyncBootstrap({
    required EntityId bootstrapId,
    required Iterable<int> serverSequences,
    DateTime? completedAt,
  }) {
    final completionTime = (completedAt ?? DateTime.now()).toUtc();
    return transaction(() async {
      final state = await select(syncStates).getSingle();
      if (state.bootstrapCompletedAtMs != null) {
        if (state.bootstrapId == bootstrapId.value) return;
        throw StateError('Bootstrap lokal sudah diselesaikan dengan ID lain.');
      }
      if (state.bootstrapId != bootstrapId.value ||
          state.bootstrapPayloadJson == null) {
        throw StateError('Bootstrap lokal yang akan diselesaikan tidak ada.');
      }

      final sequenceValues = serverSequences.toList(growable: false);
      if (sequenceValues.any((sequence) => sequence < 1)) {
        throw ArgumentError.value(
          serverSequences,
          'serverSequences',
          'Server sequence harus bernilai positif.',
        );
      }
      final latestSequence = sequenceValues.fold<int>(
        state.lastPulledSequence,
        (latest, sequence) => sequence > latest ? sequence : latest,
      );
      final throughSequence = state.bootstrapOutboxSequence;
      if (throughSequence != null) {
        await (delete(syncOutbox)..where(
              (table) =>
                  table.localSequence.isSmallerOrEqualValue(throughSequence),
            ))
            .go();
      }
      await (update(syncStates)..where((table) => table.id.equals(1))).write(
        SyncStatesCompanion(
          lastPulledSequence: Value(latestSequence),
          bootstrapPayloadJson: const Value(null),
          bootstrapOutboxSequence: const Value(null),
          bootstrapCompletedAtMs: Value(completionTime.millisecondsSinceEpoch),
        ),
      );
    });
  }

  Future<SyncApplySummary> applyRemoteSyncPage({
    required List<RemoteSyncChange> changes,
    required int nextCursor,
    DateTime? appliedAt,
  }) {
    final applicationTime = (appliedAt ?? DateTime.now()).toUtc();
    return transaction(() async {
      final state = await select(syncStates).getSingle();
      _validateRemotePage(
        changes,
        currentCursor: state.lastPulledSequence,
        nextCursor: nextCursor,
      );
      final pendingImpacts = await _pendingSyncImpacts();
      final blockedChanges = await _blockedRemoteOperationChanges(
        changes,
        pendingImpacts,
      );
      var applied = 0;
      var ignored = 0;
      var conflicts = 0;

      for (final change in changes) {
        final prior =
            await (select(appliedOperations)..where(
                  (table) => table.serverSequence.equals(change.serverSequence),
                ))
                .getSingleOrNull();
        if (prior != null) {
          if (prior.operationId != change.operationId.value ||
              prior.entityType != change.entityType.name ||
              prior.entityId != change.entityId.value ||
              prior.version != change.version) {
            throw StateError(
              'Server sequence sudah dipakai oleh change yang berbeda.',
            );
          }
          ignored++;
          continue;
        }

        final blockedReason = blockedChanges[change.serverSequence];
        final decision = blockedReason == null
            ? switch (change.entityType) {
                SyncEntityType.bill => await _applyRemoteBill(
                  change,
                  pendingImpacts[_syncEntityKey(
                        change.entityType,
                        change.entityId,
                      )] ??
                      const [],
                  applicationTime,
                ),
                SyncEntityType.payment => await _applyRemotePayment(
                  change,
                  pendingImpacts[_syncEntityKey(
                        change.entityType,
                        change.entityId,
                      )] ??
                      const [],
                  applicationTime,
                ),
              }
            : await _recordBlockedRemoteConflict(
                change,
                blockedReason,
                applicationTime,
              );
        switch (decision) {
          case _RemoteApplyDecision.applied:
            applied++;
          case _RemoteApplyDecision.ignored:
            ignored++;
          case _RemoteApplyDecision.conflict:
            conflicts++;
        }

        await into(appliedOperations).insert(
          AppliedOperationsCompanion.insert(
            operationId: change.operationId.value,
            serverSequence: Value(change.serverSequence),
            entityType: change.entityType.name,
            entityId: change.entityId.value,
            version: change.version,
            appliedAtMs: applicationTime.millisecondsSinceEpoch,
          ),
        );
      }

      await (update(syncStates)..where((table) => table.id.equals(1))).write(
        SyncStatesCompanion(lastPulledSequence: Value(nextCursor)),
      );
      return SyncApplySummary(
        applied: applied,
        ignored: ignored,
        conflicts: conflicts,
        nextCursor: nextCursor,
      );
    });
  }

  Future<_RemoteApplyDecision> _applyRemoteBill(
    RemoteSyncChange change,
    List<_PendingSyncImpact> pending,
    DateTime detectedAt,
  ) async {
    final remote = decodeBillSnapshot(change.payload);
    if (remote.id != change.entityId || remote.version != change.version) {
      throw const FormatException('Metadata change Bill tidak sesuai payload.');
    }
    final local = await findBillById(change.entityId);
    final earlyDecision = await _resolvePendingOrOlderChange(
      change: change,
      pending: pending,
      localVersion: local?.version,
      localPayloadJson: local == null ? null : encodeBillSnapshot(local),
      remotePayloadJson: encodeBillSnapshot(remote),
      snapshotsEqual:
          local != null &&
          encodeBillSnapshot(local) == encodeBillSnapshot(remote),
      detectedAt: detectedAt,
    );
    if (earlyDecision != null) return earlyDecision;

    if (local == null) {
      await into(bills).insert(_billToCompanion(remote));
      return _RemoteApplyDecision.applied;
    }
    if (remote.version == local.version + 1) {
      await _updateBillRow(remote);
      return _RemoteApplyDecision.applied;
    }
    return _recordRemoteConflict(
      change: change,
      reason: 'version_gap',
      localVersion: local.version,
      localPayloadJson: encodeBillSnapshot(local),
      remotePayloadJson: encodeBillSnapshot(remote),
      detectedAt: detectedAt,
    );
  }

  Future<Map<int, String>> _blockedRemoteOperationChanges(
    List<RemoteSyncChange> changes,
    Map<String, List<_PendingSyncImpact>> pendingImpacts,
  ) async {
    final groups = <EntityId, List<RemoteSyncChange>>{};
    for (final change in changes) {
      groups.putIfAbsent(change.operationId, () => []).add(change);
    }
    final blocked = <int, String>{};
    for (final group in groups.values.where((value) => value.length > 1)) {
      final reasons = <int, String?>{};
      for (final change in group) {
        reasons[change.serverSequence] = await _previewRemoteConflictReason(
          change,
          pendingImpacts[_syncEntityKey(change.entityType, change.entityId)] ??
              const [],
        );
      }
      if (reasons.values.every((reason) => reason == null)) continue;
      for (final change in group) {
        blocked[change.serverSequence] =
            reasons[change.serverSequence] ?? 'operation_conflict';
      }
    }
    return blocked;
  }

  Future<String?> _previewRemoteConflictReason(
    RemoteSyncChange change,
    List<_PendingSyncImpact> pending,
  ) async {
    final snapshot = await _remoteSnapshotContext(change);
    if (pending.isNotEmpty) {
      final sameOperation = pending.any(
        (impact) => impact.operationId == change.operationId,
      );
      final earliestBaseVersion = pending
          .map((impact) => impact.baseVersion)
          .reduce((first, second) => first < second ? first : second);
      if ((sameOperation || change.version <= earliestBaseVersion) &&
          snapshot.localVersion != null &&
          snapshot.localVersion! >= change.version) {
        return null;
      }
      return 'pending_local_change';
    }
    if (snapshot.localVersion == null ||
        change.version < snapshot.localVersion!) {
      return null;
    }
    if (change.version == snapshot.localVersion) {
      return snapshot.localPayloadJson == snapshot.remotePayloadJson
          ? null
          : 'same_version_different_payload';
    }
    if (change.version == snapshot.localVersion! + 1) return null;
    return 'version_gap';
  }

  Future<_RemoteApplyDecision> _recordBlockedRemoteConflict(
    RemoteSyncChange change,
    String reason,
    DateTime detectedAt,
  ) async {
    final snapshot = await _remoteSnapshotContext(change);
    return _recordRemoteConflict(
      change: change,
      reason: reason,
      localVersion: snapshot.localVersion,
      localPayloadJson: snapshot.localPayloadJson,
      remotePayloadJson: snapshot.remotePayloadJson,
      detectedAt: detectedAt,
    );
  }

  Future<_RemoteSnapshotContext> _remoteSnapshotContext(
    RemoteSyncChange change,
  ) async {
    switch (change.entityType) {
      case SyncEntityType.bill:
        final remote = decodeBillSnapshot(change.payload);
        final local = await findBillById(change.entityId);
        return _RemoteSnapshotContext(
          localVersion: local?.version,
          localPayloadJson: local == null ? null : encodeBillSnapshot(local),
          remotePayloadJson: encodeBillSnapshot(remote),
        );
      case SyncEntityType.payment:
        final remote = decodePaymentSnapshot(change.payload);
        final local = await findPaymentById(change.entityId);
        return _RemoteSnapshotContext(
          localVersion: local?.version,
          localPayloadJson: local == null ? null : encodePaymentSnapshot(local),
          remotePayloadJson: encodePaymentSnapshot(remote),
        );
    }
  }

  Future<_RemoteApplyDecision> _applyRemotePayment(
    RemoteSyncChange change,
    List<_PendingSyncImpact> pending,
    DateTime detectedAt,
  ) async {
    final remote = decodePaymentSnapshot(change.payload);
    if (remote.id != change.entityId || remote.version != change.version) {
      throw const FormatException(
        'Metadata change Payment tidak sesuai payload.',
      );
    }
    final local = await findPaymentById(change.entityId);
    final earlyDecision = await _resolvePendingOrOlderChange(
      change: change,
      pending: pending,
      localVersion: local?.version,
      localPayloadJson: local == null ? null : encodePaymentSnapshot(local),
      remotePayloadJson: encodePaymentSnapshot(remote),
      snapshotsEqual:
          local != null &&
          encodePaymentSnapshot(local) == encodePaymentSnapshot(remote),
      detectedAt: detectedAt,
    );
    if (earlyDecision != null) return earlyDecision;

    final bill = await findBillById(remote.billId);
    if (bill == null) {
      throw StateError('Bill untuk Payment remote belum tersedia.');
    }
    if (local == null) {
      await into(payments).insert(_paymentToCompanion(remote));
      return _RemoteApplyDecision.applied;
    }
    if (remote.version == local.version + 1) {
      final updatedRows =
          await (update(payments)
                ..where((table) => table.id.equals(remote.id.value)))
              .write(_paymentToCompanion(remote));
      if (updatedRows != 1) {
        throw StateError('Payment remote tidak dapat diperbarui.');
      }
      return _RemoteApplyDecision.applied;
    }
    return _recordRemoteConflict(
      change: change,
      reason: 'version_gap',
      localVersion: local.version,
      localPayloadJson: encodePaymentSnapshot(local),
      remotePayloadJson: encodePaymentSnapshot(remote),
      detectedAt: detectedAt,
    );
  }

  Future<_RemoteApplyDecision?> _resolvePendingOrOlderChange({
    required RemoteSyncChange change,
    required List<_PendingSyncImpact> pending,
    required int? localVersion,
    required String? localPayloadJson,
    required String remotePayloadJson,
    required bool snapshotsEqual,
    required DateTime detectedAt,
  }) async {
    if (pending.isNotEmpty) {
      final sameOperation = pending.any(
        (impact) => impact.operationId == change.operationId,
      );
      final earliestBaseVersion = pending
          .map((impact) => impact.baseVersion)
          .reduce((first, second) => first < second ? first : second);
      if ((sameOperation || change.version <= earliestBaseVersion) &&
          localVersion != null &&
          localVersion >= change.version) {
        return _RemoteApplyDecision.ignored;
      }
      return _recordRemoteConflict(
        change: change,
        reason: 'pending_local_change',
        localVersion: localVersion,
        localPayloadJson: localPayloadJson,
        remotePayloadJson: remotePayloadJson,
        detectedAt: detectedAt,
      );
    }
    if (localVersion == null) return null;
    if (change.version < localVersion ||
        (change.version == localVersion && snapshotsEqual)) {
      return _RemoteApplyDecision.ignored;
    }
    if (change.version == localVersion) {
      return _recordRemoteConflict(
        change: change,
        reason: 'same_version_different_payload',
        localVersion: localVersion,
        localPayloadJson: localPayloadJson,
        remotePayloadJson: remotePayloadJson,
        detectedAt: detectedAt,
      );
    }
    return null;
  }

  Future<_RemoteApplyDecision> _recordRemoteConflict({
    required RemoteSyncChange change,
    required String reason,
    required int? localVersion,
    required String? localPayloadJson,
    required String remotePayloadJson,
    required DateTime detectedAt,
  }) async {
    await into(syncConflicts).insert(
      SyncConflictsCompanion.insert(
        serverSequence: Value(change.serverSequence),
        operationId: change.operationId.value,
        entityType: change.entityType.name,
        entityId: change.entityId.value,
        reason: reason,
        localVersion: Value(localVersion),
        remoteVersion: change.version,
        localPayloadJson: Value(localPayloadJson),
        remotePayloadJson: remotePayloadJson,
        detectedAtMs: detectedAt.millisecondsSinceEpoch,
      ),
    );
    return _RemoteApplyDecision.conflict;
  }

  Future<Map<String, List<_PendingSyncImpact>>> _pendingSyncImpacts() async {
    final rows = await (select(
      syncOutbox,
    )..orderBy([(table) => OrderingTerm.asc(table.localSequence)])).get();
    final impacts = <String, List<_PendingSyncImpact>>{};
    for (final row in rows) {
      final operation = _syncOperationFromRow(row);
      _addPendingImpact(
        impacts,
        operation.entityType,
        operation.entityId,
        operation.operationId,
        operation.baseVersion,
      );
      if (operation.operationType == SyncOperationType.paymentRecord) {
        final payload = operation.decodePayload();
        final billPayload = payload['bill'];
        final billBaseVersion = payload['bill_base_version'];
        if (billPayload is! Map ||
            billPayload['id'] is! String ||
            billBaseVersion is! int) {
          throw const FormatException('Payload payment.record lokal rusak.');
        }
        _addPendingImpact(
          impacts,
          SyncEntityType.bill,
          EntityId.fromString(billPayload['id']! as String),
          operation.operationId,
          billBaseVersion,
        );
      }
    }
    return impacts;
  }

  void _addPendingImpact(
    Map<String, List<_PendingSyncImpact>> impacts,
    SyncEntityType entityType,
    EntityId entityId,
    EntityId operationId,
    int baseVersion,
  ) {
    impacts
        .putIfAbsent(_syncEntityKey(entityType, entityId), () => [])
        .add(
          _PendingSyncImpact(
            operationId: operationId,
            baseVersion: baseVersion,
          ),
        );
  }

  Future<List<PendingSyncOperation>> getPendingSyncOperations({
    int limit = 100,
  }) async {
    if (limit < 1 || limit > 100) {
      throw RangeError.range(limit, 1, 100, 'limit');
    }
    final rows =
        await (select(syncOutbox)
              ..orderBy([(table) => OrderingTerm.asc(table.localSequence)])
              ..limit(limit))
            .get();
    return rows.map(_syncOperationFromRow).toList(growable: false);
  }

  Future<int> countPendingSyncOperations() async {
    final count = syncOutbox.localSequence.count();
    final query = selectOnly(syncOutbox)..addColumns([count]);
    return (await query.getSingle()).read(count) ?? 0;
  }

  Future<int> countUnresolvedSyncConflicts() async {
    final count = syncConflicts.serverSequence.count();
    final query = selectOnly(syncConflicts)
      ..addColumns([count])
      ..where(syncConflicts.resolvedAtMs.isNull());
    return (await query.getSingle()).read(count) ?? 0;
  }

  Future<int> acknowledgeSyncOperations(Iterable<EntityId> operationIds) {
    final values = operationIds.map((id) => id.value).toSet();
    if (values.isEmpty) {
      return Future.value(0);
    }
    return (delete(
      syncOutbox,
    )..where((table) => table.operationId.isIn(values))).go();
  }

  Future<void> _updateBillRow(Bill bill) async {
    final updatedRows =
        await (update(bills)..where((table) => table.id.equals(bill.id.value)))
            .write(_billToCompanion(bill));
    if (updatedRows != 1) {
      throw StateError('Tagihan yang akan diperbarui tidak ditemukan.');
    }
  }

  Future<void> _enqueueOperation({
    required SyncEntityType entityType,
    required EntityId entityId,
    required SyncOperationType operationType,
    required int baseVersion,
    required String payloadJson,
    required DateTime createdAt,
  }) async {
    final operationId = EntityId.generate(now: createdAt);
    await into(syncOutbox).insert(
      SyncOutboxCompanion.insert(
        operationId: operationId.value,
        entityType: entityType.name,
        entityId: entityId.value,
        operationType: operationType.wireName,
        baseVersion: baseVersion,
        payloadJson: payloadJson,
        createdAtMs: createdAt.millisecondsSinceEpoch,
      ),
    );
  }

  Future<Payment?> findPaymentById(EntityId id) async {
    final row = await (select(
      payments,
    )..where((table) => table.id.equals(id.value))).getSingleOrNull();

    return row == null ? null : _paymentFromRow(row);
  }

  Future<List<PaymentHistoryEntry>> getPaymentHistory() async {
    return _paymentHistoryQuery().get().then(_paymentHistoryFromRows);
  }

  Stream<List<PaymentHistoryEntry>> watchPaymentHistory() {
    return _paymentHistoryQuery().watch().map(_paymentHistoryFromRows);
  }

  JoinedSelectStatement<HasResultSet, dynamic> _paymentHistoryQuery() {
    return (select(payments)
        .join([innerJoin(bills, bills.id.equalsExp(payments.billId))])
      ..where(payments.deletedAtMs.isNull())
      ..orderBy([
        OrderingTerm.desc(payments.paidAtMs),
        OrderingTerm.desc(payments.createdAtMs),
      ]));
  }

  List<PaymentHistoryEntry> _paymentHistoryFromRows(List<TypedResult> rows) {
    return rows
        .map(
          (row) => PaymentHistoryEntry(
            payment: _paymentFromRow(row.readTable(payments)),
            billName: row.readTable(bills).name,
          ),
        )
        .toList(growable: false);
  }
}

enum _RemoteApplyDecision { applied, ignored, conflict }

final class _PendingSyncImpact {
  const _PendingSyncImpact({
    required this.operationId,
    required this.baseVersion,
  });

  final EntityId operationId;
  final int baseVersion;
}

final class _RemoteSnapshotContext {
  const _RemoteSnapshotContext({
    required this.localVersion,
    required this.localPayloadJson,
    required this.remotePayloadJson,
  });

  final int? localVersion;
  final String? localPayloadJson;
  final String remotePayloadJson;
}

String _syncEntityKey(SyncEntityType entityType, EntityId entityId) =>
    '${entityType.name}:${entityId.value}';

void _validateRemotePage(
  List<RemoteSyncChange> changes, {
  required int currentCursor,
  required int nextCursor,
}) {
  var previousSequence = currentCursor;
  for (final change in changes) {
    if (change.serverSequence <= previousSequence ||
        !change.createdAt.isUtc ||
        change.version < 1) {
      throw const FormatException('Halaman perubahan remote tidak valid.');
    }
    previousSequence = change.serverSequence;
  }
  final expectedCursor = changes.isEmpty ? currentCursor : previousSequence;
  if (nextCursor != expectedCursor) {
    throw const FormatException('Cursor halaman perubahan tidak valid.');
  }
}

PendingSyncOperation _syncOperationFromRow(SyncOutboxRow row) {
  return PendingSyncOperation(
    localSequence: row.localSequence,
    operationId: EntityId.fromString(row.operationId),
    entityType: SyncEntityType.values.byName(row.entityType),
    entityId: EntityId.fromString(row.entityId),
    operationType: SyncOperationType.fromWireName(row.operationType),
    baseVersion: row.baseVersion,
    payloadJson: row.payloadJson,
    createdAt: DateTime.fromMillisecondsSinceEpoch(
      row.createdAtMs,
      isUtc: true,
    ),
  );
}

BillsCompanion _billToCompanion(Bill bill) {
  return BillsCompanion.insert(
    id: bill.id.value,
    name: bill.name,
    category: Value(bill.category),
    amountMinorUnits: bill.amount.minorUnits,
    currency: bill.amount.currency.code,
    billingCycle: _billingCycleToDatabase(bill.billingCycle),
    nextDueDate: bill.nextDueDate.toString(),
    startDate: bill.startDate.toString(),
    status: bill.status.name,
    notes: Value(bill.notes),
    createdAtMs: bill.createdAt.millisecondsSinceEpoch,
    updatedAtMs: bill.updatedAt.millisecondsSinceEpoch,
    deletedAtMs: Value(bill.deletedAt?.millisecondsSinceEpoch),
    version: bill.version,
  );
}

Bill _billFromRow(BillRow row) {
  return Bill(
    id: EntityId.fromString(row.id),
    name: row.name,
    category: row.category,
    amount: Money(
      minorUnits: row.amountMinorUnits,
      currency: _currencyFromDatabase(row.currency),
    ),
    billingCycle: _billingCycleFromDatabase(row.billingCycle),
    nextDueDate: CalendarDate.parse(row.nextDueDate),
    startDate: CalendarDate.parse(row.startDate),
    status: BillStatus.values.byName(row.status),
    notes: row.notes,
    createdAt: DateTime.fromMillisecondsSinceEpoch(
      row.createdAtMs,
      isUtc: true,
    ),
    updatedAt: DateTime.fromMillisecondsSinceEpoch(
      row.updatedAtMs,
      isUtc: true,
    ),
    deletedAt: row.deletedAtMs == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(row.deletedAtMs!, isUtc: true),
    version: row.version,
  );
}

PaymentsCompanion _paymentToCompanion(Payment payment) {
  return PaymentsCompanion.insert(
    id: payment.id.value,
    billId: payment.billId.value,
    amountMinorUnits: payment.amount.minorUnits,
    currency: payment.amount.currency.code,
    dueDate: payment.dueDate.toString(),
    paidAtMs: payment.paidAt.millisecondsSinceEpoch,
    notes: Value(payment.notes),
    createdAtMs: payment.createdAt.millisecondsSinceEpoch,
    updatedAtMs: payment.updatedAt.millisecondsSinceEpoch,
    deletedAtMs: Value(payment.deletedAt?.millisecondsSinceEpoch),
    version: payment.version,
  );
}

Payment _paymentFromRow(PaymentRow row) {
  return Payment(
    id: EntityId.fromString(row.id),
    billId: EntityId.fromString(row.billId),
    amount: Money(
      minorUnits: row.amountMinorUnits,
      currency: _currencyFromDatabase(row.currency),
    ),
    dueDate: CalendarDate.parse(row.dueDate),
    paidAt: DateTime.fromMillisecondsSinceEpoch(row.paidAtMs, isUtc: true),
    notes: row.notes,
    createdAt: DateTime.fromMillisecondsSinceEpoch(
      row.createdAtMs,
      isUtc: true,
    ),
    updatedAt: DateTime.fromMillisecondsSinceEpoch(
      row.updatedAtMs,
      isUtc: true,
    ),
    deletedAt: row.deletedAtMs == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(row.deletedAtMs!, isUtc: true),
    version: row.version,
  );
}

String _billingCycleToDatabase(BillingCycle billingCycle) {
  return switch (billingCycle) {
    BillingCycle.oneTime => 'one_time',
    BillingCycle.weekly => 'weekly',
    BillingCycle.monthly => 'monthly',
    BillingCycle.yearly => 'yearly',
  };
}

BillingCycle _billingCycleFromDatabase(String value) {
  return switch (value) {
    'one_time' => BillingCycle.oneTime,
    'weekly' => BillingCycle.weekly,
    'monthly' => BillingCycle.monthly,
    'yearly' => BillingCycle.yearly,
    _ => throw FormatException('Billing cycle database tidak dikenal.', value),
  };
}

Currency _currencyFromDatabase(String value) {
  return Currency.values.firstWhere(
    (currency) => currency.code == value,
    orElse: () =>
        throw FormatException('Currency database tidak dikenal.', value),
  );
}
