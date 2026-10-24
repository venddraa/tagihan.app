import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tagihan_vendra/core/presentation_formatters.dart';
import 'package:tagihan_vendra/data/local/app_database.dart';
import 'package:tagihan_vendra/data/sync/pairing_admin_client.dart';
import 'package:tagihan_vendra/data/sync/sync_http.dart';
import 'package:tagihan_vendra/features/settings/pairing_invitation_qr.dart';

class DevicePairingSection extends StatefulWidget {
  const DevicePairingSection({super.key, required this.database, this.client});
  final AppDatabase database;
  final PairingAdminClient? client;
  @override
  State<DevicePairingSection> createState() => _DevicePairingSectionState();
}

class _DevicePairingSectionState extends State<DevicePairingSection>
    with WidgetsBindingObserver {
  late final PairingAdminClient _client = widget.client ?? PairingAdminClient();
  PairingOverview? _overview;
  PairingInvitation? _invitation;
  String? _localDeviceId;
  String? _error;
  String? _invitationNotice;
  Timer? _invitationTimer;
  bool _foreground = true;
  int _visibilityEpoch = 0;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final state = WidgetsBinding.instance.lifecycleState;
    _foreground = state == null || state == AppLifecycleState.resumed;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (_foreground) return;
    _visibilityEpoch++;
    if (_invitation == null) return;
    setState(
      () => _clearInvitation(
        notice: 'Undangan disembunyikan karena aplikasi tidak aktif. Buat undangan baru jika diperlukan.',
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _invitationTimer?.cancel();
    super.dispose();
  }

  void _clearInvitation({String? notice}) {
    _invitationTimer?.cancel();
    _invitationTimer = null;
    _invitation = null;
    _invitationNotice = notice;
  }

  void _revealInvitation(PairingInvitation invitation, int epoch) {
    _clearInvitation();
    if (!_foreground || epoch != _visibilityEpoch) {
      _invitationNotice = 'Undangan tidak ditampilkan karena aplikasi sempat tidak aktif. Buat undangan baru jika diperlukan.';
      return;
    }
    final remaining = invitation.expiresAt.difference(DateTime.now().toUtc());
    if (remaining <= Duration.zero) {
      _invitationNotice = 'Undangan sudah kedaluwarsa menurut jam Fedora. Periksa jam perangkat atau buat undangan baru.';
      return;
    }
    _invitation = invitation;
    // Maksimal lima menit di layar, sekalipun jam lokal berubah. Ini hanya
    // menghapus tampilan; validitas dan pembatalan tetap ditentukan oleh hub.
    final duration = remaining < const Duration(minutes: 5)
        ? remaining
        : const Duration(minutes: 5);
    _invitationTimer = Timer(duration, () {
      if (!mounted) return;
      setState(
        () => _clearInvitation(
          notice: 'Waktu tampilan undangan berakhir. Buat undangan baru jika diperlukan.',
        ),
      );
    });
  }

  Future<void> _copyInvitation() async {
    final invitation = _invitation;
    if (_busy || invitation == null || !_foreground) return;
    if (!DateTime.now().toUtc().isBefore(invitation.expiresAt)) {
      setState(
        () => _clearInvitation(
          notice: 'Undangan sudah kedaluwarsa. Buat undangan baru.',
        ),
      );
      return;
    }
    await _run(() => Clipboard.setData(ClipboardData(text: invitation.code)));
  }

  Future<void> _load() async {
    final overview = await _client.refresh();
    final local = await widget.database.getLocalSyncState();
    if (!mounted) return;
    setState(() {
      _overview = overview;
      _localDeviceId = local.deviceId.value;
      if (_invitation != null &&
          overview.activeInvitationId != _invitation!.id) {
        _clearInvitation();
      }
    });
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } on Object catch (error) {
      if (!mounted) return;
      final message = switch (error) {
        SyncAuthorizationException e => e.message,
        SyncUnavailableException e => e.message,
        SyncProtocolException e => e.message,
        _ => 'Perangkat belum dapat dimuat. Data lokal tetap tersedia.',
      };
      setState(() => _error = message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<bool> _confirm(String title, String message) async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          scrollable: true,
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Batal'),
            ),
            FilledButton(
              key: const ValueKey('confirm-device-action'),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Lanjutkan'),
            ),
          ],
        ),
      ) ??
      false;

  Future<void> _create() async {
    if (_overview!.requests.any(
      (entry) => entry.status == 'pending' || entry.status == 'approving',
    )) {
      if (!await _confirm(
        'Ganti undangan?',
        'Permintaan yang belum selesai akan dibatalkan.',
      )) {
        return;
      }
    }
    if (!mounted) return;
    final epoch = _visibilityEpoch;
    await _run(() async {
      final invitation = await _client.createInvitation();
      if (mounted) setState(() => _revealInvitation(invitation, epoch));
      await _load();
    });
  }

  Future<void> _decide(PairingRequestEntry entry, bool approve) async {
    final message = approve
        ? 'Perangkat ${entry.name} akan mendapat akses ke seluruh data tagihan. Cocokkan request ID di kedua perangkat:\n\n${entry.id}'
        : 'Permintaan ${entry.name} akan ditolak.';
    if (!await _confirm(
          approve ? 'Izinkan perangkat?' : 'Tolak perangkat?',
          message,
        ) ||
        !mounted) {
      return;
    }
    await _run(() async {
      await _client.decide(entry.id, approve: approve);
      await _load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      key: const ValueKey('device-pairing-section'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 32),
        Row(
          children: [
            Expanded(
              child: Text(
                'Perangkat terhubung',
                style: theme.textTheme.titleLarge,
              ),
            ),
            TextButton.icon(
              key: const ValueKey('pairing-refresh'),
              onPressed: _busy ? null : () => _run(_load),
              icon: const Icon(Icons.refresh),
              label: const Text('Perbarui'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        const Text(
          'Sinkronkan Fedora terlebih dahulu sebelum menghubungkan perangkat baru. Perbarui daftar untuk memeriksa permintaan yang menunggu persetujuanmu.',
        ),
        if (_busy)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text('Memproses…'),
          ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              _error!,
              key: const ValueKey('pairing-error'),
              style: TextStyle(color: theme.colorScheme.error),
            ),
          ),
        if (_overview case final overview?) ...[
          const SizedBox(height: 16),
          if (!overview.enabled)
            const Text('Pairing jaringan belum diaktifkan pada service ini.')
          else ...[
            Text('Hub: ${overview.endpoint}', style: theme.textTheme.bodySmall),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                key: const ValueKey('create-pairing-invitation'),
                onPressed: _busy ? null : _create,
                icon: const Icon(Icons.add_link),
                label: const Text('Hubungkan perangkat'),
              ),
            ),
          ],
          if (_invitation case final invitation?) ...[
            const SizedBox(height: 12),
            Text(
              'Undangan berlaku sampai ${formatDateTime(invitation.expiresAt)}.',
            ),
            const Text(
              'Teks ini bersifat rahasia sementara. Undangan baru menggantikan undangan sebelumnya.',
            ),
            ExpansionTile(
              key: ValueKey('pairing-qr-${invitation.id}'),
              title: const Text('QR undangan'),
              tilePadding: EdgeInsets.zero,
              childrenPadding: const EdgeInsets.only(bottom: 12),
              children: [PairingInvitationQr(invitation: invitation)],
            ),
            ExpansionTile(
              key: ValueKey('pairing-text-${invitation.id}'),
              title: const Text('Teks undangan'),
              tilePadding: EdgeInsets.zero,
              children: [
                SelectableText(
                  invitation.code,
                  key: const ValueKey('pairing-invitation-code'),
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                ),
              ],
            ),
            Wrap(
              spacing: 8,
              children: [
                TextButton.icon(
                  onPressed: _busy ? null : _copyInvitation,
                  icon: const Icon(Icons.copy),
                  label: const Text('Salin undangan'),
                ),
                TextButton(
                  onPressed: _busy
                      ? null
                      : () => _run(() async {
                          await _client.cancel(invitation.id);
                          if (mounted) setState(_clearInvitation);
                          await _load();
                        }),
                  child: const Text('Batalkan undangan'),
                ),
              ],
            ),
          ],
          if (_invitationNotice != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                _invitationNotice!,
                key: const ValueKey('pairing-invitation-notice'),
              ),
            ),
          for (final entry in overview.requests) ...[
            const SizedBox(height: 16),
            const Divider(),
            Text(entry.name, style: theme.textTheme.titleMedium),
            SelectableText(
              'Request ID: ${entry.id}',
              style: theme.textTheme.bodySmall,
            ),
            Text(switch (entry.status) {
              'pending' => 'Menunggu persetujuan',
              'approving' => 'Persetujuan belum terkonfirmasi. Ulangi Izinkan untuk memeriksa hasilnya.',
              'approved' => 'Diizinkan',
              'rejected' => 'Ditolak',
              'expired' => 'Kedaluwarsa',
              _ => 'Dibatalkan',
            }),
            if (entry.status == 'pending' || entry.status == 'approving')
              Wrap(
                spacing: 12,
                children: [
                  if (entry.status == 'pending')
                    OutlinedButton(
                      key: ValueKey('reject-pairing-${entry.id}'),
                      onPressed: _busy ? null : () => _decide(entry, false),
                      child: const Text('Tolak'),
                    ),
                  FilledButton(
                    key: ValueKey('approve-pairing-${entry.id}'),
                    onPressed: _busy ? null : () => _decide(entry, true),
                    child: const Text('Izinkan'),
                  ),
                ],
              ),
          ],
          const SizedBox(height: 16),
          if (overview.devices.isEmpty)
            const Text('Belum ada perangkat terdaftar.'),
          for (final device in overview.devices) ...[
            const Divider(),
            Text(
              device.id == _localDeviceId
                  ? '${device.name} · perangkat ini'
                  : device.name,
              style: theme.textTheme.titleMedium,
            ),
            SelectableText(device.id, style: theme.textTheme.bodySmall),
            if (device.revoked)
              const Text('Akses dicabut')
            else if (device.id != _localDeviceId)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  key: ValueKey('revoke-device-${device.id}'),
                  onPressed: _busy
                      ? null
                      : () async {
                          if (!await _confirm(
                                'Cabut akses?',
                                'Perangkat ${device.name} tidak dapat sync lagi. Data yang sudah ada di perangkat tersebut tidak dihapus.',
                              ) ||
                              !mounted) {
                            return;
                          }
                          await _run(() async {
                            await _client.revoke(device.id);
                            await _load();
                          });
                        },
                  child: const Text('Cabut akses'),
                ),
              ),
          ],
        ],
      ],
    );
  }
}
