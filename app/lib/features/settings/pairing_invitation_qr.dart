import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:tagihan_vendra/data/sync/pairing_admin_client.dart';

// QR hanya representasi lokal dari undangan. Tidak membuat credential/request
// baru, tidak membuka jaringan, dan tidak memuat token ke semantics label.
class PairingInvitationQr extends StatefulWidget {
  const PairingInvitationQr({super.key, required this.invitation});
  final PairingInvitation invitation;

  @override
  State<PairingInvitationQr> createState() => _PairingInvitationQrState();
}

class _PairingInvitationQrState extends State<PairingInvitationQr> {
  QrCode? _qr;

  @override
  void initState() {
    super.initState();
    _prepare();
  }

  @override
  void didUpdateWidget(covariant PairingInvitationQr oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.invitation.code != widget.invitation.code) _prepare();
  }

  void _prepare() {
    final result = QrValidator.validate(
      data: widget.invitation.code,
      errorCorrectionLevel: QrErrorCorrectLevel.M,
    );
    _qr = result.isValid ? result.qrCode : null;
  }

  @override
  Widget build(BuildContext context) {
    final qr = _qr;
    if (qr == null) {
      return const Text('QR tidak dapat ditampilkan. Gunakan Salin undangan.');
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final available = constraints.maxWidth.isFinite
            ? constraints.maxWidth.clamp(0.0, 432.0)
            : 432.0;
        final ratio = MediaQuery.devicePixelRatioOf(context);
        final modules = qr.moduleCount + 8; // Quiet zone empat modul per sisi.
        // qr_flutter membulatkan ukuran modul ke setengah logical pixel. Pilih
        // ukuran bulat supaya matrix dan quiet zone tidak berubah karena pembulatan.
        final moduleSize = (available / modules).floorToDouble();
        if (moduleSize < 1) {
          return const Text(
            'Perbesar jendela untuk menampilkan QR atau gunakan Salin undangan.',
          );
        }
        final size = modules * moduleSize;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: RepaintBoundary(
                key: const ValueKey('pairing-qr-image'),
                child: QrImageView.withQr(
                  qr: qr,
                  size: size,
                  padding: EdgeInsets.all(4 * moduleSize),
                  backgroundColor: Colors.white,
                  eyeStyle: const QrEyeStyle(
                    eyeShape: QrEyeShape.square,
                    color: Colors.black,
                  ),
                  dataModuleStyle: const QrDataModuleStyle(
                    dataModuleShape: QrDataModuleShape.square,
                    color: Colors.black,
                  ),
                  gapless: true,
                  semanticsLabel: 'QR undangan pairing rahasia. Isinya sama dengan teks undangan.',
                  errorStateBuilder: (_, _) => const Text(
                    'QR tidak dapat ditampilkan. Gunakan Salin undangan.',
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'QR memuat undangan yang sama dengan teks. Bagikan hanya ke perangkat yang ingin kamu izinkan.',
            ),
            const SizedBox(height: 8),
            const Text(
              'Pemindai di aplikasi penerima belum tersedia. Gunakan Salin undangan untuk pairing saat ini.',
            ),
            if (moduleSize * ratio < 3)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text('Perbesar jendela agar QR lebih mudah dipindai.'),
              ),
          ],
        );
      },
    );
  }
}
