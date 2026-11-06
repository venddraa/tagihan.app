import 'package:flutter/material.dart';
import 'package:tagihan_vendra/core/presentation_formatters.dart';
import 'package:tagihan_vendra/core/widgets/confirmation_dialog.dart';
import 'package:tagihan_vendra/core/widgets/record_list_item.dart';
import 'package:tagihan_vendra/data/local/app_database.dart';
import 'package:tagihan_vendra/domain/bill.dart';
import 'package:tagihan_vendra/domain/billing_schedule.dart';
import 'package:tagihan_vendra/domain/calendar_date.dart';
import 'package:tagihan_vendra/features/bills/bill_form_dialog.dart';
import 'package:tagihan_vendra/features/payments/payment_form_dialog.dart';

class BillListPage extends StatefulWidget {
  const BillListPage({
    super.key,
    required this.database,
    required this.compact,
  });

  final AppDatabase database;
  final bool compact;

  @override
  State<BillListPage> createState() => _BillListPageState();
}

class _BillListPageState extends State<BillListPage> {
  final _searchController = TextEditingController();
  int _tabIndex = 0; // 0: Aktif, 1: Arsip
  String _searchQuery = '';
  String _activeFilter = 'semua'; // 'semua', 'terlambat', 'segera'
  bool _showSearch = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _showForm(BuildContext context, {Bill? bill}) async {
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => BillFormDialog(database: widget.database, bill: bill),
    );

    if (saved == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            bill == null
                ? 'Tagihan berhasil ditambahkan.'
                : 'Tagihan diperbarui.',
          ),
        ),
      );
    }
  }

  Future<void> _recordPaymentForBill(BuildContext context, Bill bill) async {
    final activeBills = await widget.database.getActiveBills();
    if (!context.mounted) return;
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => PaymentFormDialog(
        database: widget.database,
        bills: activeBills.isEmpty ? [bill] : activeBills,
        initialBill: bill,
      ),
    );

    if (saved == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Pembayaran untuk ${bill.name} berhasil dicatat.'),
        ),
      );
    }
  }

  Future<void> _showDetails(BuildContext context, Bill bill) async {
    final action = await showDialog<_BillAction>(
      context: context,
      builder: (_) => _BillDetailsDialog(bill: bill),
    );

    if (!context.mounted || action == null) return;
    if (action == _BillAction.pay) {
      await _recordPaymentForBill(context, bill);
      return;
    }
    if (action == _BillAction.edit) {
      await _showForm(context, bill: bill);
      return;
    }
    if (action == _BillAction.unarchive) {
      try {
        await widget.database.unarchiveBill(bill.id, DateTime.now().toUtc());
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${bill.name} berhasil dipulihkan ke daftar aktif.')),
          );
        }
      } on Object catch (error) {
        debugPrint('Gagal memulihkan tagihan: ${error.runtimeType}');
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Tagihan tidak dapat dipulihkan.')),
          );
        }
      }
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => ConfirmationDialog(
        icon: Icons.archive_outlined,
        title: 'Archive tagihan?',
        message: '${bill.name} akan disembunyikan dari daftar tagihan aktif.',
        confirmLabel: 'Archive',
        confirmKey: const ValueKey('confirm-archive-button'),
      ),
    );

    if (confirmed != true || !context.mounted) return;
    try {
      await widget.database.archiveBill(bill.id, DateTime.now().toUtc());
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tagihan berhasil di-archive.')),
        );
      }
    } on Object catch (error) {
      debugPrint('Gagal mengarsipkan tagihan: ${error.runtimeType}');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tagihan tidak dapat di-archive.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final colorScheme = theme.colorScheme;
    final isArchivedTab = _tabIndex == 1;

    return Padding(
      padding: EdgeInsets.all(widget.compact ? 16 : 36),
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1040),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 16,
                runSpacing: 10,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Tagihan', style: textTheme.headlineMedium),
                      if (!widget.compact) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Kelola tagihan dan subscription pribadi.',
                          style: textTheme.bodyLarge,
                        ),
                      ],
                    ],
                  ),
                  FilledButton.icon(
                    key: const ValueKey('add-bill-button'),
                    onPressed: () => _showForm(context),
                    icon: const Icon(Icons.add),
                    label: const Text('Tambah tagihan'),
                  ),
                ],
              ),
              SizedBox(height: widget.compact ? 10 : 16),
              // Search & Tab bar
              Row(
                children: [
                  if (!_showSearch) ...[
                    SegmentedButton<int>(
                      showSelectedIcon: false,
                      segments: const [
                        ButtonSegment(
                          value: 0,
                          label: Text('Aktif'),
                        ),
                        ButtonSegment(
                          value: 1,
                          label: Text('Arsip'),
                        ),
                      ],
                      selected: {_tabIndex},
                      onSelectionChanged: (selected) {
                        setState(() => _tabIndex = selected.first);
                      },
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.search),
                      tooltip: 'Cari tagihan',
                      onPressed: () => setState(() => _showSearch = true),
                    ),
                  ] else ...[
                    Expanded(
                      child: SizedBox(
                        height: 40,
                        child: TextField(
                          controller: _searchController,
                          autofocus: true,
                          decoration: InputDecoration(
                            hintText: 'Cari tagihan…',
                            prefixIcon: const Icon(Icons.search, size: 20),
                            suffixIcon: IconButton(
                              icon: const Icon(Icons.close, size: 18),
                              onPressed: () {
                                _searchController.clear();
                                setState(() {
                                  _searchQuery = '';
                                  _showSearch = false;
                                });
                              },
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 8,
                            ),
                          ),
                          onChanged: (value) => setState(
                            () => _searchQuery = value.trim().toLowerCase(),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              if (!isArchivedTab && !_showSearch) ...[
                const SizedBox(height: 10),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      FilterChip(
                        label: const Text('Semua'),
                        selected: _activeFilter == 'semua',
                        onSelected: (_) =>
                            setState(() => _activeFilter = 'semua'),
                      ),
                      const SizedBox(width: 8),
                      FilterChip(
                        label: const Text('Terlambat'),
                        selected: _activeFilter == 'terlambat',
                        onSelected: (_) =>
                            setState(() => _activeFilter = 'terlambat'),
                      ),
                      const SizedBox(width: 8),
                      FilterChip(
                        label: const Text('Segera (7 hari)'),
                        selected: _activeFilter == 'segera',
                        onSelected: (_) =>
                            setState(() => _activeFilter = 'segera'),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Expanded(
                child: StreamBuilder<List<Bill>>(
                  stream: isArchivedTab
                      ? widget.database.watchArchivedBills()
                      : widget.database.watchActiveBills(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return const _MessageState(
                        icon: Icons.error_outline,
                        title: 'Tagihan tidak dapat dimuat',
                        message: 'Tutup dan buka kembali aplikasi untuk mencoba lagi.',
                      );
                    }
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final allBills = snapshot.data!;
                    if (allBills.isEmpty && _searchQuery.isEmpty) {
                      return _MessageState(
                        icon: isArchivedTab ? Icons.archive_outlined : Icons.receipt_long_outlined,
                        title: isArchivedTab ? 'Belum ada arsip' : 'Belum ada tagihan',
                        message: isArchivedTab
                            ? 'Tagihan yang di-archive akan tampil di sini.'
                            : 'Tambahkan tagihan pertama agar mulai tercatat.',
                        action: isArchivedTab
                            ? null
                            : TextButton.icon(
                                onPressed: () => _showForm(context),
                                icon: const Icon(Icons.add),
                                label: const Text('Tambah tagihan'),
                              ),
                      );
                    }

                    // Apply search & filter
                    final today = CalendarDate.fromDateTime(DateTime.now());
                    final filtered = allBills.where((bill) {
                      if (_searchQuery.isNotEmpty) {
                        final nameMatches = bill.name.toLowerCase().contains(_searchQuery);
                        final catMatches = bill.category?.toLowerCase().contains(_searchQuery) ?? false;
                        if (!nameMatches && !catMatches) return false;
                      }
                      if (!isArchivedTab) {
                        if (_activeFilter == 'terlambat') {
                          return isBillOverdue(bill, today);
                        } else if (_activeFilter == 'segera') {
                          return isBillUpcoming(bill, today, withinDays: 7);
                        }
                      }
                      return true;
                    }).toList();

                    if (filtered.isEmpty) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 40),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.search_off_rounded, size: 40, color: colorScheme.onSurfaceVariant),
                              const SizedBox(height: 12),
                              Text('Tidak ada tagihan yang cocok.', style: textTheme.titleMedium),
                              const SizedBox(height: 4),
                              Text(
                                'Coba ubah kata kunci atau filter pencarian.',
                                style: TextStyle(color: colorScheme.onSurfaceVariant),
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    // Card sebagai container list — naik dari scaffold background
                    return Card(
                      clipBehavior: Clip.antiAlias,
                      child: ListView.separated(
                        key: const ValueKey('bill-list'),
                        itemCount: filtered.length,
                        separatorBuilder: (_, _) => const Divider(
                          height: 1,
                          indent: 20,
                          endIndent: 20,
                        ),
                        itemBuilder: (context, index) {
                          final bill = filtered[index];
                          return _BillListItem(
                            bill: bill,
                            isArchived: isArchivedTab,
                            onTap: () => _showDetails(context, bill),
                            onQuickPay: isArchivedTab
                                ? null
                                : () => _recordPaymentForBill(context, bill),
                          );
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BillListItem extends StatelessWidget {
  const _BillListItem({
    required this.bill,
    required this.onTap,
    this.isArchived = false,
    this.onQuickPay,
  });

  final Bill bill;
  final VoidCallback onTap;
  final bool isArchived;
  final VoidCallback? onQuickPay;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final today = CalendarDate.fromDateTime(DateTime.now());
    final overdue = isBillOverdue(bill, today);
    final upcoming = isBillUpcoming(bill, today, withinDays: 7);
    final timingLabel = isArchived
        ? 'Arsip'
        : overdue
        ? 'Terlambat'
        : upcoming
        ? 'Segera'
        : null;

    return RecordListItem(
      key: ValueKey('bill-${bill.id.value}'),
      onTap: onTap,
      title: bill.name,
      amount: formatMoney(bill.amount),
      leading: Container(
        width: 44,
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isArchived
              ? colorScheme.surfaceContainerHigh
              : colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          bill.name.characters.first.toUpperCase(),
          style: TextStyle(
            color: isArchived
                ? colorScheme.onSurfaceVariant
                : colorScheme.onPrimaryContainer,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      subtitle: Wrap(
        spacing: 8,
        runSpacing: 6,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          if (timingLabel != null)
            _TimingLabel(
              label: timingLabel,
              color: isArchived
                  ? colorScheme.onSurfaceVariant
                  : overdue
                  ? colorScheme.error
                  : colorScheme.primary,
            ),
          Text(
            '${formatBillingCycle(bill.billingCycle)} · Jatuh tempo ${formatCalendarDate(bill.nextDueDate)}',
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _TimingLabel extends StatelessWidget {
  const _TimingLabel({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('bill-timing-label'),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withAlpha(28),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall
            ?.copyWith(color: color, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _BillDetailsDialog extends StatelessWidget {
  const _BillDetailsDialog({required this.bill});

  final Bill bill;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isArchived = bill.status == BillStatus.archived;

    return AlertDialog(
      scrollable: true,
      title: Row(
        children: [
          Expanded(child: Text(bill.name)),
          if (isArchived)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                'Arsip',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
      content: SizedBox(
        width: 440,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Nominal',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              formatMoney(bill.amount),
              key: const ValueKey('bill-detail-amount'),
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 14),
            const Divider(height: 1),
            const SizedBox(height: 8),
            _DetailRow(
              label: 'Siklus',
              value: formatBillingCycle(bill.billingCycle),
            ),
            _DetailRow(
              label: 'Jatuh tempo',
              value: formatCalendarDate(bill.nextDueDate),
            ),
            _DetailRow(
              label: 'Tanggal mulai',
              value: formatCalendarDate(bill.startDate),
            ),
            if (bill.category != null)
              _DetailRow(label: 'Kategori', value: bill.category!),
            if (bill.notes != null)
              _DetailRow(label: 'Catatan', value: bill.notes!),
          ],
        ),
      ),
      actions: [
        if (isArchived) ...[
          FilledButton.icon(
            key: const ValueKey('unarchive-bill-button'),
            onPressed: () => Navigator.of(context).pop(_BillAction.unarchive),
            icon: const Icon(Icons.unarchive_outlined, size: 18),
            label: const Text('Pulihkan'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Tutup'),
          ),
        ] else ...[
          TextButton(
            key: const ValueKey('archive-bill-button'),
            onPressed: () => Navigator.of(context).pop(_BillAction.archive),
            child: const Text('Archive'),
          ),
          FilledButton.tonal(
            key: const ValueKey('edit-bill-button'),
            onPressed: () => Navigator.of(context).pop(_BillAction.edit),
            child: const Text('Edit'),
          ),
          FilledButton.icon(
            key: const ValueKey('pay-bill-button'),
            onPressed: () => Navigator.of(context).pop(_BillAction.pay),
            icon: const Icon(Icons.payments_outlined, size: 18),
            label: const Text('Bayar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Tutup'),
          ),
        ],
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          Text(value),
        ],
      ),
    );
  }
}

class _MessageState extends StatelessWidget {
  const _MessageState({
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, size: 28, color: colorScheme.primary),
            ),
            const SizedBox(height: 16),
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: colorScheme.onSurfaceVariant),
            ),
            if (action != null) ...[const SizedBox(height: 12), action!],
          ],
        ),
      ),
    );
  }
}

enum _BillAction { edit, archive, pay, unarchive }
