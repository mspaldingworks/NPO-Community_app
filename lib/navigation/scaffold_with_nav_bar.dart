import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:npo_community/core/services/home_alert_service.dart';
import 'package:npo_community/features/onboarding_tour/widgets/tour_anchor.dart';

class ScaffoldWithNavBar extends StatelessWidget {
  const ScaffoldWithNavBar({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  void _goBranch(int index) {
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasHomeAlerts = Provider.of<HomeAlertService>(
      context,
      listen: true,
    ).hasAlerts;
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
        // Order must match the StatefulShellRoute branches in app_router.
        // Home (the Emerge mark) sits in the middle; Events is reached from
        // Home rather than from a tab.
        destinations: [
          const NavigationDestination(
            label: 'Community',
            icon: TourAnchor(name: 'Community', child: Icon(Icons.group)),
          ),
          NavigationDestination(
            label: 'Home',
            icon: TourAnchor(
              name: 'Home',
              child: _NavGlow(glow: hasHomeAlerts, child: const _NavLogoMark()),
            ),
            selectedIcon: TourAnchor(
              name: 'Home',
              child: _NavGlow(glow: hasHomeAlerts, child: const _NavLogoMark()),
            ),
          ),
          const NavigationDestination(
            label: 'Alumni Directory',
            icon: TourAnchor(
              name: 'Alumni Directory',
              child: Icon(Icons.people_outline),
            ),
          ),
        ],
        onDestinationSelected: _goBranch,
      ),
    );
  }
}

class _NavGlow extends StatelessWidget {
  const _NavGlow({required this.child, required this.glow});

  final Widget child;
  final bool glow;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: glow
            ? [
                BoxShadow(
                  color: Colors.redAccent.withAlpha(179),
                  blurRadius: 12,
                  spreadRadius: 2,
                ),
              ]
            : const [],
      ),
      child: child,
    );
  }
}

class _NavLogoMark extends StatelessWidget {
  const _NavLogoMark();

  static const String _assetPath = 'assets/branding/emerge_ky_logo.png';

  @override
  Widget build(BuildContext context) {
    final size = IconTheme.of(context).size ?? 24;
    return SizedBox.square(
      dimension: size,
      child: Image.asset(
        _assetPath,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.high,
        errorBuilder: (context, error, stackTrace) {
          return const Icon(Icons.home);
        },
      ),
    );
  }
}
