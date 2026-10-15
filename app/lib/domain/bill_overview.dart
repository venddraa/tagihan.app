import 'package:tagihan_vendra/domain/bill.dart';
import 'package:tagihan_vendra/domain/billing_schedule.dart';
import 'package:tagihan_vendra/domain/calendar_date.dart';
import 'package:tagihan_vendra/domain/money.dart';

final class BillOverview {
  BillOverview(Iterable<Bill> bills, CalendarDate today) {
    final active = bills.where((bill) => bill.isActive).toList()
      ..sort((first, second) {
        final dateOrder = first.nextDueDate.compareTo(second.nextDueDate);
        return dateOrder != 0 ? dateOrder : first.name.compareTo(second.name);
      });
    activeCount = active.length;
    overdue = List.unmodifiable(
      active.where((bill) => isBillOverdue(bill, today)),
    );
    upcoming = List.unmodifiable(
      active.where((bill) => isBillUpcoming(bill, today)),
    );

    // Sum annual equivalents first, then round once to the nearest minor unit.
    // Weekly uses 52 payments/year, monthly 12, yearly 1, one-time 0.
    final annualTotals = <Currency, int>{};
    for (final bill in active) {
      final multiplier = switch (bill.billingCycle) {
        BillingCycle.oneTime => 0,
        BillingCycle.weekly => 52,
        BillingCycle.monthly => 12,
        BillingCycle.yearly => 1,
      };
      if (multiplier == 0) continue;
      final currency = bill.amount.currency;
      annualTotals[currency] =
          (annualTotals[currency] ?? 0) + bill.amount.minorUnits * multiplier;
    }
    monthlyCommitments = List.unmodifiable([
      for (final currency in Currency.values)
        if (annualTotals.containsKey(currency))
          Money(
            minorUnits: (annualTotals[currency]! + 6) ~/ 12,
            currency: currency,
          ),
    ]);
  }

  late final int activeCount;
  late final List<Bill> overdue;
  late final List<Bill> upcoming;
  late final List<Money> monthlyCommitments;
}
