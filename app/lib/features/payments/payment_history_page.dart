import 'package:flutter/material.dart';
import 'package:tagihan_vendra/core/presentation_formatters.dart';
import 'package:tagihan_vendra/data/local/app_database.dart';
import 'package:tagihan_vendra/features/payments/payment_form_dialog.dart';

class PaymentHistoryPage extends StatelessWidget {
  const PaymentHistoryPage({
    super.key,
    required this.database,
    required this.compact,
  });

  final AppDatabase database;
  final bool compact;

  Future<void> _recordPayment(BuildContext context) async {
    try {
      final bills = await database.getActiveBills();
      if (!context.mounted) return;
      if (bills.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tambahkan tagihan aktif terlebih dahulu.'),
          ),
        );
        return;
      }

      final saved = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (_) => PaymentFormDialog(database: database, bills: bills),
      );
      if (saved == true && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pembayaran berhasil dicatat.')),
        );
      }
    } on Object catch (error) {
      debugPrint('Gagal membuka form pembayaran: ${error.runtimeType}');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Data tagihan tidak dapat dimuat.')),
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
                      Text('Pembayaran', style: textTheme.headlineMedium),
                      const SizedBox(height: 8),
                      Text(
                        'Catat dan lihat riwayat pembayaran.',
                        style: textTheme.bodyLarge,
                      ),
                    ],
                  ),
                  FilledButton.icon(
                    key: const ValueKey('record-payment-button'),
                    onPressed: () => _recordPayment(context),
                    icon: const Icon(Icons.add),
                    label: const Text('Catat pembayaran'),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              Expanded(
                child: StreamBuilder<List<PaymentHistoryEntry>>(
                  stream: database.watchPaymentHistory(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return const _PaymentMessage(
                        icon: Icons.error_outline,
                        title: 'Riwayat tidak dapat dimuat',
                        message: 'Tutup dan buka kembali aplikasi untuk mencoba lagi.',
                      );
                    }
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final entries = snapshot.data!;
                    if (entries.isEmpty) {
                      return _PaymentMessage(
                        icon: Icons.payments_outlined,
                        title: 'Belum ada pembayaran',
                        message: 'Pembayaran yang dicatat akan muncul di sini.',
                        action: TextButton.icon(
                          onPressed: () => _recordPayment(context),
                          icon: const Icon(Icons.add),
                          label: const Text('Catat pembayaran'),
                        ),
                      );
                    }

                    return ListView.separated(
                      key: const ValueKey('payment-list'),
                      itemCount: entries.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final entry = entries[index];
                        return _PaymentListItem(
                          entry: entry,
                          onTap: () => showDialog<void>(
                            context: context,
                            builder: (_) => _PaymentDetailsDialog(entry: entry),
                          ),
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

class _PaymentListItem extends StatelessWidget {
  const _PaymentListItem({required this.entry, required this.onTap});

  final PaymentHistoryEntry entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final payment = entry.payment;
    final colorScheme = Theme.of(context).colorScheme;
    return InkWell(
      key: ValueKey('payment-${payment.id.value}'),
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
              child: Icon(
                Icons.check,
                color: colorScheme.onPrimaryContainer,
                size: 21,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.billName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    'Dibayar ${formatDateTimeDate(payment.paidAt)} · Periode ${formatCalendarDate(payment.dueDate)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Text(
              formatMoney(payment.amount),
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

class _PaymentDetailsDialog extends StatelessWidget {
  const _PaymentDetailsDialog({required this.entry});

  final PaymentHistoryEntry entry;

  @override
  Widget build(BuildContext context) {
    final payment = entry.payment;
    return AlertDialog(
      title: Text(entry.billName),
      content: SizedBox(
        width: 440,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _DetailRow(label: 'Nominal', value: formatMoney(payment.amount)),
            _DetailRow(
              label: 'Dibayar pada',
              value: formatDateTimeDate(payment.paidAt),
            ),
            _DetailRow(
              label: 'Periode tagihan',
              value: formatCalendarDate(payment.dueDate),
            ),
            if (payment.notes != null)
              _DetailRow(label: 'Catatan', value: payment.notes!),
          ],
        ),
      ),
      actions: [
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
            width: 124,
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

class _PaymentMessage extends StatelessWidget {
  const _PaymentMessage({
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
