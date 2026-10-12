// ignore_for_file: recursive_getters

import 'package:drift/drift.dart';
import 'package:tagihan_vendra/domain/bill.dart';
import 'package:tagihan_vendra/domain/calendar_date.dart';
import 'package:tagihan_vendra/domain/entity_id.dart';
import 'package:tagihan_vendra/domain/money.dart';

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

@DriftDatabase(tables: [Bills])
final class AppDatabase extends _$AppDatabase {
  AppDatabase(super.executor);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (migrator) => migrator.createAll(),
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
