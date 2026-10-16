import 'package:flutter/material.dart';
import 'package:tagihan_vendra/data/local/app_database.dart';
import 'package:tagihan_vendra/features/bills/bill_list_page.dart';
import 'package:tagihan_vendra/features/overview/overview_page.dart';
import 'package:tagihan_vendra/features/payments/payment_history_page.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.database});

  final AppDatabase database;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  static const _desktopBreakpoint = 860.0;

  static const _destinations = [
    _AppDestination(
      label: 'Ringkasan',
      description: 'Pantau tagihan yang perlu diperhatikan.',
    ),
    _AppDestination(
      label: 'Tagihan',
      description: 'Kelola tagihan dan subscription pribadi.',
    ),
    _AppDestination(
      label: 'Pembayaran',
      description: 'Lihat dan catat riwayat pembayaran.',
    ),
    _AppDestination(
      label: 'Pengaturan',
      description: 'Atur preferensi aplikasi.',
    ),
  ];

  int _selectedIndex = 0;

  void _selectDestination(int index) {
    setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final destination = _destinations[_selectedIndex];

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < _desktopBreakpoint) {
          return _CompactShell(
            database: widget.database,
            destination: destination,
            destinations: _destinations,
            selectedIndex: _selectedIndex,
            onDestinationSelected: _selectDestination,
          );
        }

        return _DesktopShell(
          database: widget.database,
          destination: destination,
          destinations: _destinations,
          selectedIndex: _selectedIndex,
          onDestinationSelected: _selectDestination,
        );
      },
    );
  }
}

class _DesktopShell extends StatelessWidget {
  const _DesktopShell({
    required this.database,
    required this.destination,
    required this.destinations,
    required this.selectedIndex,
    required this.onDestinationSelected,
  });

  final AppDatabase database;
  final _AppDestination destination;
  final List<_AppDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            SizedBox(
              key: const ValueKey('desktop-header'),
              width: double.infinity,
              height: 76,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  const Positioned(left: 32, child: _Brand()),
                  Row(
                    key: const ValueKey('desktop-navigation'),
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (var index = 0; index < destinations.length; index++)
                        _TopNavigationItem(
                          key: ValueKey('desktop-destination-$index'),
                          label: destinations[index].label,
                          selected: selectedIndex == index,
                          onTap: () => onDestinationSelected(index),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: _DestinationContent(
                database: database,
                destination: destination,
                selectedIndex: selectedIndex,
                onDestinationSelected: onDestinationSelected,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CompactShell extends StatelessWidget {
  const _CompactShell({
    required this.database,
    required this.destination,
    required this.destinations,
    required this.selectedIndex,
    required this.onDestinationSelected,
  });

  final AppDatabase database;
  final _AppDestination destination;
  final List<_AppDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const _Brand()),
      body: SafeArea(
        top: false,
        bottom: false,
        child: _DestinationContent(
          database: database,
          destination: destination,
          selectedIndex: selectedIndex,
          onDestinationSelected: onDestinationSelected,
          compact: true,
        ),
      ),
      bottomNavigationBar: _BottomNavigation(
        destinations: destinations,
        selectedIndex: selectedIndex,
        onDestinationSelected: onDestinationSelected,
      ),
    );
  }
}

class _Brand extends StatelessWidget {
  const _Brand();

  @override
  Widget build(BuildContext context) {
    return const Text(
      'Tagihan Vendra',
      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
    );
  }
}

class _TopNavigationItem extends StatelessWidget {
  const _TopNavigationItem({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: Semantics(
        button: true,
        selected: selected,
        child: Material(
          color: selected ? colorScheme.primaryContainer : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Text(
                label,
                style: TextStyle(
                  color: selected
                      ? colorScheme.onPrimaryContainer
                      : colorScheme.onSurfaceVariant,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BottomNavigation extends StatelessWidget {
  const _BottomNavigation({
    required this.destinations,
    required this.selectedIndex,
    required this.onDestinationSelected,
  });

  final List<_AppDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Material(
      key: const ValueKey('compact-navigation'),
      color: colorScheme.surface,
      child: SafeArea(
        top: false,
        child: Container(
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: colorScheme.outlineVariant)),
          ),
          child: Row(
            children: [
              for (var index = 0; index < destinations.length; index++)
                Expanded(
                  child: _BottomNavigationItem(
                    key: ValueKey('compact-destination-$index'),
                    label: destinations[index].label,
                    selected: selectedIndex == index,
                    onTap: () => onDestinationSelected(index),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BottomNavigationItem extends StatelessWidget {
  const _BottomNavigationItem({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Semantics(
      button: true,
      selected: selected,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(4, 12, 4, 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                width: selected ? 28 : 0,
                height: 3,
                decoration: BoxDecoration(
                  color: colorScheme.primary,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 8),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  maxLines: 1,
                  style: TextStyle(
                    color: selected
                        ? colorScheme.onSurface
                        : colorScheme.onSurfaceVariant,
                    fontSize: 12,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DestinationContent extends StatelessWidget {
  const _DestinationContent({
    required this.database,
    required this.destination,
    required this.selectedIndex,
    required this.onDestinationSelected,
    this.compact = false,
  });

  final AppDatabase database;
  final _AppDestination destination;
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (selectedIndex == 0) {
      return OverviewPage(
        database: database,
        compact: compact,
        onOpenBills: () => onDestinationSelected(1),
        onOpenPayments: () => onDestinationSelected(2),
      );
    }
    if (selectedIndex == 1) {
      return BillListPage(database: database, compact: compact);
    }
    if (selectedIndex == 2) {
      return PaymentHistoryPage(database: database, compact: compact);
    }

    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: EdgeInsets.all(compact ? 24 : 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(destination.label, style: textTheme.headlineMedium),
          const SizedBox(height: 8),
          Text(destination.description, style: textTheme.bodyLarge),
          const Expanded(
            child: Center(
              child: Text('Konten akan ditambahkan pada tahap berikutnya.'),
            ),
          ),
        ],
      ),
    );
  }
}

class _AppDestination {
  const _AppDestination({required this.label, required this.description});

  final String label;
  final String description;
}
