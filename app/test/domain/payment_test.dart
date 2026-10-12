import 'package:flutter_test/flutter_test.dart';
import 'package:tagihan_vendra/domain/calendar_date.dart';
import 'package:tagihan_vendra/domain/entity_id.dart';
import 'package:tagihan_vendra/domain/money.dart';
import 'package:tagihan_vendra/domain/payment.dart';

void main() {
  group('Payment', () {
    test('mencatat pembayaran sebagai record terpisah', () {
      final payment = _createPayment();

      expect(
        payment.billId,
        EntityId.fromString('01890f47-3d7a-7c53-bb3c-9d6ec2f1a6b0'),
      );
      expect(payment.amount, Money(minorUnits: 349000, currency: Currency.idr));
      expect(payment.dueDate, CalendarDate(2026, 10, 18));
      expect(payment.paidAt, DateTime.utc(2026, 10, 15, 9, 30));
      expect(payment.isDeleted, isFalse);
    });

    test('dueDate tetap menunjukkan periode saat pembayaran lebih awal', () {
      final payment = _createPayment();

      expect(payment.dueDate, CalendarDate(2026, 10, 18));
      expect(payment.paidAt.day, 15);
    });

    test('mendukung tombstone pembayaran', () {
      final deletedAt = DateTime.utc(2026, 10, 16);
      final payment = _createPayment(
        updatedAt: deletedAt,
        deletedAt: deletedAt,
      );

      expect(payment.isDeleted, isTrue);
    });

    test('menolak timestamp non-UTC dan version nol', () {
      expect(
        () => _createPayment(paidAt: DateTime(2026, 10, 15)),
        throwsArgumentError,
      );
      expect(() => _createPayment(version: 0), throwsRangeError);
    });
  });
}

Payment _createPayment({
  DateTime? paidAt,
  DateTime? updatedAt,
  DateTime? deletedAt,
  int version = 1,
}) {
  return Payment(
    id: EntityId.fromString('01890f47-3d7a-7a41-8585-2ec0a6634f2a'),
    billId: EntityId.fromString('01890f47-3d7a-7c53-bb3c-9d6ec2f1a6b0'),
    amount: Money(minorUnits: 349000, currency: Currency.idr),
    dueDate: CalendarDate(2026, 10, 18),
    paidAt: paidAt ?? DateTime.utc(2026, 10, 15, 9, 30),
    notes: 'Dibayar lebih awal',
    createdAt: DateTime.utc(2026, 10, 15, 9, 30),
    updatedAt: updatedAt ?? DateTime.utc(2026, 10, 15, 9, 30),
    deletedAt: deletedAt,
    version: version,
  );
}
