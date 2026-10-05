import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
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
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
        // Order must match the StatefulShellRoute branches in app_router.
        // Home (the Emerge mark) sits in the middle; Events is reached from
        // Home rather than from a tab.
        destinations: const [
          const NavigationDestination(
            label: 'Community',
            icon: TourAnchor(name: 'Community', child: Icon(Icons.group)),
          ),
          const NavigationDestination(
            label: 'Home',
            icon: TourAnchor(name: 'Home', child: _NavLogoMark()),
            selectedIcon: TourAnchor(name: 'Home', child: _NavLogoMark()),
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

class _NavLogoMark extends StatelessWidget {
  const _NavLogoMark();

  static const String _assetPath = 'assets/branding/emerge_ky_logo.png';

  /// The Emerge Kentucky wordmark is wide (600×215), so it gets the width of
  /// the tab's indicator pill rather than an icon's square: readable, and it
  /// still sits inside the pill when selected.
  static const double _width = 64;
  static const double _height = 26;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: _width,
      height: _height,
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
