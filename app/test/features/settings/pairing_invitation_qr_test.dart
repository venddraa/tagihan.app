import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:tagihan_vendra/data/sync/pairing_admin_client.dart';
import 'package:tagihan_vendra/features/settings/pairing_invitation_qr.dart';

import '../../data/sync/pairing_admin_client_test.dart' show invitationFixture;

void main() {
  for (final (width, ratio, brightness) in [
    (264.0, 1.0, Brightness.dark),
    (432.0, 1.5, Brightness.dark),
    (720.0, 2.0, Brightness.light),
  ]) {
    testWidgets(
      'QR mempertahankan payload, kontras, dan quiet zone pada $width/$ratio',
      (tester) async {
        final invitation = PairingInvitation.fromJson(invitationFixture());
        tester.view.physicalSize = Size(width * ratio, 900 * ratio);
        tester.view.devicePixelRatio = ratio;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(brightness: brightness),
            home: Scaffold(body: PairingInvitationQr(invitation: invitation)),
          ),
        );
        await tester.pumpAndSettle();
        final finder = find.byKey(const ValueKey('pairing-qr-image'));
        final boundary = tester.renderObject<RenderRepaintBoundary>(finder);
        expect(boundary.size.width, lessThanOrEqualTo(width));
        expect(boundary.size.width, lessThanOrEqualTo(432));
        expect(boundary.size.width, boundary.size.height);
        final view = tester.widget<QrImageView>(find.byType(QrImageView));
        expect(view.semanticsLabel, isNot(contains(invitation.token)));

        final captured = await tester.runAsync(() async {
          final image = await boundary.toImage(pixelRatio: ratio);
          try {
            return (
              image.width,
              (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!
                  .buffer
                  .asUint8List(),
            );
          } finally {
            image.dispose();
          }
        });
        final (size, pixels) = captured!;
        final model = QrImage(
          QrCode.fromData(
            data: invitation.code,
            errorCorrectLevel: QrErrorCorrectLevel.M,
          ),
        );
        final step = size / (model.moduleCount + 8);
        final margin = (4 * step).floor();
        // Memeriksa hasil raster, bukan sekadar konfigurasi widget. Seluruh sisi
        // quiet zone harus putih dan opaque, juga ketika app memakai dark theme.
        for (var y = 0; y < size; y++) {
          for (var x = 0; x < size; x++) {
            if (x < margin ||
                y < margin ||
                x >= size - margin ||
                y >= size - margin) {
              expect(_rgba(pixels, size, x, y), 0xffffffff);
            }
          }
        }
        // Matrix yang benar-benar digambar harus mengodekan teks undangan asli.
        // Ini juga menangkap wiring payload yang salah atau pembulatan painter.
        for (var row = 0; row < model.moduleCount; row++) {
          for (var col = 0; col < model.moduleCount; col++) {
            final x = ((col + 4.5) * step).floor();
            final y = ((row + 4.5) * step).floor();
            expect(
              _rgba(pixels, size, x, y),
              model.isDark(row, col) ? 0x000000ff : 0xffffffff,
              reason: 'Modul $row/$col harus cocok dengan payload undangan.',
            );
          }
        }
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
      },
    );
  }

  testWidgets('ruang terlalu sempit menampilkan fallback tanpa overflow', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 80,
            child: PairingInvitationQr(
              invitation: PairingInvitation.fromJson(invitationFixture()),
            ),
          ),
        ),
      ),
    );
    expect(find.byType(QrImageView), findsNothing);
    expect(find.textContaining('gunakan Salin undangan'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

int _rgba(Uint8List pixels, int width, int x, int y) {
  final offset = (y * width + x) * 4;
  return (pixels[offset] << 24) |
      (pixels[offset + 1] << 16) |
      (pixels[offset + 2] << 8) |
      pixels[offset + 3];
}
