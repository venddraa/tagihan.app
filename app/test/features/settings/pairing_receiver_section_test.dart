import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tagihan_vendra/features/settings/pairing_receiver_section.dart';

import '../../data/sync/pairing_receiver_test.dart' show ReceiverFixture;

void main() {
  for (final size in [const Size(1200, 900), const Size(320, 700)]) {
    testWidgets('penerima undangan tersimpan dan pulih pada $size', (
      tester,
    ) async {
      final fixture = ReceiverFixture();
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(fixture.database.close);
      final busy = <bool>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: PairingReceiverSection(
                receiver: fixture.receiver,
                syncing: false,
                onBusyChanged: busy.add,
              ),
            ),
          ),
        ),
      );
      expect(fixture.calls, isEmpty);
      expect(fixture.credentials.values, isEmpty);
      await tester.enterText(
        find.byKey(const ValueKey('pairing-invitation-input')),
        fixture.invitation.code,
      );
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const ValueKey('submit-pairing-request')),
            )
            .onPressed,
        isNull,
      );
      final review = find.byKey(const ValueKey('review-pairing-invitation'));
      await tester.ensureVisible(review);
      await tester.tap(review);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('pairing-invitation-preview')),
        findsOneWidget,
      );
      expect(
        find.text('Alamat hub: ${fixture.invitation.endpoint}'),
        findsOneWidget,
      );
      expect(fixture.calls, isEmpty);
      expect(fixture.credentials.values, isEmpty);
      final begin = find.text('Kirim permintaan pairing');
      expect(fixture.credentials.reads, 0);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('pairing-invitation-preview')),
          matching: find.textContaining(fixture.invitation.token),
        ),
        findsNothing,
      );
      await tester.ensureVisible(begin);
      await tester.tap(begin);
      await _until(
        tester,
        () => find
            .text('Status: Menunggu persetujuan Fedora')
            .evaluate()
            .isNotEmpty,
      );
      expect(busy, [true, false]);
      expect(
        find.byKey(const ValueKey('pairing-invitation-input')),
        findsNothing,
      );
      final pending = await tester.runAsync(fixture.receiver.readProfile);
      expect(find.textContaining(pending!.credential), findsNothing);
      fixture.approved = true;
      final refresh = find.text('Periksa sesi dan status');
      await tester.ensureVisible(refresh);
      await tester.tap(refresh);
      await _until(
        tester,
        () => find.text('Status: Terhubung').evaluate().isNotEmpty,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });
  }

  testWidgets(
    'undangan invalid atau diedit harus ditinjau tanpa jaringan/keyring',
    (tester) async {
      final fixture = ReceiverFixture();
      addTearDown(fixture.database.close);
      await _mount(tester, fixture);
      final input = find.byKey(const ValueKey('pairing-invitation-input'));
      final review = find.byKey(const ValueKey('review-pairing-invitation'));
      final submit = find.byKey(const ValueKey('submit-pairing-request'));
      await tester.enterText(input, 'bukan-undangan');
      await tester.ensureVisible(review);
      await tester.tap(review);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('pairing-invitation-preview')),
        findsNothing,
      );
      expect(find.textContaining('Teks undangan tidak valid.'), findsOneWidget);
      expect(tester.widget<FilledButton>(submit).onPressed, isNull);
      await tester.enterText(input, fixture.invitation.code);
      await tester.ensureVisible(review);
      await tester.tap(review);
      await tester.pumpAndSettle();
      expect(tester.widget<FilledButton>(submit).onPressed, isNotNull);
      await tester.enterText(input, '${fixture.invitation.code}x');
      await tester.pump();
      expect(
        find.byKey(const ValueKey('pairing-invitation-preview')),
        findsNothing,
      );
      expect(tester.widget<FilledButton>(submit).onPressed, isNull);
      expect(fixture.calls, isEmpty);
      expect(fixture.credentials.values, isEmpty);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    },
  );

  testWidgets(
    'background membersihkan input rahasia dan tidak mengirim saat resume',
    (tester) async {
      final fixture = ReceiverFixture();
      addTearDown(fixture.database.close);
      await _mount(tester, fixture);
      final input = find.byKey(const ValueKey('pairing-invitation-input'));
      await tester.enterText(input, fixture.invitation.code);
      final review = find.byKey(const ValueKey('review-pairing-invitation'));
      await tester.ensureVisible(review);
      await tester.tap(review);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('pairing-invitation-preview')),
        findsOneWidget,
      );
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(tester.widget<TextField>(input).controller!.text, isEmpty);
      expect(
        find.byKey(const ValueKey('pairing-invitation-preview')),
        findsNothing,
      );
      expect(fixture.calls, isEmpty);
      expect(fixture.credentials.values, isEmpty);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    },
  );
}

Future<void> _mount(WidgetTester tester, ReceiverFixture fixture) =>
    tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: PairingReceiverSection(
              receiver: fixture.receiver,
              syncing: false,
              onBusyChanged: (_) {},
            ),
          ),
        ),
      ),
    );

Future<void> _until(WidgetTester tester, bool Function() ready) async {
  for (var i = 0; i < 100; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 1)),
    );
    await tester.pump(const Duration(milliseconds: 20));
    if (ready()) return;
  }
  fail('Operasi pairing tidak selesai dalam batas test.');
}
