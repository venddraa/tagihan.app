import 'dart:async';

import 'package:flutter/material.dart';
import 'package:tagihan_vendra/core/presentation_formatters.dart';
import 'package:tagihan_vendra/data/local/app_database.dart';
import 'package:tagihan_vendra/data/sync/sync_coordinator.dart';
import 'package:tagihan_vendra/features/settings/sync_conflict_section.dart';
import 'package:tagihan_vendra/features/settings/device_pairing_section.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({
    super.key,
    required this.database,
    required this.syncCoordinator,
    required this.compact,
  });

  final AppDatabase database;
  final SyncCoordinator syncCoordinator;
  final bool compact;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late SyncRuntimeStatus _status;
  late StreamSubscription<SyncRuntimeStatus> _statusSubscription;

  @override
  void initState() {
    super.initState();
    _status = widget.syncCoordinator.status;
    _connectCoordinator();
    unawaited(widget.syncCoordinator.refreshLocalStatus());
  }

  void _connectCoordinator() {
    _statusSubscription = widget.syncCoordinator.statusChanges.listen((status) {
      if (mounted) setState(() => _status = status);
    });
  }

  @override
  void didUpdateWidget(covariant SettingsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.syncCoordinator == widget.syncCoordinator) return;
    unawaited(_statusSubscription.cancel());
    _status = widget.syncCoordinator.status;
    _connectCoordinator();
    unawaited(widget.syncCoordinator.refreshLocalStatus());
  }

  @override
  void dispose() {
    unawaited(_statusSubscription.cancel());
    super.dispose();
  }

  Future<void> _synchronize() async {
    await widget.syncCoordinator.synchronize();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      key: const ValueKey('settings-scroll'),
      padding: EdgeInsets.all(widget.compact ? 24 : 40),
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Pengaturan', style: theme.textTheme.headlineMedium),
              const SizedBox(height: 8),
              Text(
                'Kelola sinkronisasi tanpa mengubah cara aplikasi bekerja secara offline.',
                style: theme.textTheme.bodyLarge,
              ),
              const SizedBox(height: 32),
              Text('Sinkronisasi perangkat', style: theme.textTheme.titleLarge),
              const SizedBox(height: 8),
              Text(
                widget.syncCoordinator.bootstrapPolicy ==
                        SyncBootstrapPolicy.initializeHub
                    ? 'Fedora ini menggunakan sync hub lokal. Service tetap dibatasi ke komputer ini sampai pairing perangkat tersedia.'
                    : 'Perangkat ini menyimpan data sendiri dan hanya menghubungi sync hub saat kamu meminta sinkronisasi.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 20),
              _SyncStatusPanel(status: _status),
              const SizedBox(height: 20),
              FilledButton.icon(
                key: const ValueKey('sync-now-button'),
                onPressed: _status.phase == SyncRuntimePhase.syncing
                    ? null
                    : _synchronize,
                icon: _status.phase == SyncRuntimePhase.syncing
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.sync),
                label: Text(
                  _status.phase == SyncRuntimePhase.syncing
                      ? 'Menyinkronkan…'
                      : 'Sinkronkan sekarang',
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Tidak ada data finansial yang dikirim ke layanan cloud. Jika hub tidak tersedia, perubahan tetap tersimpan di perangkat ini.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              SyncConflictSection(
                database: widget.database,
                onResolved: widget.syncCoordinator.refreshLocalStatus,
              ),
              DevicePairingSection(database: widget.database),
            ],
          ),
        ),
      ),
    );
  }
}

class _SyncStatusPanel extends StatelessWidget {
  const _SyncStatusPanel({required this.status});

  final SyncRuntimeStatus status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final presentation = _presentationFor(status.phase, theme.colorScheme);
    return Semantics(
      liveRegion: true,
      label: '${presentation.label}. ${status.message}',
      child: Container(
        key: const ValueKey('sync-status-panel'),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          border: Border.all(color: theme.colorScheme.outlineVariant),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(presentation.icon, color: presentation.color),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    presentation.label,
                    key: const ValueKey('sync-status-label'),
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: presentation.color,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(status.message),
            if (status.phase == SyncRuntimePhase.syncing) ...[
              const SizedBox(height: 16),
              const LinearProgressIndicator(),
            ],
            const SizedBox(height: 20),
            const Divider(height: 1),
            const SizedBox(height: 16),
            _StatusValue(
              label: 'Perubahan menunggu',
              value: status.pendingChanges.toString(),
              valueKey: const ValueKey('sync-pending-count'),
            ),
            const SizedBox(height: 12),
            _StatusValue(
              label: 'Conflict belum selesai',
              value: status.conflicts.toString(),
              valueKey: const ValueKey('sync-conflict-count'),
            ),
            const SizedBox(height: 12),
            _StatusValue(
              label: 'Sync terakhir sesi ini',
              value: status.lastSyncAt == null
                  ? 'Belum ada'
                  : formatDateTime(status.lastSyncAt!),
              valueKey: const ValueKey('sync-last-time'),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusValue extends StatelessWidget {
  const _StatusValue({
    required this.label,
    required this.value,
    required this.valueKey,
  });

  final String label;
  final String value;
  final Key valueKey;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        const SizedBox(width: 16),
        Text(
          value,
          key: valueKey,
          textAlign: TextAlign.end,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

({String label, IconData icon, Color color}) _presentationFor(
  SyncRuntimePhase phase,
  ColorScheme colors,
) {
  return switch (phase) {
    SyncRuntimePhase.idle => (
      label: 'Siap offline',
      icon: Icons.offline_bolt_outlined,
      color: colors.onSurfaceVariant,
    ),
    SyncRuntimePhase.syncing => (
      label: 'Menyinkronkan',
      icon: Icons.sync,
      color: colors.primary,
    ),
    SyncRuntimePhase.synced => (
      label: 'Tersinkron',
      icon: Icons.check_circle_outline,
      color: colors.primary,
    ),
    SyncRuntimePhase.offline => (
      label: 'Hub tidak tersedia',
      icon: Icons.cloud_off_outlined,
      color: colors.onSurfaceVariant,
    ),
    SyncRuntimePhase.conflict => (
      label: 'Perlu keputusan',
      icon: Icons.warning_amber_rounded,
      color: colors.tertiary,
    ),
    SyncRuntimePhase.failed => (
      label: 'Sync gagal',
      icon: Icons.error_outline,
      color: colors.error,
    ),
  };
}
