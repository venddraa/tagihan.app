import 'package:flutter/material.dart';
import 'package:tagihan_vendra/data/local/app_database.dart';
import 'package:tagihan_vendra/data/sync/sync_coordinator.dart';
import 'package:tagihan_vendra/features/bills/bill_list_page.dart';
import 'package:tagihan_vendra/features/overview/overview_page.dart';
import 'package:tagihan_vendra/features/payments/payment_history_page.dart';
import 'package:tagihan_vendra/features/settings/settings_page.dart';

class AppShell extends StatefulWidget {
  const AppShell({
    super.key,
    required this.database,
    required this.syncCoordinator,
  });

  final AppDatabase database;
  final SyncCoordinator syncCoordinator;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  static const _desktopBreakpoint = 860.0;

  static const _destinations = [
    _AppDestination(label: 'Ringkasan', icon: Icons.dashboard_outlined),
    _AppDestination(label: 'Tagihan', icon: Icons.receipt_long_outlined),
    _AppDestination(label: 'Pembayaran', icon: Icons.payments_outlined),
    _AppDestination(label: 'Pengaturan', icon: Icons.tune_outlined),
  ];

  int _selectedIndex = 0;

  void _selectDestination(int index) {
    setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < _desktopBreakpoint) {
          return _CompactShell(
            database: widget.database,
            syncCoordinator: widget.syncCoordinator,
            destinations: _destinations,
            selectedIndex: _selectedIndex,
            onDestinationSelected: _selectDestination,
          );
        }

        return _DesktopShell(
          database: widget.database,
          syncCoordinator: widget.syncCoordinator,
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
    required this.syncCoordinator,
    required this.destinations,
    required this.selectedIndex,
    required this.onDestinationSelected,
  });

  final AppDatabase database;
  final SyncCoordinator syncCoordinator;
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
              height: 72,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final showLabels = constraints.maxWidth >= 1040;
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    child: Row(
                      children: [
                        const Expanded(
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: _Brand(),
                          ),
                        ),
                        Row(
                          key: const ValueKey('desktop-navigation'),
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            for (
                              var index = 0;
                              index < destinations.length;
                              index++
                            )
                              _TopNavigationItem(
                                key: ValueKey('desktop-destination-$index'),
                                label: destinations[index].label,
                                icon: destinations[index].icon,
                                showLabel: showLabels,
                                selected: selectedIndex == index,
                                onTap: () => onDestinationSelected(index),
                              ),
                          ],
                        ),
                        const Expanded(child: SizedBox()),
                      ],
                    ),
                  );
                },
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: _DestinationContent(
                database: database,
                syncCoordinator: syncCoordinator,
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
    required this.syncCoordinator,
    required this.destinations,
    required this.selectedIndex,
    required this.onDestinationSelected,
  });

  final AppDatabase database;
  final SyncCoordinator syncCoordinator;
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
          syncCoordinator: syncCoordinator,
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
    final colors = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: colors.primaryContainer,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Icon(
            Icons.receipt_long_outlined,
            size: 18,
            color: colors.onPrimaryContainer,
          ),
        ),
        const SizedBox(width: 10),
        const Flexible(
          child: Text(
            'Tagihan Vendra',
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.2,
            ),
          ),
        ),
      ],
    );
  }
}

class _TopNavigationItem extends StatelessWidget {
  const _TopNavigationItem({
    super.key,
    required this.label,
    required this.icon,
    required this.showLabel,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool showLabel;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Semantics(
        label: label,
        button: true,
        selected: selected,
        excludeSemantics: true,
        child: Tooltip(
          message: label,
          child: Material(
            color: selected
                ? colorScheme.surfaceContainerHigh
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 13,
                  vertical: 9,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      icon,
                      size: 18,
                      color: selected
                          ? colorScheme.primary
                          : colorScheme.onSurfaceVariant,
                    ),
                    if (showLabel) ...[
                      const SizedBox(width: 7),
                      Text(
                        label,
                        style: TextStyle(
                          color: selected
                              ? colorScheme.onSurface
                              : colorScheme.onSurfaceVariant,
                          fontWeight: selected
                              ? FontWeight.w600
                              : FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
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
                    icon: destinations[index].icon,
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
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
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
                width: selected ? 30 : 0,
                height: 3,
                decoration: BoxDecoration(
                  color: colorScheme.primary,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 7),
              Icon(
                icon,
                size: 21,
                color: selected
                    ? colorScheme.primary
                    : colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: 4),
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
    required this.syncCoordinator,
    required this.selectedIndex,
    required this.onDestinationSelected,
    this.compact = false,
  });

  final AppDatabase database;
  final SyncCoordinator syncCoordinator;
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
    return SettingsPage(
      database: database,
      syncCoordinator: syncCoordinator,
      compact: compact,
    );
  }
}

class _AppDestination {
  const _AppDestination({required this.label, required this.icon});

  final String label;
  final IconData icon;
}
