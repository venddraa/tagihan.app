import 'package:tagihan_vendra/domain/bill.dart';
import 'package:tagihan_vendra/domain/calendar_date.dart';
import 'package:tagihan_vendra/domain/money.dart';

String formatBillingCycle(BillingCycle cycle) {
  return switch (cycle) {
    BillingCycle.oneTime => 'Satu kali',
    BillingCycle.weekly => 'Mingguan',
    BillingCycle.monthly => 'Bulanan',
    BillingCycle.yearly => 'Tahunan',
  };
}

String formatCalendarDate(CalendarDate date) {
  return '${date.day} ${_monthNames[date.month - 1]} ${date.year}';
}

String formatDateTimeDate(DateTime dateTime) {
  final local = dateTime.toLocal();
  return '${local.day} ${_monthNames[local.month - 1]} ${local.year}';
}

String formatMoney(Money money) {
  final scale = _powerOfTen(money.currency.decimalDigits);
  final majorUnits = money.minorUnits ~/ scale;
  final groupedMajor = _groupThousands(majorUnits.toString());

  if (money.currency.decimalDigits == 0) {
    return money.currency == Currency.idr
        ? 'Rp$groupedMajor'
        : '${money.currency.code} $groupedMajor';
  }

  final fraction = (money.minorUnits % scale).toString().padLeft(
    money.currency.decimalDigits,
    '0',
  );
  return '${money.currency.code} $groupedMajor.$fraction';
}

int _powerOfTen(int exponent) {
  var value = 1;
  for (var index = 0; index < exponent; index++) {
    value *= 10;
  }
  return value;
}

String _groupThousands(String digits) {
  final parts = <String>[];
  for (var end = digits.length; end > 0; end -= 3) {
    final start = end - 3 < 0 ? 0 : end - 3;
    parts.add(digits.substring(start, end));
  }
  return parts.reversed.join('.');
}

const _monthNames = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'Mei',
  'Jun',
  'Jul',
  'Agu',
  'Sep',
  'Okt',
  'Nov',
  'Des',
];
