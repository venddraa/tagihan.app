import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tagihan_vendra/app/tagihan_vendra_app.dart';

void main() {
  testWidgets('menampilkan navigasi atas pada layar desktop', (tester) async {
    await _setScreenSize(tester, const Size(1200, 800));
    await tester.pumpWidget(const TagihanVendraApp());

    expect(find.text('Tagihan Vendra'), findsOneWidget);
    expect(find.byKey(const ValueKey('desktop-navigation')), findsOneWidget);
    expect(find.byKey(const ValueKey('compact-navigation')), findsNothing);
    final headerRect = tester.getRect(
      find.byKey(const ValueKey('desktop-header')),
    );
    final navigationRect = tester.getRect(
      find.byKey(const ValueKey('desktop-navigation')),
    );

    expect(headerRect.width, 1200);
    expect(navigationRect.center.dx, closeTo(headerRect.center.dx, 0.01));
    expect(
      Theme.of(tester.element(find.byType(Scaffold))).brightness,
      Brightness.dark,
    );

    await tester.tap(find.byKey(const ValueKey('desktop-destination-1')));
    await tester.pumpAndSettle();

    expect(
      find.text('Kelola tagihan dan subscription pribadi.'),
      findsOneWidget,
    );
  });

  testWidgets('menampilkan navigasi bawah pada layar sempit', (tester) async {
    await _setScreenSize(tester, const Size(390, 844));
    await tester.pumpWidget(const TagihanVendraApp());

    expect(find.byKey(const ValueKey('desktop-navigation')), findsNothing);
    expect(find.byKey(const ValueKey('compact-navigation')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('compact-destination-2')));
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
