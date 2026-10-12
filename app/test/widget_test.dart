import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tagihan_vendra/app/tagihan_vendra_app.dart';
import 'package:tagihan_vendra/data/local/app_database.dart';

void main() {
  late AppDatabase database;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await database.close();
  });

  testWidgets('menampilkan navigasi atas pada layar desktop', (tester) async {
    await _setScreenSize(tester, const Size(1200, 800));
    await tester.pumpWidget(TagihanVendraApp(database: database));

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

    await _disposeApp(tester);
  });

  testWidgets('menampilkan navigasi bawah pada layar sempit', (tester) async {
    await _setScreenSize(tester, const Size(390, 844));
    await tester.pumpWidget(TagihanVendraApp(database: database));

    expect(find.byKey(const ValueKey('desktop-navigation')), findsNothing);
    expect(find.byKey(const ValueKey('compact-navigation')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('compact-destination-2')));
    await tester.pumpAndSettle();

    expect(find.text('Lihat dan catat riwayat pembayaran.'), findsOneWidget);

    await _disposeApp(tester);
  });

  testWidgets('menambah, melihat, mengedit, dan archive tagihan', (
    tester,
  ) async {
    await _setScreenSize(tester, const Size(1200, 900));
    await tester.pumpWidget(TagihanVendraApp(database: database));

    await tester.tap(find.byKey(const ValueKey('desktop-destination-1')));
    await tester.pumpAndSettle();
    expect(find.text('Belum ada tagihan'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('add-bill-button')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('bill-name-field')),
      'Spotify',
    );
    await tester.enterText(
      find.byKey(const ValueKey('bill-amount-field')),
      '59990',
    );
    await tester.tap(find.byKey(const ValueKey('save-bill-button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('bill-list')), findsOneWidget);
    expect(find.text('Spotify'), findsOneWidget);
    expect(find.text('Rp59.990'), findsOneWidget);

    await tester.tap(find.text('Spotify'));
    await tester.pumpAndSettle();
    expect(find.text('Nominal'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('edit-bill-button')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('bill-name-field')),
      'Spotify Premium',
    );
    await tester.tap(find.byKey(const ValueKey('save-bill-button')));
    await tester.pumpAndSettle();

    expect(find.text('Spotify Premium'), findsOneWidget);
    await tester.tap(find.text('Spotify Premium'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('archive-bill-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('confirm-archive-button')));
    await tester.pumpAndSettle();

    expect(find.text('Belum ada tagihan'), findsOneWidget);
    final stored = await database.getActiveBills();
    expect(stored, isEmpty);

    await _disposeApp(tester);
  });
}

Future<void> _disposeApp(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pumpAndSettle();
}

Future<void> _setScreenSize(WidgetTester tester, Size size) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;

  addTearDown(() {
    tester.view.resetDevicePixelRatio();
    tester.view.resetPhysicalSize();
  });
}
