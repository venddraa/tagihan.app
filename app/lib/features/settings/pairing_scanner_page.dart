import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:tagihan_vendra/data/sync/pairing_admin_client.dart';

MobileScannerController createPairingScannerController() =>
    MobileScannerController(
      autoStart: false,
      facing: CameraFacing.back,
      formats: const [BarcodeFormat.qrCode],
      detectionSpeed: DetectionSpeed.noDuplicates,
      returnImage: false,
    );

class PairingScannerPage extends StatefulWidget {
  const PairingScannerPage({super.key, this.controller});

  // Page memiliki lifecycle controller, termasuk controller yang diinjeksi test.
  final MobileScannerController? controller;
  @override
  State<PairingScannerPage> createState() => _PairingScannerPageState();
}

class _PairingScannerPageState extends State<PairingScannerPage>
    with WidgetsBindingObserver {
  late final bool _supported = widget.controller != null || Platform.isIOS;
  late final MobileScannerController _controller;
  Future<void> _cameraWork = Future<void>.value();
  bool _foreground = true, _wanted = false, _starting = false;
  bool _finishing = false, _leaving = false, _fault = false;
  int _visibilityEpoch = 0;
  String? _message;

  bool get _current => mounted && (ModalRoute.of(context)?.isCurrent ?? false);

  @override
  void initState() {
    super.initState();
    assert(widget.controller == null || !widget.controller!.autoStart);
    if (!_supported) return;
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    _foreground = lifecycle == null || lifecycle == AppLifecycleState.resumed;
    _controller = widget.controller ?? createPairingScannerController();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _foreground) _start();
    });
  }

  void _queue(Future<void> Function() action) {
    // Stop/dispose menunggu start yang masih meminta izin. Start yang terlambat
    // tidak boleh menghidupkan kamera kembali setelah page ditutup/background.
    _cameraWork = _cameraWork.then((_) => action()).catchError((Object error) {
      _wanted = false;
      if (!mounted || _leaving) return;
      setState(() {
        _starting = false;
        _finishing = false;
        _fault = true;
        _message = 'Kamera belum dapat diproses. Tutup halaman scan lalu coba lagi, atau gunakan teks undangan.';
      });
    });
  }

  void _start() {
    if (!_current ||
        !_foreground ||
        _starting ||
        _finishing ||
        _leaving ||
        _fault) {
      return;
    }
    setState(() {
      _wanted = true;
      _starting = true;
      _message = null;
    });
    _queue(() async {
      try {
        if (_wanted && _foreground && !_leaving && mounted) {
          await _controller.start();
        }
        if (!_wanted || !_foreground || _leaving || !mounted) {
          await _controller.stop();
        } else if (_controller.value.error case final error?) {
          _wanted = false;
          if (mounted) setState(() => _message = _cameraError(error));
        }
      } finally {
        if (mounted && !_leaving) setState(() => _starting = false);
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (_foreground) {
      // Rebuild hanya untuk mengaktifkan tombol; kamera tidak auto-resume.
      if (mounted && !_leaving) setState(() {});
      return;
    }
    _visibilityEpoch++;
    _wanted = false;
    if (mounted && !_leaving) {
      setState(
        () => _message = 'Pemindaian dijeda. Setelah kembali atau mengizinkan kamera, tekan Mulai kamera.',
      );
    }
    _queue(_controller.stop);
  }

  void _detect(BarcodeCapture capture) {
    if (!_current ||
        !_foreground ||
        !_wanted ||
        !_controller.value.isRunning ||
        _finishing ||
        _leaving ||
        _fault) {
      return;
    }
    final invitations = <String, PairingInvitation>{};
    var sawQR = false;
    for (final barcode in capture.barcodes) {
      if (barcode.format != BarcodeFormat.qrCode) continue;
      sawQR = true;
      try {
        final invitation = PairingInvitation.fromCode(barcode.rawValue ?? '');
        invitations[invitation.code] = invitation;
      } on FormatException {
        /* Abaikan payload asing tanpa membuka URL/log. */
      }
    }
    if (invitations.length != 1) {
      final message = invitations.length > 1
          ? 'Ada beberapa undangan. Arahkan kamera ke satu QR saja.'
          : sawQR
          ? 'QR bukan undangan Tagihan Vendra yang valid. Coba QR dari Fedora.'
          : null;
      if (message != null && _message != message) {
        setState(() => _message = message);
      }
      return;
    }
    final invitation = invitations.values.single;
    final epoch = _visibilityEpoch;
    setState(() {
      _finishing = true;
      _wanted = false;
    });
    _queue(() async {
      await _controller.stop();
      if (!mounted || !_current || _leaving) return;
      if (!_foreground || epoch != _visibilityEpoch) {
        setState(() {
          _finishing = false;
          _message =
              'Pemindaian dijeda. Tekan Mulai kamera untuk memindai ulang.';
        });
        return;
      }
      Navigator.of(context).pop(invitation.code);
    });
  }

  void _detectError(Object error, StackTrace trace) {
    if (!mounted || _leaving) return;
    _wanted = false;
    setState(
      () => _message = 'QR belum dapat dibaca. Tekan Mulai kamera untuk mencoba lagi atau gunakan teks undangan.',
    );
    _queue(_controller.stop);
  }

  void _didPop(bool didPop, String? result) {
    if (!didPop || !_supported) return;
    _leaving = true;
    _wanted = false;
    _queue(_controller.stop);
  }

  @override
  void dispose() {
    if (_supported) {
      WidgetsBinding.instance.removeObserver(this);
      _leaving = true;
      _wanted = false;
      _queue(() async {
        try {
          await _controller.stop();
        } finally {
          await _controller.dispose();
        }
      });
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope<String>(
    onPopInvokedWithResult: _didPop,
    child: Scaffold(
      appBar: AppBar(title: const Text('Pindai undangan')),
      body: !_supported
          ? const Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'Pemindaian kamera tersedia di iPhone. Gunakan teks undangan pada Fedora.',
              ),
            )
          : SafeArea(
              child: Column(
                children: [
                  Expanded(
                    child: MobileScanner(
                      controller: _controller,
                      onDetect: _detect,
                      onDetectError: _detectError,
                      errorBuilder: (_, _) => const ColoredBox(
                        color: Colors.black,
                        child: Center(
                          child: Icon(
                            Icons.videocam_off_outlined,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      placeholderBuilder: (_) =>
                          const ColoredBox(color: Colors.black),
                    ),
                  ),
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text(
                            'Arahkan kamera ke QR undangan di Fedora. Setelah terbaca, tinjau identitas hub sebelum mengirim permintaan pairing.',
                          ),
                          if (_message != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 12),
                              child: Text(
                                _message!,
                                key: const ValueKey('scanner-message'),
                              ),
                            ),
                          if (_starting || _finishing)
                            const Padding(
                              padding: EdgeInsets.only(top: 12),
                              child: LinearProgressIndicator(),
                            ),
                          const SizedBox(height: 12),
                          OutlinedButton(
                            key: const ValueKey('scanner-start'),
                            onPressed:
                                _starting ||
                                    _finishing ||
                                    _wanted ||
                                    _fault ||
                                    !_foreground
                                ? null
                                : _start,
                            child: const Text('Mulai kamera'),
                          ),
                          TextButton(
                            key: const ValueKey('scanner-use-text'),
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text('Gunakan teks undangan'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    ),
  );
}

String _cameraError(MobileScannerException error) => switch (error.errorCode) {
  MobileScannerErrorCode.permissionDenied => 'Izin kamera ditolak. Aktifkan izin kamera untuk aplikasi ini di Settings iPhone, lalu tekan Mulai kamera.',
  MobileScannerErrorCode.unsupported =>
    'Kamera tidak tersedia pada perangkat ini. Gunakan teks undangan.',
  _ => 'Kamera belum dapat dimulai. Coba lagi atau gunakan teks undangan.',
};
