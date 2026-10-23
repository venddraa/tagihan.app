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
      final begin = find.text('Kirim permintaan pairing');
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
}

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
