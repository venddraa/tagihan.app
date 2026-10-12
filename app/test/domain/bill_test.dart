import 'package:flutter_test/flutter_test.dart';
import 'package:tagihan_vendra/domain/bill.dart';
import 'package:tagihan_vendra/domain/calendar_date.dart';
import 'package:tagihan_vendra/domain/entity_id.dart';
import 'package:tagihan_vendra/domain/money.dart';

void main() {
  group('Bill', () {
    test('membentuk tagihan aktif dengan metadata offline-first', () {
      final bill = _createBill();

      expect(bill.name, 'ChatGPT Plus');
      expect(bill.amount, Money(minorUnits: 349000, currency: Currency.idr));
      expect(bill.billingCycle, BillingCycle.monthly);
      expect(bill.status, BillStatus.active);
      expect(bill.version, 1);
      expect(bill.isActive, isTrue);
      expect(bill.isDeleted, isFalse);
    });

    test('tagihan archived tidak dianggap aktif', () {
      final bill = _createBill(status: BillStatus.archived);

      expect(bill.isActive, isFalse);
    });

    test('tombstone membuat tagihan tidak aktif', () {
      final deletedAt = DateTime.utc(2026, 10, 12, 12);
      final bill = _createBill(updatedAt: deletedAt, deletedAt: deletedAt);

      expect(bill.isDeleted, isTrue);
      expect(bill.isActive, isFalse);
    });

    test('menolak jatuh tempo yang mendahului tanggal mulai', () {
      expect(
        () => _createBill(nextDueDate: CalendarDate(2026, 9, 30)),
        throwsArgumentError,
      );
    });

    test('menolak timestamp non-UTC dan version nol', () {
      expect(
        () => _createBill(createdAt: DateTime(2026, 10, 1)),
        throwsArgumentError,
      );
      expect(() => _createBill(version: 0), throwsRangeError);
    });
  });
}

Bill _createBill({
  BillStatus status = BillStatus.active,
  CalendarDate? nextDueDate,
  DateTime? createdAt,
  DateTime? updatedAt,
  DateTime? deletedAt,
  int version = 1,
}) {
  return Bill(
    id: EntityId.fromString('01890f47-3d7a-7c53-bb3c-9d6ec2f1a6b0'),
    name: 'ChatGPT Plus',
    category: 'Software',
    amount: Money(minorUnits: 349000, currency: Currency.idr),
    billingCycle: BillingCycle.monthly,
    nextDueDate: nextDueDate ?? CalendarDate(2026, 10, 18),
    startDate: CalendarDate(2026, 10, 1),
    status: status,
    notes: null,
    createdAt: createdAt ?? DateTime.utc(2026, 10, 1),
    updatedAt: updatedAt ?? DateTime.utc(2026, 10, 1),
    deletedAt: deletedAt,
    version: version,
  );
}
