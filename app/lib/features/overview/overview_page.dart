import 'dart:async';

import 'package:flutter/material.dart';
import 'package:tagihan_vendra/core/presentation_formatters.dart';
import 'package:tagihan_vendra/data/local/app_database.dart';
import 'package:tagihan_vendra/domain/bill.dart';
import 'package:tagihan_vendra/domain/bill_overview.dart';
import 'package:tagihan_vendra/domain/calendar_date.dart';

class OverviewPage extends StatefulWidget {
  const OverviewPage({
    super.key,
    required this.database,
    required this.compact,
    required this.onOpenBills,
    required this.onOpenPayments,
  });

  final AppDatabase database;
  final bool compact;
  final VoidCallback onOpenBills;
  final VoidCallback onOpenPayments;

  @override
  State<OverviewPage> createState() => _OverviewPageState();
}

class _OverviewPageState extends State<OverviewPage>
    with WidgetsBindingObserver {
  late Stream<List<Bill>> _bills;
  late Stream<List<PaymentHistoryEntry>> _payments;
  Timer? _midnightTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _connectStreams();
    _scheduleDateRefresh();
  }

  void _connectStreams() {
    _bills = widget.database.watchActiveBills();
    _payments = widget.database.watchPaymentHistory();
  }

  @override
  void didUpdateWidget(covariant OverviewPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.database != widget.database) _connectStreams();
  }

  void _scheduleDateRefresh() {
    _midnightTimer?.cancel();
    final now = DateTime.now();
    final midnight = DateTime(now.year, now.month, now.day + 1);
    _midnightTimer = Timer(midnight.difference(now), () {
      if (!mounted) return;
      setState(() {});
      _scheduleDateRefresh();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      setState(() {});
      _scheduleDateRefresh();
    }
  }

  @override
  void dispose() {
    _midnightTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final today = CalendarDate.fromDateTime(DateTime.now());
    return StreamBuilder<List<Bill>>(
      stream: _bills,
      builder: (context, billsSnapshot) {
        return StreamBuilder<List<PaymentHistoryEntry>>(
          stream: _payments,
          builder: (context, paymentsSnapshot) {
            if (billsSnapshot.hasError || paymentsSnapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Ringkasan tidak dapat dimuat.'),
                      const SizedBox(height: 12),
                      OutlinedButton(
                        onPressed: () => setState(_connectStreams),
                        child: const Text('Coba lagi'),
                      ),
                    ],
                  ),
                ),
              );
            }
            if (!billsSnapshot.hasData || !paymentsSnapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final overview = BillOverview(billsSnapshot.data!, today);
            final payments = paymentsSnapshot.data!;
            return SingleChildScrollView(
              key: const ValueKey('overview-scroll'),
              padding: EdgeInsets.all(widget.compact ? 24 : 40),
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1040),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Ringkasan',
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${formatCalendarDate(today)} · ${overview.activeCount} tagihan aktif',
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                      const SizedBox(height: 28),
                      _CommitmentSummary(overview: overview),
                      const SizedBox(height: 32),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final overdue = _BillSection(
                            title: 'Terlambat',
                            bills: overview.overdue,
                            emptyText: 'Tidak ada tagihan terlambat.',
                            description: 'Jatuh tempo sebelum hari ini',
                            onOpenBills: widget.onOpenBills,
                            overdue: true,
                          );
                          final upcoming = _BillSection(
                            title: 'Mendatang',
                            bills: overview.upcoming,
                            emptyText:
                                'Tidak ada tagihan dalam 30 hari ke depan.',
                            description: 'Hari ini sampai 30 hari ke depan',
                            onOpenBills: widget.onOpenBills,
                          );
                          if (constraints.maxWidth < 700) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                overdue,
                                const SizedBox(height: 28),
                                upcoming,
                              ],
                            );
                          }
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(child: overdue),
                              const SizedBox(width: 36),
                              Expanded(child: upcoming),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 32),
                      _SectionHeader(
                        title: 'Pembayaran terbaru',
                        onOpen: widget.onOpenPayments,
                      ),
                      if (payments.isEmpty)
                        const _EmptyMessage('Belum ada pembayaran tercatat.')
                      else
                        for (final entry in payments.take(5))
                          _SummaryRow(
                            title: entry.billName,
                            subtitle:
                                'Dibayar ${formatDateTimeDate(entry.payment.paidAt)} · Periode ${formatCalendarDate(entry.payment.dueDate)}',
                            amount: formatMoney(entry.payment.amount),
                            onTap: widget.onOpenPayments,
                          ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _CommitmentSummary extends StatelessWidget {
  const _CommitmentSummary({required this.overview});

  final BillOverview overview;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      key: const ValueKey('monthly-commitment'),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(10),
        color: theme.colorScheme.surface,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Komitmen bulanan', style: theme.textTheme.titleMedium),
          const SizedBox(height: 10),
          if (overview.monthlyCommitments.isEmpty)
            Text('Rp0', style: theme.textTheme.headlineMedium)
          else
            for (final amount in overview.monthlyCommitments)
              Text(formatMoney(amount), style: theme.textTheme.headlineMedium),
          const SizedBox(height: 12),
          Text(
            'Estimasi rata-rata tagihan berulang aktif, bukan total pembayaran bulan ini. '
            'Mingguan × 52 ÷ 12, bulanan penuh, tahunan ÷ 12; satu kali tidak dihitung. '
            'Dibulatkan ke satuan terkecil masing-masing mata uang.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _BillSection extends StatelessWidget {
  const _BillSection({
    required this.title,
    required this.bills,
    required this.emptyText,
    required this.description,
    required this.onOpenBills,
    this.overdue = false,
  });

  final String title;
  final List<Bill> bills;
  final String emptyText;
  final String description;
  final VoidCallback onOpenBills;
  final bool overdue;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionHeader(
          title: '$title (${bills.length})',
          onOpen: onOpenBills,
          color: overdue && bills.isNotEmpty ? theme.colorScheme.error : null,
        ),
        Text(description, style: theme.textTheme.bodySmall),
        const SizedBox(height: 8),
        if (bills.isEmpty)
          _EmptyMessage(emptyText)
        else ...[
          for (final bill in bills.take(5))
            _SummaryRow(
              title: bill.name,
              subtitle:
                  '${formatCalendarDate(bill.nextDueDate)} · ${formatBillingCycle(bill.billingCycle)}',
              amount: formatMoney(bill.amount),
              onTap: onOpenBills,
            ),
          if (bills.length > 5)
            Text(
              'Menampilkan 5 dari ${bills.length} tagihan.',
              style: theme.textTheme.bodySmall,
            ),
        ],
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.onOpen, this.color});

  final String title;
  final VoidCallback onOpen;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleMedium
                ?.copyWith(color: color),
          ),
        ),
        TextButton(onPressed: onOpen, child: const Text('Lihat semua')),
      ],
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.title,
    required this.subtitle,
    required this.amount,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final String amount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: theme.colorScheme.outlineVariant),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text(subtitle, style: theme.textTheme.bodySmall),
            const SizedBox(height: 6),
            Text(amount),
          ],
        ),
      ),
    );
  }
}

class _EmptyMessage extends StatelessWidget {
  const _EmptyMessage(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Text(
        message,
        style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
      ),
    );
  }
}
