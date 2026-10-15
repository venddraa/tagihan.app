import 'package:flutter_test/flutter_test.dart';
import 'package:tagihan_vendra/core/presentation_formatters.dart';
import 'package:tagihan_vendra/domain/calendar_date.dart';
import 'package:tagihan_vendra/domain/money.dart';

void main() {
  test('memformat uang tanpa mengubah integer minor unit', () {
    expect(
      formatMoney(Money(minorUnits: 59990, currency: Currency.idr)),
      'Rp59.990',
    );
    expect(
      formatMoney(Money(minorUnits: 1299, currency: Currency.usd)),
      'USD 12.99',
    );
    expect(
      formatMoney(Money(minorUnits: 1099, currency: Currency.eur)),
      'EUR 10.99',
    );
  });

  test('memformat tanggal kalender dalam Bahasa Indonesia', () {
    expect(formatCalendarDate(CalendarDate(2026, 10, 15)), '15 Okt 2026');
  });
}
