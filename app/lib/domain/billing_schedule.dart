import 'dart:math';

import 'package:tagihan_vendra/domain/bill.dart';
import 'package:tagihan_vendra/domain/calendar_date.dart';

CalendarDate? calculateNextDueDate(Bill bill) {
  return switch (bill.billingCycle) {
    BillingCycle.oneTime => null,
    BillingCycle.weekly => _addDays(bill.nextDueDate, 7),
    BillingCycle.monthly => _nextMonthlyDate(
      bill.nextDueDate,
      anchorDay: bill.startDate.day,
    ),
    BillingCycle.yearly => _nextYearlyDate(
      bill.nextDueDate,
      anchorMonth: bill.startDate.month,
      anchorDay: bill.startDate.day,
    ),
  };
}

bool isBillOverdue(Bill bill, CalendarDate today) {
  return bill.isActive && bill.nextDueDate.isBefore(today);
}

bool isBillUpcoming(Bill bill, CalendarDate today, {int withinDays = 30}) {
  if (withinDays < 0) {
    throw RangeError.range(withinDays, 0, null, 'withinDays');
  }
  if (!bill.isActive || bill.nextDueDate.isBefore(today)) return false;

  final lastDay = _addDays(today, withinDays);
  return !bill.nextDueDate.isAfter(lastDay);
}

CalendarDate _addDays(CalendarDate date, int days) {
  final result = date.toUtcDateTime().add(Duration(days: days));
  return CalendarDate.fromDateTime(result);
}

CalendarDate _nextMonthlyDate(CalendarDate current, {required int anchorDay}) {
  final firstOfNextMonth = DateTime.utc(current.year, current.month + 1);
  final day = min(
    anchorDay,
    _lastDayOfMonth(firstOfNextMonth.year, firstOfNextMonth.month),
  );
  return CalendarDate(firstOfNextMonth.year, firstOfNextMonth.month, day);
}

CalendarDate _nextYearlyDate(
  CalendarDate current, {
  required int anchorMonth,
  required int anchorDay,
}) {
  var year = current.year;
  var candidate = _clampedDate(year, anchorMonth, anchorDay);
  if (!candidate.isAfter(current)) {
    year++;
    candidate = _clampedDate(year, anchorMonth, anchorDay);
  }
  return candidate;
}

CalendarDate _clampedDate(int year, int month, int day) {
  return CalendarDate(year, month, min(day, _lastDayOfMonth(year, month)));
}

int _lastDayOfMonth(int year, int month) {
  return DateTime.utc(year, month + 1, 0).day;
}
