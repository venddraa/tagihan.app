import 'package:flutter_test/flutter_test.dart';
import 'package:tagihan_vendra/domain/bill.dart';
import 'package:tagihan_vendra/domain/billing_schedule.dart';
import 'package:tagihan_vendra/domain/calendar_date.dart';
import 'package:tagihan_vendra/domain/entity_id.dart';
import 'package:tagihan_vendra/domain/money.dart';

void main() {
  group('calculateNextDueDate', () {
    test('weekly menambah tepat tujuh hari melewati akhir bulan', () {
      final bill = _bill(
        cycle: BillingCycle.weekly,
        startDate: CalendarDate(2026, 10, 29),
        nextDueDate: CalendarDate(2026, 10, 29),
      );

      expect(calculateNextDueDate(bill), CalendarDate(2026, 11, 5));
    });

    test('monthly mempertahankan anchor setelah bulan pendek', () {
      final january = _bill(
        cycle: BillingCycle.monthly,
        startDate: CalendarDate(2027, 1, 31),
        nextDueDate: CalendarDate(2027, 1, 31),
      );
      final february = _bill(
        cycle: BillingCycle.monthly,
        startDate: CalendarDate(2027, 1, 31),
        nextDueDate: CalendarDate(2027, 2, 28),
      );

      expect(calculateNextDueDate(january), CalendarDate(2027, 2, 28));
      expect(calculateNextDueDate(february), CalendarDate(2027, 3, 31));
    });

    test('yearly menangani subscription tanggal 29 Februari', () {
      final leapYear = _bill(
        cycle: BillingCycle.yearly,
        startDate: CalendarDate(2024, 2, 29),
        nextDueDate: CalendarDate(2024, 2, 29),
      );
      final nonLeapYear = _bill(
        cycle: BillingCycle.yearly,
        startDate: CalendarDate(2024, 2, 29),
        nextDueDate: CalendarDate(2027, 2, 28),
      );

      expect(calculateNextDueDate(leapYear), CalendarDate(2025, 2, 28));
      expect(calculateNextDueDate(nonLeapYear), CalendarDate(2028, 2, 29));
    });

    test('one-time tidak mempunyai jatuh tempo lanjutan', () {
      expect(calculateNextDueDate(_bill(cycle: BillingCycle.oneTime)), isNull);
    });
  });

  group('status waktu tagihan', () {
    final today = CalendarDate(2026, 10, 15);

    test('jatuh tempo sebelum hari ini adalah overdue', () {
      expect(
        isBillOverdue(_bill(nextDueDate: CalendarDate(2026, 10, 14)), today),
        isTrue,
      );
      expect(
        isBillOverdue(_bill(nextDueDate: CalendarDate(2026, 10, 15)), today),
        isFalse,
      );
    });

    test('upcoming memakai rentang inklusif dan menolak overdue', () {
      expect(
        isBillUpcoming(
          _bill(nextDueDate: CalendarDate(2026, 10, 15)),
          today,
          withinDays: 7,
        ),
        isTrue,
      );
      expect(
        isBillUpcoming(
          _bill(nextDueDate: CalendarDate(2026, 10, 22)),
          today,
          withinDays: 7,
        ),
        isTrue,
      );
      expect(
        isBillUpcoming(
          _bill(nextDueDate: CalendarDate(2026, 10, 23)),
          today,
          withinDays: 7,
        ),
        isFalse,
      );
      expect(
        isBillUpcoming(
          _bill(nextDueDate: CalendarDate(2026, 10, 14)),
          today,
          withinDays: 7,
        ),
        isFalse,
      );
    });

    test('paused, archived, dan tombstone tidak dihitung', () {
      final deletedAt = DateTime.utc(2026, 10, 1);
      expect(
        isBillOverdue(
          _bill(
            status: BillStatus.paused,
            nextDueDate: CalendarDate(2026, 10, 1),
          ),
          today,
        ),
        isFalse,
      );
      expect(
        isBillUpcoming(
          _bill(
            status: BillStatus.archived,
            nextDueDate: CalendarDate(2026, 10, 16),
          ),
          today,
        ),
        isFalse,
      );
      expect(
        isBillOverdue(
          _bill(
            nextDueDate: CalendarDate(2026, 10, 1),
            updatedAt: deletedAt,
            deletedAt: deletedAt,
          ),
          today,
        ),
        isFalse,
      );
    });

    test('rentang upcoming negatif ditolak', () {
      expect(
        () => isBillUpcoming(_bill(), today, withinDays: -1),
        throwsRangeError,
      );
    });
  });
}

Bill _bill({
  BillingCycle cycle = BillingCycle.monthly,
  CalendarDate? startDate,
  CalendarDate? nextDueDate,
  BillStatus status = BillStatus.active,
  DateTime? updatedAt,
  DateTime? deletedAt,
}) {
  final createdAt = DateTime.utc(2026, 1, 1);
  return Bill(
    id: EntityId.fromString('01890f47-3d7a-7c53-bb3c-9d6ec2f1a6b0'),
    name: 'Tagihan test',
    amount: Money(minorUnits: 59990, currency: Currency.idr),
    billingCycle: cycle,
    nextDueDate: nextDueDate ?? CalendarDate(2026, 10, 25),
    startDate: startDate ?? CalendarDate(2026, 1, 25),
    status: status,
    createdAt: createdAt,
    updatedAt: updatedAt ?? createdAt,
    deletedAt: deletedAt,
    version: 1,
  );
}
