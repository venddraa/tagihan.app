import 'package:flutter/material.dart';
import 'package:tagihan_vendra/core/presentation_formatters.dart';
import 'package:tagihan_vendra/data/local/app_database.dart';
import 'package:tagihan_vendra/data/local/sync_operation.dart';
import 'package:tagihan_vendra/domain/bill.dart';
import 'package:tagihan_vendra/domain/payment.dart';

class SyncConflictSection extends StatefulWidget {
  const SyncConflictSection({
    super.key,
    required this.database,
    required this.onResolved,
  });

  final AppDatabase database;
  final Future<void> Function() onResolved;

  @override
  State<SyncConflictSection> createState() => _SyncConflictSectionState();
}

class _SyncConflictSectionState extends State<SyncConflictSection> {
  final Set<String> _resolving = {};
  late Stream<List<SyncConflictGroup>> _conflicts;

  @override
  void initState() {
    super.initState();
    _conflicts = widget.database.watchUnresolvedSyncConflicts();
  }

  @override
  void didUpdateWidget(covariant SyncConflictSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.database != widget.database) {
      _conflicts = widget.database.watchUnresolvedSyncConflicts();
    }
  }

  Future<void> _resolve(
    SyncConflictGroup group,
    SyncConflictResolution resolution,
  ) async {
    final useLocal = resolution == SyncConflictResolution.keepLocal;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Selesaikan data berbeda?'),
        content: Text(
          useLocal
              ? 'Data dari perangkat ini akan direbase di atas versi sync hub dan dikirim pada sync berikutnya.'
              : 'Perubahan lokal yang berbenturan akan dibatalkan, lalu data dari sync hub digunakan.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            key: ValueKey(
              useLocal ? 'confirm-keep-local' : 'confirm-use-remote',
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Lanjutkan'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _resolving.add(group.operationId.value));
    try {
      await widget.database.resolveSyncConflict(
        operationId: group.operationId,
        resolution: resolution,
      );
      await widget.onResolved();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            useLocal
                ? 'Data perangkat ini siap dikirim ulang.'
                : 'Data sync hub sudah diterapkan.',
          ),
        ),
      );
    } on Object catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Conflict belum dapat diselesaikan: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _resolving.remove(group.operationId.value));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<SyncConflictGroup>>(
      stream: _conflicts,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Text('Daftar conflict tidak dapat dimuat.');
        }
        final groups = snapshot.data;
        if (groups == null) {
          return const SizedBox.shrink();
        }
        if (groups.isEmpty) return const SizedBox.shrink();

        return Column(
          key: const ValueKey('sync-conflict-section'),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 32),
            Text(
              'Data berbeda ditemukan',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Tagihan Vendra tidak memilih perubahan secara diam-diam. Periksa kedua versi sebelum menentukan data yang dipakai.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            for (final group in groups) ...[
              _ConflictPanel(
                group: group,
                resolving: _resolving.contains(group.operationId.value),
                onKeepLocal: () =>
                    _resolve(group, SyncConflictResolution.keepLocal),
                onUseRemote: () =>
                    _resolve(group, SyncConflictResolution.useRemote),
              ),
              const SizedBox(height: 16),
            ],
          ],
        );
      },
    );
  }
}

class _ConflictPanel extends StatelessWidget {
  const _ConflictPanel({
    required this.group,
    required this.resolving,
    required this.onKeepLocal,
    required this.onUseRemote,
  });

  final SyncConflictGroup group;
  final bool resolving;
  final VoidCallback onKeepLocal;
  final VoidCallback onUseRemote;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final entry = _representativeEntry(group);
    final local = _snapshotPresentation(entry.entityType, entry.localPayload);
    final remote = _snapshotPresentation(entry.entityType, entry.remotePayload);
    final includesPayment = group.entries.any(
      (value) => value.entityType == SyncEntityType.payment,
    );

    return Container(
      key: ValueKey('sync-conflict-${group.operationId.value}'),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border.all(color: theme.colorScheme.tertiary),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            includesPayment ? 'Pembayaran berbeda' : 'Tagihan berbeda',
            style: theme.textTheme.titleMedium,
          ),
          if (includesPayment) ...[
            const SizedBox(height: 4),
            Text(
              'Mencakup pembayaran dan perubahan tagihan terkait.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final localView = _VersionSummary(
                label: 'Perangkat ini',
                presentation: local,
              );
              final remoteView = _VersionSummary(
                label: 'Sync hub',
                presentation: remote,
              );
              if (constraints.maxWidth < 560) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [localView, const SizedBox(height: 16), remoteView],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: localView),
                  const SizedBox(width: 24),
                  Expanded(child: remoteView),
                ],
              );
            },
          ),
          const SizedBox(height: 20),
          Wrap(
            alignment: WrapAlignment.end,
            spacing: 12,
            runSpacing: 10,
            children: [
              OutlinedButton(
                key: ValueKey('use-remote-${group.operationId.value}'),
                onPressed: resolving ? null : onUseRemote,
                child: const Text('Gunakan sync hub'),
              ),
              FilledButton(
                key: ValueKey('keep-local-${group.operationId.value}'),
                onPressed: resolving ? null : onKeepLocal,
                child: Text(
                  resolving ? 'Menyelesaikan…' : 'Gunakan perangkat ini',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _VersionSummary extends StatelessWidget {
  const _VersionSummary({required this.label, required this.presentation});

  final String label;
  final _SnapshotPresentation presentation;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.labelLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          presentation.primary,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(presentation.secondary),
      ],
    );
  }
}

SyncConflictEntry _representativeEntry(SyncConflictGroup group) {
  return group.entries.firstWhere(
    (entry) => entry.entityType == SyncEntityType.bill,
    orElse: () => group.entries.first,
  );
}

_SnapshotPresentation _snapshotPresentation(
  SyncEntityType entityType,
  Map<String, Object?>? payload,
) {
  if (payload == null) {
    return const _SnapshotPresentation(
      primary: 'Belum ada di perangkat ini',
      secondary: 'Versi 0',
    );
  }
  return switch (entityType) {
    SyncEntityType.bill => _billPresentation(decodeBillSnapshot(payload)),
    SyncEntityType.payment => _paymentPresentation(
      decodePaymentSnapshot(payload),
    ),
  };
}

_SnapshotPresentation _billPresentation(Bill bill) {
  return _SnapshotPresentation(
    primary: bill.name,
    secondary:
        '${formatMoney(bill.amount)} · ${formatCalendarDate(bill.nextDueDate)} · ${_billStatusLabel(bill.status)} · versi ${bill.version}',
  );
}

_SnapshotPresentation _paymentPresentation(Payment payment) {
  return _SnapshotPresentation(
    primary: formatMoney(payment.amount),
    secondary:
        'Dibayar ${formatDateTimeDate(payment.paidAt)} · versi ${payment.version}',
  );
}

String _billStatusLabel(BillStatus status) {
  return switch (status) {
    BillStatus.active => 'Aktif',
    BillStatus.paused => 'Dijeda',
    BillStatus.archived => 'Diarsipkan',
  };
}

final class _SnapshotPresentation {
  const _SnapshotPresentation({required this.primary, required this.secondary});

  final String primary;
  final String secondary;
}
