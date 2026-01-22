import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:transconnect/core/services/home_alert_service.dart';
import 'package:transconnect/features/onboarding_tour/widgets/tour_anchor.dart';

class ScaffoldWithNavBar extends StatelessWidget {
  const ScaffoldWithNavBar({
    required this.navigationShell,
    super.key,
  });

  final StatefulNavigationShell navigationShell;

  void _goBranch(int index) {
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasHomeAlerts =
        Provider.of<HomeAlertService>(context, listen: true).hasAlerts;
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
        destinations: [
          const NavigationDestination(
            label: 'Community',
            icon: TourAnchor(
              name: 'Community',
              child: Icon(Icons.group),
            ),
          ),
          const NavigationDestination(
            label: 'Exchange',
            icon: TourAnchor(
              name: 'Exchange',
              child: Icon(Icons.swap_horiz_outlined),
            ),
          ),
          NavigationDestination(
            label: 'Home',
            icon: TourAnchor(
              name: 'Home',
              child: _NavGlowIcon(
                icon: Icons.home,
                glow: hasHomeAlerts,
              ),
            ),
            selectedIcon: TourAnchor(
              name: 'Home',
              child: _NavGlowIcon(
                icon: Icons.home,
                glow: hasHomeAlerts,
              ),
            ),
          ),
          const NavigationDestination(
            label: 'Resources',
            icon: TourAnchor(
              name: 'Resources',
              child: Icon(Icons.book),
            ),
          ),
          const NavigationDestination(
            label: 'The Meadow',
            icon: TourAnchor(
              name: 'The Meadow',
              child: Icon(Icons.local_florist),
            ),
          ),
        ],
        onDestinationSelected: _goBranch,
      ),
    );
  }
}

class _NavGlowIcon extends StatelessWidget {
  const _NavGlowIcon({required this.icon, required this.glow});

  final IconData icon;
  final bool glow;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: glow
            ? [
                BoxShadow(
                  color: Colors.redAccent.withOpacity(0.7),
                  blurRadius: 12,
                  spreadRadius: 2,
                ),
              ]
            : const [],
      ),
      child: Icon(icon),
    );
  }
}
