import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tagihan_vendra/data/local/app_database.dart';
import 'package:tagihan_vendra/domain/bill.dart';
import 'package:tagihan_vendra/domain/calendar_date.dart';
import 'package:tagihan_vendra/domain/entity_id.dart';
import 'package:tagihan_vendra/domain/money.dart';
import 'package:tagihan_vendra/domain/payment.dart';

void main() {
  late Directory temporaryDirectory;
  late File databaseFile;
  AppDatabase? database;

  setUp(() async {
    temporaryDirectory = await Directory.systemTemp.createTemp(
      'tagihan-vendra-persistence-',
    );
    databaseFile = File('${temporaryDirectory.path}/tagihan_vendra.sqlite');
  });

  tearDown(() async {
    await database?.close();
    await temporaryDirectory.delete(recursive: true);
  });

  test(
    'tagihan dan pembayaran tetap ada setelah database dibuka ulang',
    () async {
      final billId = EntityId.fromString(
        '0199d2f0-4c00-7000-8000-000000000001',
      );
      final paymentId = EntityId.fromString(
        '0199d2f0-4c00-7000-8000-000000000002',
      );
      final createdAt = DateTime.utc(2026, 10, 16, 8);
      final bill = Bill(
        id: billId,
        name: 'Internet rumah',
        category: 'Utilitas',
        amount: Money(minorUnits: 350000, currency: Currency.idr),
        billingCycle: BillingCycle.monthly,
        nextDueDate: CalendarDate(2026, 10, 25),
        startDate: CalendarDate(2026, 1, 25),
        status: BillStatus.active,
        notes: 'Dibayar manual',
        createdAt: createdAt,
        updatedAt: createdAt,
        version: 1,
      );

      database = AppDatabase(NativeDatabase(databaseFile));
      await database!.insertBill(bill);
      await database!.recordPayment(
        Payment(
          id: paymentId,
          billId: billId,
          amount: bill.amount,
          dueDate: bill.nextDueDate,
          paidAt: DateTime.utc(2026, 10, 16, 9),
          notes: 'Lunas',
          createdAt: DateTime.utc(2026, 10, 16, 9),
          updatedAt: DateTime.utc(2026, 10, 16, 9),
          version: 1,
        ),
      );
      await database!.close();
      database = null;

      database = AppDatabase(NativeDatabase(databaseFile));
      final reopenedBill = await database!.findBillById(billId);
      final reopenedPayment = await database!.findPaymentById(paymentId);
      final paymentHistory = await database!.getPaymentHistory();

      expect(databaseFile.existsSync(), isTrue);
      expect(reopenedBill, isNotNull);
      expect(reopenedBill!.nextDueDate, CalendarDate(2026, 11, 25));
      expect(reopenedBill.version, 2);
      expect(reopenedPayment, isNotNull);
      expect(reopenedPayment!.notes, 'Lunas');
      expect(paymentHistory.single.billName, 'Internet rumah');
      expect(paymentHistory.single.payment.id, paymentId);
    },
  );
}
