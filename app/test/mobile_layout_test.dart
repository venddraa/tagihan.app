import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tagihan_vendra/app/app_theme.dart';
import 'package:tagihan_vendra/data/local/app_database.dart';
import 'package:tagihan_vendra/domain/bill.dart';
import 'package:tagihan_vendra/domain/calendar_date.dart';
import 'package:tagihan_vendra/domain/entity_id.dart';
import 'package:tagihan_vendra/domain/money.dart';
import 'package:tagihan_vendra/domain/payment.dart';
import 'package:tagihan_vendra/features/bills/bill_form_dialog.dart';
import 'package:tagihan_vendra/features/bills/bill_list_page.dart';
import 'package:tagihan_vendra/features/payments/payment_form_dialog.dart';
import 'package:tagihan_vendra/features/payments/payment_history_page.dart';

void main() {
  late AppDatabase database;

  setUp(() => database = AppDatabase(NativeDatabase.memory()));
  tearDown(() => database.close());

  for (final size in [const Size(320, 568), const Size(390, 844)]) {
    testWidgets('form tagihan dapat disimpan dengan keyboard pada $size', (
      tester,
    ) async {
      _phoneViewport(tester, size);
      await _openForm(tester, BillFormDialog(database: database));
      await tester.enterText(
        find.byKey(const ValueKey('bill-name-field')),
        'Subscription pribadi',
      );
      _showKeyboard(tester);
      await tester.pumpAndSettle();

      final amountField = find.byKey(const ValueKey('bill-amount-field'));
      await tester.ensureVisible(amountField);
      await tester.enterText(amountField, '999999999');
      final save = find.byKey(const ValueKey('save-bill-button'));
      await tester.ensureVisible(save);
      await tester.pumpAndSettle();

      expect(tester.getRect(save).bottom, lessThanOrEqualTo(size.height - 240));
      expect(tester.takeException(), isNull);
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(find.byType(BillFormDialog), findsNothing);
      final bills = await tester.runAsync(database.getActiveBills);
      expect(bills!.single.amount.minorUnits, 999999999);
      await _dispose(tester);
    });
  }

  testWidgets(
    'form pembayaran landscape tetap dapat digunakan dengan keyboard',
    (tester) async {
      _phoneViewport(tester, const Size(844, 390));
      final bill = _bill();
      await tester.runAsync(() => database.insertBill(bill));
      await _openForm(
        tester,
        PaymentFormDialog(database: database, bills: [bill]),
      );
      _showKeyboard(tester, height: 150);
      await tester.pumpAndSettle();
      final save = find.byKey(const ValueKey('save-payment-button'));
      await tester.ensureVisible(save);
      await tester.pumpAndSettle();
      expect(tester.getRect(save).bottom, lessThanOrEqualTo(240));
      expect(tester.takeException(), isNull);
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(find.byType(PaymentFormDialog), findsNothing);
      final history = await tester.runAsync(database.getPaymentHistory);
      expect(history!.single.payment.amount, bill.amount);
      await _dispose(tester);
    },
  );

  testWidgets('nominal besar dan detail panjang terbaca pada layar kecil', (
    tester,
  ) async {
    _phoneViewport(tester, const Size(320, 568));
    final bill = _bill();
    final now = DateTime.now().toUtc();
    await tester.runAsync(() async {
      await database.insertBill(bill);
      await database.insertPayment(
        Payment(
          id: EntityId.generate(),
          billId: bill.id,
          amount: bill.amount,
          dueDate: bill.nextDueDate,
          paidAt: now,
          notes: List.filled(40, 'Catatan pembayaran panjang.').join('\n'),
          createdAt: now,
          updatedAt: now,
          version: 1,
        ),
      );
    });

    for (final page in [
      BillListPage(database: database, compact: true),
      PaymentHistoryPage(database: database, compact: true),
    ]) {
      await tester.pumpWidget(_testApp(page));
      await tester.pumpAndSettle();
      final amount = find.text('Rp999.999.999');
      expect(amount, findsOneWidget);
      await tester.ensureVisible(amount);
      await tester.pumpAndSettle();
      final rect = tester.getRect(amount);
      expect(rect.left, greaterThanOrEqualTo(0));
      expect(rect.right, lessThanOrEqualTo(320));
      await tester.tap(amount);
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.widgetWithText(TextButton, 'Tutup'));
      await tester.pumpAndSettle();
      await _dispose(tester);
    }
  });
}

Widget _testApp(Widget child) {
  return MaterialApp(
    theme: AppTheme.dark.copyWith(platform: TargetPlatform.iOS),
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(1.3)),
      child: child!,
    ),
    home: Scaffold(body: SafeArea(child: child)),
  );
}

Future<void> _openForm(WidgetTester tester, Widget form) async {
  await tester.pumpWidget(
    _testApp(
      Builder(
        builder: (context) => Center(
          child: TextButton(
            onPressed: () =>
                showDialog<void>(context: context, builder: (_) => form),
            child: const Text('Buka form'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Buka form'));
  await tester.pumpAndSettle();
}

void _phoneViewport(WidgetTester tester, Size size) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  tester.view.padding = size.width > size.height
      ? const FakeViewPadding(left: 47, right: 47, bottom: 21)
      : const FakeViewPadding(top: 47, bottom: 34);
  addTearDown(() {
    tester.view.resetDevicePixelRatio();
    tester.view.resetPhysicalSize();
    tester.view.resetPadding();
    tester.view.resetViewInsets();
  });
}

void _showKeyboard(WidgetTester tester, {double height = 240}) {
  final padding = tester.view.padding;
  tester.view.padding = FakeViewPadding(
    top: padding.top,
    left: padding.left,
    right: padding.right,
  );
  tester.view.viewInsets = FakeViewPadding(bottom: height);
}

Future<void> _dispose(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pumpAndSettle();
}

Bill _bill() {
  final now = DateTime.now().toUtc();
  return Bill(
    id: EntityId.generate(),
    name: 'Subscription dengan nama panjang untuk pengujian layar ponsel',
    amount: Money(minorUnits: 999999999, currency: Currency.idr),
    billingCycle: BillingCycle.monthly,
    nextDueDate: CalendarDate(2026, 12, 25),
    startDate: CalendarDate(2026, 1, 25),
    status: BillStatus.active,
    notes: List.filled(40, 'Catatan tagihan panjang.').join('\n'),
    createdAt: now,
    updatedAt: now,
    version: 1,
  );
}
