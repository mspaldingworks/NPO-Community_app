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
        destinations: const [
          NavigationDestination(
            label: 'Community',
            icon: TourAnchor(
              name: 'Community',
              child: Icon(Icons.group),
            ),
          ),
          NavigationDestination(
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
              child: Icon(Icons.home),
            ),
          ),
          NavigationDestination(
            label: 'Resources',
            icon: TourAnchor(
              name: 'Resources',
              child: Icon(Icons.book),
            ),
          ),
          NavigationDestination(
            label: 'Events',
            icon: TourAnchor(
              name: 'Events',
              child: Icon(Icons.calendar_month_outlined),
            ),
          ),
        ],
        onDestinationSelected: _goBranch,
      ),
    );
  }
}
