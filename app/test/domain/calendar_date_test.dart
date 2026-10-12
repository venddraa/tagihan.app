import 'package:flutter_test/flutter_test.dart';
import 'package:tagihan_vendra/domain/calendar_date.dart';

void main() {
  group('CalendarDate', () {
    test('menyimpan tanggal tanpa waktu dan timezone', () {
      final date = CalendarDate(2026, 10, 18);

      expect(date.year, 2026);
      expect(date.month, 10);
      expect(date.day, 18);
      expect(date.toString(), '2026-10-18');
    });

    test('menerima leap day yang valid', () {
      expect(CalendarDate(2024, 2, 29).toString(), '2024-02-29');
    });

    test('menolak tanggal kalender yang tidak valid', () {
      expect(() => CalendarDate(2026, 2, 29), throwsArgumentError);
      expect(() => CalendarDate(2026, 13, 1), throwsArgumentError);
    });

    test('membandingkan tanggal secara kronologis', () {
      final earlier = CalendarDate(2026, 10, 18);
      final later = CalendarDate(2026, 10, 25);

      expect(earlier.isBefore(later), isTrue);
      expect(later.isAfter(earlier), isTrue);
    });
  });
}
