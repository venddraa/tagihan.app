import 'package:flutter/material.dart';
import 'package:tagihan_vendra/core/presentation_formatters.dart';
import 'package:tagihan_vendra/data/local/app_database.dart';
import 'package:tagihan_vendra/domain/bill.dart';
import 'package:tagihan_vendra/features/bills/bill_form_dialog.dart';

class BillListPage extends StatelessWidget {
  const BillListPage({
    super.key,
    required this.database,
    required this.compact,
  });

  final AppDatabase database;
  final bool compact;

  Future<void> _showForm(BuildContext context, {Bill? bill}) async {
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => BillFormDialog(database: database, bill: bill),
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

  Future<void> _showDetails(BuildContext context, Bill bill) async {
    final action = await showDialog<_BillAction>(
      context: context,
      builder: (_) => _BillDetailsDialog(bill: bill),
    );

    if (!context.mounted || action == null) return;
    if (action == _BillAction.edit) {
      await _showForm(context, bill: bill);
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Archive tagihan?'),
        content: Text(
          '${bill.name} akan disembunyikan dari daftar tagihan aktif.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Batal'),
          ),
          FilledButton(
            key: const ValueKey('confirm-archive-button'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Archive'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;
    try {
      await database.archiveBill(bill.id, DateTime.now().toUtc());
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
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: EdgeInsets.all(compact ? 24 : 40),
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
                spacing: 24,
                runSpacing: 16,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Tagihan', style: textTheme.headlineMedium),
                      const SizedBox(height: 8),
                      Text(
                        'Kelola tagihan dan subscription pribadi.',
                        style: textTheme.bodyLarge,
                      ),
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
              const SizedBox(height: 32),
              Expanded(
                child: StreamBuilder<List<Bill>>(
                  stream: database.watchActiveBills(),
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

                    final bills = snapshot.data!;
                    if (bills.isEmpty) {
                      return _MessageState(
                        icon: Icons.receipt_long_outlined,
                        title: 'Belum ada tagihan',
                        message:
                            'Tambahkan tagihan pertama agar mulai tercatat.',
                        action: TextButton.icon(
                          onPressed: () => _showForm(context),
                          icon: const Icon(Icons.add),
                          label: const Text('Tambah tagihan'),
                        ),
                      );
                    }

                    return ListView.separated(
                      key: const ValueKey('bill-list'),
                      itemCount: bills.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final bill = bills[index];
                        return _BillListItem(
                          bill: bill,
                          onTap: () => _showDetails(context, bill),
                        );
                      },
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
  const _BillListItem({required this.bill, required this.onTap});

  final Bill bill;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return InkWell(
      key: ValueKey('bill-${bill.id.value}'),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 18),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                bill.name.characters.first.toUpperCase(),
                style: TextStyle(
                  color: colorScheme.onPrimaryContainer,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    bill.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    '${formatBillingCycle(bill.billingCycle)} · Jatuh tempo ${formatCalendarDate(bill.nextDueDate)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Text(
              formatMoney(bill.amount),
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(width: 10),
            Icon(Icons.chevron_right, color: colorScheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}

class _BillDetailsDialog extends StatelessWidget {
  const _BillDetailsDialog({required this.bill});

  final Bill bill;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(bill.name),
      content: SizedBox(
        width: 440,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _DetailRow(label: 'Nominal', value: formatMoney(bill.amount)),
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
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Tutup'),
        ),
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
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 112,
            child: Text(
              label,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(child: Text(value)),
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 38, color: colorScheme.onSurfaceVariant),
          const SizedBox(height: 16),
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 6),
          Text(message, style: TextStyle(color: colorScheme.onSurfaceVariant)),
          if (action != null) ...[const SizedBox(height: 12), action!],
        ],
      ),
    );
  }
}

enum _BillAction { edit, archive }
