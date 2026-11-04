import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:tagihan_vendra/data/sync/pairing_admin_client.dart';
import 'package:tagihan_vendra/features/settings/pairing_scanner_page.dart';

import '../../data/sync/pairing_admin_client_test.dart' show invitationFixture;

void main() {
  late MobileScannerPlatform original;
  late FakeScanner platform;
  late MobileScannerController controller;
  late List<String?> results;
  setUp(() {
    original = MobileScannerPlatform.instance;
    MobileScannerController.resetPlatformSessionOwner();
    platform = FakeScanner();
    MobileScannerPlatform.instance = platform;
    controller = createPairingScannerController();
    results = [];
  });
  tearDown(() async {
    MobileScannerPlatform.instance = original;
    MobileScannerController.resetPlatformSessionOwner();
    await platform.captures.close();
  });

  testWidgets(
    'QR asing dan undangan ganda ditolak; hasil valid menunggu stop dan hanya kembali satu kali',
    (tester) async {
      final code = PairingInvitation.fromJson(invitationFixture()).code;
      final other = PairingInvitation.fromJson({
        ...invitationFixture(),
        'invitation_id': '0199e7d0-0000-7000-8000-000000000076',
      }).code;
      await _open(tester, controller, results);
      await pumpScanner(tester, () => controller.value.isRunning);
      expect(platform.options!.formats, [BarcodeFormat.qrCode]);
      expect(platform.options!.returnImage, isFalse);
      expect(platform.options!.cameraDirection, CameraFacing.back);
      platform.capture(['https://foreign.example/private-token']);
      await tester.pump();
      expect(find.textContaining('QR bukan undangan'), findsOneWidget);
      expect(find.textContaining('private-token'), findsNothing);
      platform.capture([code, other]);
      await tester.pump();
      expect(find.textContaining('beberapa undangan'), findsOneWidget);
      expect(results, isEmpty);
      platform.stopGate = Completer<void>();
      platform.capture([code, code]);
      platform.capture([code]);
      await pumpScanner(tester, () => platform.stops == 1);
      expect(results, isEmpty);
      platform.stopGate!.complete();
      await pumpScanner(tester, () => platform.disposals == 1);
      expect(results, [code]);
      expect(find.text('Buka scanner'), findsOneWidget);
      await _unmount(tester);
    },
  );

  testWidgets(
    'izin ditolak ditampilkan tanpa detail native dan dapat dicoba lagi',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      platform.startError = const MobileScannerException(
        errorCode: MobileScannerErrorCode.permissionDenied,
        errorDetails: MobileScannerErrorDetails(
          message: 'native-secret-detail',
        ),
      );
      await _open(tester, controller, results);
      await pumpScanner(
        tester,
        () => find.textContaining('Izin kamera ditolak').evaluate().isNotEmpty,
      );
      expect(find.textContaining('native-secret-detail'), findsNothing);
      expect(results, isEmpty);
      platform.startError = null;
      await tester.ensureVisible(find.byKey(const ValueKey('scanner-start')));
      await tester.tap(find.byKey(const ValueKey('scanner-start')));
      await pumpScanner(tester, () => controller.value.isRunning);
      expect(platform.starts, 2);
      await _cancel(tester, platform);
      expect(results, [null]);
    },
  );

  testWidgets(
    'background ketika start belum selesai menghentikan start terlambat tanpa auto-resume',
    (tester) async {
      platform.startGate = Completer<void>();
      await _open(tester, controller, results);
      await pumpScanner(tester, () => platform.starts == 1);
      await _background(tester);
      platform.capture([PairingInvitation.fromJson(invitationFixture()).code]);
      await tester.pump();
      platform.startGate!.complete();
      await pumpScanner(tester, () => platform.stops == 1);
      expect(controller.value.isRunning, isFalse);
      expect(results, isEmpty);
      expect(platform.starts, 1);
      await tester.ensureVisible(find.byKey(const ValueKey('scanner-start')));
      await tester.tap(find.byKey(const ValueKey('scanner-start')));
      await pumpScanner(tester, () => controller.value.isRunning);
      expect(platform.starts, 2);
      await _cancel(tester, platform);
    },
  );

  testWidgets(
    'menutup page saat start pending tetap melepas kamera setelah start terlambat',
    (tester) async {
      platform.startGate = Completer<void>();
      await _open(tester, controller, results);
      await pumpScanner(tester, () => platform.starts == 1);
      await tester.ensureVisible(
        find.byKey(const ValueKey('scanner-use-text')),
      );
      await tester.tap(find.byKey(const ValueKey('scanner-use-text')));
      await tester.pump(const Duration(milliseconds: 400));
      expect(results, [null]);
      expect(platform.disposals, 0);
      platform.startGate!.complete();
      await pumpScanner(tester, () => platform.disposals == 1);
      expect(platform.stops, 1);
      await _unmount(tester);
    },
  );

  testWidgets(
    'hasil dibuang jika aplikasi tidak aktif sebelum stop dikonfirmasi',
    (tester) async {
      await _open(tester, controller, results);
      await pumpScanner(tester, () => controller.value.isRunning);
      platform.stopGate = Completer<void>();
      platform.capture([PairingInvitation.fromJson(invitationFixture()).code]);
      await pumpScanner(tester, () => platform.stops == 1);
      await _background(tester);
      platform.stopGate!.complete();
      await pumpScanner(
        tester,
        () =>
            tester
                .widget<OutlinedButton>(
                  find.byKey(const ValueKey('scanner-start')),
                )
                .onPressed !=
            null,
      );
      expect(results, isEmpty);
      expect(controller.value.isRunning, isFalse);
      await _cancel(tester, platform);
    },
  );

  testWidgets(
    'kegagalan stop tidak mengembalikan token dan tetap melepas resource saat ditutup',
    (tester) async {
      await _open(tester, controller, results);
      await pumpScanner(tester, () => controller.value.isRunning);
      platform.stopError = true;
      platform.capture([PairingInvitation.fromJson(invitationFixture()).code]);
      await pumpScanner(
        tester,
        () => find
            .textContaining('Kamera belum dapat diproses')
            .evaluate()
            .isNotEmpty,
      );
      expect(results, isEmpty);
      expect(
        tester
            .widget<OutlinedButton>(find.byKey(const ValueKey('scanner-start')))
            .onPressed,
        isNull,
      );
      await _cancel(tester, platform);
    },
  );

  testWidgets('page default pada Linux tidak mengakses plugin kamera', (
    tester,
  ) async {
    if (!Platform.isLinux) return;
    await tester.pumpWidget(const MaterialApp(home: PairingScannerPage()));
    expect(find.textContaining('tersedia di iPhone'), findsOneWidget);
    expect(platform.starts, 0);
    await _unmount(tester);
    await controller.dispose();
  });
}

// Real MobileScannerController dengan platform palsu; tidak ada kamera fisik.
class FakeScanner extends MobileScannerPlatform {
  final captures = StreamController<BarcodeCapture?>.broadcast(sync: true);
  int starts = 0, stops = 0, disposals = 0;
  StartOptions? options;
  Completer<void>? startGate, stopGate;
  MobileScannerException? startError;
  bool stopError = false;
  void capture(List<String> codes) => captures.add(
    BarcodeCapture(
      barcodes: [
        for (final code in codes)
          Barcode(format: BarcodeFormat.qrCode, rawValue: code),
      ],
    ),
  );
  @override
  Stream<BarcodeCapture?> get barcodesStream => captures.stream;
  @override
  Stream<TorchState> get torchStateStream => const Stream.empty();
  @override
  Stream<double> get zoomScaleStateStream => const Stream.empty();
  @override
  Widget buildCameraView() =>
      const ColoredBox(key: ValueKey('fake-camera'), color: Colors.black);
  @override
  Future<MobileScannerViewAttributes> start(StartOptions startOptions) async {
    starts++;
    options = startOptions;
    await startGate?.future;
    if (startError case final error?) throw error;
    return const MobileScannerViewAttributes(
      cameraDirection: CameraFacing.back,
      currentTorchMode: TorchState.unavailable,
      size: Size(640, 480),
      numberOfCameras: 1,
    );
  }

  @override
  Future<void> stop() async {
    stops++;
    await stopGate?.future;
    if (stopError) throw StateError('native-secret-detail');
  }

  @override
  Future<void> dispose() async {
    disposals++;
  }
}

Future<void> _open(
  WidgetTester tester,
  MobileScannerController controller,
  List<String?> results,
) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              final code = await Navigator.of(context).push<String>(
                MaterialPageRoute(
                  builder: (_) => PairingScannerPage(controller: controller),
                ),
              );
              results.add(code);
            },
            child: const Text('Buka scanner'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Buka scanner'));
  await tester.pump();
}

Future<void> _background(WidgetTester tester) async {
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
  await tester.pump();
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  await tester.pump();
}

Future<void> _cancel(WidgetTester tester, FakeScanner platform) async {
  await tester.ensureVisible(find.byKey(const ValueKey('scanner-use-text')));
  await tester.tap(find.byKey(const ValueKey('scanner-use-text')));
  await pumpScanner(tester, () => platform.disposals == 1);
  await _unmount(tester);
}

Future<void> _unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
  expect(tester.takeException(), isNull);
}

Future<void> pumpScanner(WidgetTester tester, bool Function() ready) async {
  for (var i = 0; i < 100; i++) {
    await tester.pump(const Duration(milliseconds: 20));
    if (ready()) return;
  }
  fail('Operasi scanner tidak selesai dalam batas test.');
}
