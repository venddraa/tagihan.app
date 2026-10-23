import 'package:flutter/material.dart';
import 'package:tagihan_vendra/data/sync/pairing_receiver.dart';
import 'package:tagihan_vendra/data/sync/sync_http.dart';

class PairingReceiverSection extends StatefulWidget {
  const PairingReceiverSection({
    super.key,
    required this.receiver,
    required this.syncing,
    required this.onBusyChanged,
  });
  final PairingReceiver receiver;
  final bool syncing;
  final ValueChanged<bool> onBusyChanged;

  @override
  State<PairingReceiverSection> createState() => _PairingReceiverSectionState();
}

class _PairingReceiverSectionState extends State<PairingReceiverSection> {
  final _name = TextEditingController(text: 'Perangkat pribadi');
  final _code = TextEditingController();
  PairingProfile? _profile;
  String? _message;
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _code.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy || widget.syncing) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    widget.onBusyChanged(true);
    try {
      await action();
    } on SyncAuthorizationException catch (error) {
      _message = error.message;
    } on SyncProtocolException catch (error) {
      _message = error.message;
    } on SyncUnavailableException catch (error) {
      _message = '${error.message} Sesi tersimpan dapat dilanjutkan.';
    } on FormatException {
      _message = 'Periksa teks undangan dan nama perangkat.';
    } on Object {
      _message = 'Pairing belum selesai. Data lokal dan credential yang sudah tersimpan tetap dipertahankan.';
    } finally {
      if (mounted) {
        setState(() => _busy = false);
        widget.onBusyChanged(false);
      }
    }
  }

  Future<void> _begin() => _run(() async {
    // Kosongkan input rahasia setelah durably disimpan, termasuk jika timeout.
    try {
      _profile = await widget.receiver.begin(_code.text, _name.text);
    } finally {
      final saved = await widget.receiver.readProfile();
      if (mounted && saved != null) {
        _profile = saved;
        _code.clear();
      }
    }
  });

  Future<void> _refresh() => _run(() async {
    _profile = await widget.receiver.readProfile();
    if (_profile == null) {
      _message =
          'Belum ada sesi tersimpan. Masukkan undangan baru dari Fedora.';
      return;
    }
    if (mounted) _code.clear();
    _profile = await widget.receiver.resume();
  });

  Future<void> _cancel() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Batalkan pairing?'),
        content: const SingleChildScrollView(
          child: Text(
            'Hub harus dapat dihubungi untuk memastikan request belum diizinkan. Data tagihan lokal tetap tersimpan.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Kembali'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Batalkan pairing'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _run(() async {
      await widget.receiver.cancel();
      _profile = null;
      _message = 'Sesi pairing dibatalkan. Kamu dapat memakai undangan baru.';
    });
  }

  @override
  Widget build(BuildContext context) {
    final profile = _profile;
    final disabled = _busy || widget.syncing;
    return Padding(
      padding: const EdgeInsets.only(top: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Divider(),
          const SizedBox(height: 20),
          Text(
            'Hubungkan ke Fedora',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          const Text(
            'Tempel undangan dari Fedora, lalu cocokkan request ID pada kedua perangkat sebelum Fedora memberi izin. Status diperiksa saat kamu menekan tombol.',
          ),
          const SizedBox(height: 16),
          if (profile == null) ...[
            TextField(
              key: const ValueKey('pairing-device-name'),
              controller: _name,
              enabled: !disabled,
              maxLength: 80,
              decoration: const InputDecoration(labelText: 'Nama perangkat'),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey('pairing-invitation-input'),
              controller: _code,
              enabled: !disabled,
              minLines: 3,
              maxLines: 5,
              autocorrect: false,
              enableSuggestions: false,
              decoration: const InputDecoration(
                labelText: 'Teks undangan',
                hintText: 'tagihan-pairing-v1:…',
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: disabled ? null : _begin,
              child: const Text('Kirim permintaan pairing'),
            ),
          ] else ...[
            Text(
              'Status: ${_label(profile.status)}',
              key: const ValueKey('pairing-receiver-status'),
            ),
            const SizedBox(height: 8),
            SelectableText('Request ID: ${profile.requestId}'),
            const SizedBox(height: 8),
            SelectableText('Hub: ${profile.hubId}\n${profile.endpoint}'),
            if (profile.paired)
              const Padding(
                padding: EdgeInsets.only(top: 12),
                child: Text(
                  'Perangkat diizinkan. Tekan “Sinkronkan sekarang” untuk mengirim dan menerima perubahan.',
                ),
              ),
          ],
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: disabled ? null : _refresh,
            child: const Text('Periksa sesi dan status'),
          ),
          if (profile != null && !profile.paired)
            TextButton(
              onPressed: disabled ? null : _cancel,
              child: const Text('Batalkan sesi pairing'),
            ),
          if (_busy)
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: LinearProgressIndicator(),
            ),
          if (_message != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                _message!,
                key: const ValueKey('pairing-receiver-message'),
              ),
            ),
        ],
      ),
    );
  }
}

String _label(String status) => switch (status) {
  'pending' => 'Menunggu persetujuan Fedora',
  'approving' => 'Persetujuan sedang diproses',
  'paired' => 'Terhubung',
  'rejected' => 'Ditolak',
  'expired' => 'Kedaluwarsa',
  'cancelled' => 'Dibatalkan',
  _ => 'Belum diketahui',
};
