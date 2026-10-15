// ignore_for_file: recursive_getters

import 'package:drift/drift.dart';
import 'package:tagihan_vendra/domain/bill.dart';
import 'package:tagihan_vendra/domain/billing_schedule.dart';
import 'package:tagihan_vendra/domain/calendar_date.dart';
import 'package:tagihan_vendra/domain/entity_id.dart';
import 'package:tagihan_vendra/domain/money.dart';
import 'package:tagihan_vendra/domain/payment.dart';

import 'app_database.steps.dart';

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

final class PaymentHistoryEntry {
  const PaymentHistoryEntry({required this.payment, required this.billName});

  final Payment payment;
  final String billName;
}

@DriftDatabase(tables: [Bills, Payments])
final class AppDatabase extends _$AppDatabase {
  AppDatabase(super.executor);

  @override
  int get schemaVersion => 2;

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
    ),
    beforeOpen: (_) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );

  Future<void> insertBill(Bill bill) async {
    await into(bills).insert(_billToCompanion(bill));
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
    final updatedRows =
        await (update(bills)..where((table) => table.id.equals(bill.id.value)))
            .write(_billToCompanion(bill));

    if (updatedRows != 1) {
      throw StateError('Tagihan yang akan diperbarui tidak ditemukan.');
    }
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

      await updateBill(archived);
    });
  }

  Future<void> insertPayment(Payment payment) async {
    await into(payments).insert(_paymentToCompanion(payment));
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

      await insertPayment(payment);
      if (!bill.isActive || payment.dueDate != bill.nextDueDate) return;

      final nextDueDate = calculateNextDueDate(bill);
      final changedAt = payment.createdAt.isAfter(bill.updatedAt)
          ? payment.createdAt
          : bill.updatedAt;
      final updatedBill = Bill(
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
      await updateBill(updatedBill);
    });
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
