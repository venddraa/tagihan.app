import 'package:flutter_test/flutter_test.dart';
import 'package:tagihan_vendra/domain/bill.dart';
import 'package:tagihan_vendra/domain/bill_overview.dart';
import 'package:tagihan_vendra/domain/calendar_date.dart';
import 'package:tagihan_vendra/domain/entity_id.dart';
import 'package:tagihan_vendra/domain/money.dart';

void main() {
  final today = CalendarDate(2026, 10, 15);

  test('komitmen menggabungkan siklus recurring dengan integer', () {
    final overview = BillOverview([
      _bill(amount: 60000),
      _bill(amount: 120000, cycle: BillingCycle.yearly),
      _bill(amount: 12000, cycle: BillingCycle.weekly),
      _bill(amount: 999999, cycle: BillingCycle.oneTime),
    ], today);

    expect(overview.activeCount, 4);
    expect(overview.monthlyCommitments, [
      Money(minorUnits: 122000, currency: Currency.idr),
    ]);
  });

  test('pembulatan dilakukan setelah penjumlahan per currency', () {
    final overview = BillOverview([
      _bill(amount: 7, cycle: BillingCycle.yearly),
      _bill(amount: 7, cycle: BillingCycle.yearly),
      _bill(amount: 6, cycle: BillingCycle.yearly, currency: Currency.usd),
    ], today);

    expect(overview.monthlyCommitments, [
      Money(minorUnits: 1, currency: Currency.idr),
      Money(minorUnits: 1, currency: Currency.usd),
    ]);
  });

  test('currency tetap terpisah dan nominal nol tetap valid', () {
    final overview = BillOverview([
      _bill(amount: 59990),
      _bill(amount: 1299, currency: Currency.usd),
      _bill(amount: 0, currency: Currency.eur),
    ], today);

    expect(overview.monthlyCommitments, [
      Money(minorUnits: 59990, currency: Currency.idr),
      Money(minorUnits: 1299, currency: Currency.usd),
      Money(minorUnits: 0, currency: Currency.eur),
    ]);
  });

  test('paused archived dan tombstone tidak memengaruhi ringkasan', () {
    final overview = BillOverview([
      _bill(status: BillStatus.paused),
      _bill(status: BillStatus.archived),
      _bill(deleted: true),
    ], today);

    expect(overview.activeCount, 0);
    expect(overview.monthlyCommitments, isEmpty);
    expect(overview.overdue, isEmpty);
    expect(overview.upcoming, isEmpty);
  });

  test('mengelompokkan jatuh tempo dan mengurutkan tanggal lalu nama', () {
    final overview = BillOverview([
      _bill(name: 'Di luar rentang', due: CalendarDate(2026, 11, 15)),
      _bill(name: 'B', due: today),
      _bill(name: 'Terlambat', due: CalendarDate(2026, 10, 14)),
      _bill(name: 'Batas 30 hari', due: CalendarDate(2026, 11, 14)),
      _bill(name: 'A', due: today),
    ], today);

    expect(overview.overdue.map((bill) => bill.name), ['Terlambat']);
    expect(overview.upcoming.map((bill) => bill.name), [
      'A',
      'B',
      'Batas 30 hari',
    ]);
  });

  test(
    'daftar kosong dan hanya one-time tidak mempunyai komitmen recurring',
    () {
      expect(BillOverview([], today).monthlyCommitments, isEmpty);
      expect(
        BillOverview([
          _bill(cycle: BillingCycle.oneTime),
        ], today).monthlyCommitments,
        isEmpty,
      );
    },
  );
}

Bill _bill({
  String name = 'Tagihan',
  int amount = 59990,
  Currency currency = Currency.idr,
  BillingCycle cycle = BillingCycle.monthly,
  BillStatus status = BillStatus.active,
  CalendarDate? due,
  bool deleted = false,
}) {
  final timestamp = DateTime.utc(2026, 1, 1);
  return Bill(
    id: EntityId.fromString('01890f47-3d7a-7c53-bb3c-9d6ec2f1a6b0'),
    name: name,
    amount: Money(minorUnits: amount, currency: currency),
    billingCycle: cycle,
    nextDueDate: due ?? CalendarDate(2026, 10, 25),
    startDate: CalendarDate(2026, 1, 1),
    status: status,
    createdAt: timestamp,
    updatedAt: timestamp,
    deletedAt: deleted ? timestamp : null,
    version: 1,
  );
}
