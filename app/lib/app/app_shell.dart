import 'package:flutter/material.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  static const _desktopBreakpoint = 720.0;

  static const _destinations = [
    _AppDestination(
      label: 'Ringkasan',
      icon: Icons.dashboard_outlined,
      selectedIcon: Icons.dashboard,
      description: 'Pantau tagihan yang perlu diperhatikan.',
    ),
    _AppDestination(
      label: 'Tagihan',
      icon: Icons.receipt_long_outlined,
      selectedIcon: Icons.receipt_long,
      description: 'Kelola tagihan dan subscription pribadi.',
    ),
    _AppDestination(
      label: 'Pembayaran',
      icon: Icons.payments_outlined,
      selectedIcon: Icons.payments,
      description: 'Lihat dan catat riwayat pembayaran.',
    ),
    _AppDestination(
      label: 'Pengaturan',
      icon: Icons.settings_outlined,
      selectedIcon: Icons.settings,
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
          return _MobileShell(
            destination: destination,
            destinations: _destinations,
            selectedIndex: _selectedIndex,
            onDestinationSelected: _selectDestination,
          );
        }

        return _DesktopShell(
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
    required this.destination,
    required this.destinations,
    required this.selectedIndex,
    required this.onDestinationSelected,
  });

  final _AppDestination destination;
  final List<_AppDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Row(
          children: [
            NavigationRail(
              extended: true,
              minExtendedWidth: 224,
              groupAlignment: -1,
              leading: const Padding(
                padding: EdgeInsets.fromLTRB(20, 20, 20, 28),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Tagihan Vendra',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              selectedIndex: selectedIndex,
              onDestinationSelected: onDestinationSelected,
              destinations: [
                for (final destination in destinations)
                  NavigationRailDestination(
                    icon: Icon(destination.icon),
                    selectedIcon: Icon(destination.selectedIcon),
                    label: Text(destination.label),
                  ),
              ],
            ),
            const VerticalDivider(width: 1),
            Expanded(child: _DestinationContent(destination: destination)),
          ],
        ),
      ),
    );
  }
}

class _MobileShell extends StatelessWidget {
  const _MobileShell({
    required this.destination,
    required this.destinations,
    required this.selectedIndex,
    required this.onDestinationSelected,
  });

  final _AppDestination destination;
  final List<_AppDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tagihan Vendra')),
      body: _DestinationContent(destination: destination),
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedIndex,
        onDestinationSelected: onDestinationSelected,
        destinations: [
          for (final destination in destinations)
            NavigationDestination(
              icon: Icon(destination.icon),
              selectedIcon: Icon(destination.selectedIcon),
              label: destination.label,
            ),
        ],
      ),
    );
  }
}

class _DestinationContent extends StatelessWidget {
  const _DestinationContent({required this.destination});

  final _AppDestination destination;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.all(32),
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
  const _AppDestination({
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.description,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final String description;
}
