import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
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
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        destinations: [
          NavigationDestination(
            label: 'Community',
            icon: TourAnchor(
              name: 'Community',
              child: const Icon(Icons.group),
            ),
          ),
          NavigationDestination(
            label: 'Home',
            icon: TourAnchor(
              name: 'Home',
              child: const Icon(Icons.home),
            ),
          ),
          NavigationDestination(
            label: 'Resources',
            icon: TourAnchor(
              name: 'Resources',
              child: const Icon(Icons.book),
            ),
          ),
        ],
        onDestinationSelected: _goBranch,
      ),
    );
  }
}
