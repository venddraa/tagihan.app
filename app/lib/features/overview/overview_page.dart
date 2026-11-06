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
              padding: EdgeInsets.all(widget.compact ? 20 : 36),
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
                      const SizedBox(height: 24),
                      _CommitmentSummary(overview: overview),
                      const SizedBox(height: 20),
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
                                const SizedBox(height: 20),
                                upcoming,
                              ],
                            );
                          }
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(child: overdue),
                              const SizedBox(width: 20),
                              Expanded(child: upcoming),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 20),
                      // Section pembayaran terbaru sebagai Card panel
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _SectionHeader(
                                title: 'Pembayaran terbaru',
                                onOpen: widget.onOpenPayments,
                              ),
                              if (payments.isEmpty)
                                const _EmptyMessage(
                                  'Belum ada pembayaran tercatat.',
                                )
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
                      const SizedBox(height: 8),
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
    final colorScheme = theme.colorScheme;
    return Card(
      key: const ValueKey('monthly-commitment'),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 22, 24, 22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.trending_up_rounded,
                    size: 17,
                    color: colorScheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'ESTIMASI KOMITMEN BULANAN',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: colorScheme.primary,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.1,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (overview.monthlyCommitments.isEmpty)
              Text(
                'Rp0',
                key: const ValueKey('monthly-commitment-amount'),
                style: theme.textTheme.headlineMedium?.copyWith(fontSize: 36),
              )
            else
              for (final amount in overview.monthlyCommitments)
                Text(
                  formatMoney(amount),
                  key: const ValueKey('monthly-commitment-amount'),
                  style: theme.textTheme.headlineMedium?.copyWith(fontSize: 36),
                ),
            const SizedBox(height: 10),
            Text(
              'Rata-rata tagihan berulang aktif per bulan. Tagihan satu kali dan pembayaran historis tidak dihitung.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
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
    final accentColor = overdue && bills.isNotEmpty
        ? theme.colorScheme.error
        : theme.colorScheme.primary;

    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Accent strip di atas card jika overdue
          if (overdue && bills.isNotEmpty)
            Container(
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.error,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _SectionHeader(
                  title: '$title (${bills.length})',
                  onOpen: onOpenBills,
                  color: overdue && bills.isNotEmpty ? accentColor : null,
                ),
                Text(description, style: theme.textTheme.bodySmall),
                const SizedBox(height: 4),
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
            ),
          ),
        ],
      ),
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
    final colorScheme = theme.colorScheme;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        hoverColor: colorScheme.surfaceContainerHigh,
        onTap: onTap,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final placeAmountBeside = constraints.maxWidth >= 380;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            if (placeAmountBeside) ...[
                              const SizedBox(width: 16),
                              Text(
                                amount,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                        if (!placeAmountBeside) ...[
                          const SizedBox(height: 6),
                          Text(
                            amount,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 18,
                    color: colorScheme.onSurfaceVariant.withAlpha(140),
                  ),
                ],
              ),
            );
          },
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
