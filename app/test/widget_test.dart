import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tagihan_vendra/app/tagihan_vendra_app.dart';

void main() {
  testWidgets('menampilkan navigasi desktop', (tester) async {
    await _setScreenSize(tester, const Size(1200, 800));
    await tester.pumpWidget(const TagihanVendraApp());

    expect(find.text('Tagihan Vendra'), findsOneWidget);
    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);

    await tester.tap(find.byIcon(Icons.receipt_long_outlined));
    await tester.pumpAndSettle();

    expect(
      find.text('Kelola tagihan dan subscription pribadi.'),
      findsOneWidget,
    );
  });

  testWidgets('menampilkan navigasi layar sempit', (tester) async {
    await _setScreenSize(tester, const Size(390, 844));
    await tester.pumpWidget(const TagihanVendraApp());

    expect(find.byType(NavigationRail), findsNothing);
    expect(find.byType(NavigationBar), findsOneWidget);

    await tester.tap(find.byIcon(Icons.payments_outlined));
    await tester.pumpAndSettle();

    expect(find.text('Lihat dan catat riwayat pembayaran.'), findsOneWidget);
  });
}

Future<void> _setScreenSize(WidgetTester tester, Size size) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;

  addTearDown(() {
    tester.view.resetDevicePixelRatio();
    tester.view.resetPhysicalSize();
  });
}
