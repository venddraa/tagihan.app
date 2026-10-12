import 'package:flutter_test/flutter_test.dart';
import 'package:tagihan_vendra/domain/money.dart';

void main() {
  group('Money', () {
    test('menyimpan IDR sebagai integer rupiah', () {
      final money = Money(minorUnits: 59990, currency: Currency.idr);

      expect(money.minorUnits, 59990);
      expect(money.currency.code, 'IDR');
      expect(money.currency.decimalDigits, 0);
    });

    test('menyimpan USD sebagai integer cent', () {
      final money = Money(minorUnits: 1299, currency: Currency.usd);

      expect(money.minorUnits, 1299);
      expect(money.currency.decimalDigits, 2);
    });

    test('menjumlahkan nominal dengan currency yang sama', () {
      final first = Money(minorUnits: 50000, currency: Currency.idr);
      final second = Money(minorUnits: 9990, currency: Currency.idr);

      expect(first + second, Money(minorUnits: 59990, currency: Currency.idr));
    });

    test('menolak penjumlahan currency yang berbeda', () {
      final rupiah = Money(minorUnits: 10000, currency: Currency.idr);
      final dollar = Money(minorUnits: 1000, currency: Currency.usd);

      expect(() => rupiah + dollar, throwsArgumentError);
    });

    test('menolak nominal negatif', () {
      expect(
        () => Money(minorUnits: -1, currency: Currency.idr),
        throwsRangeError,
      );
    });
  });
}
