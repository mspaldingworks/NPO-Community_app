import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class ScaffoldWithNavBar extends StatelessWidget {
  const ScaffoldWithNavBar({
    required this.navigationShell,
    super.key,
  });

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    int _selectedIndex = navigationShell.currentIndex;

    void _onItemTapped(int index, BuildContext context) {
      switch (index) {
        case 0:
          navigationShell.goBranch(
            index,
            initialLocation: index == navigationShell.currentIndex,
          );
          break;
        case 1:
          navigationShell.goBranch(
            index,
            initialLocation: index == navigationShell.currentIndex,
          );
          break;
        case 2:
          navigationShell.goBranch(
            index,
            initialLocation: index == navigationShell.currentIndex,
          );
          break;
        case 3:
          navigationShell.goBranch(
            index,
            initialLocation: index == navigationShell.currentIndex,
          );
          break;
      }
    }

    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.white,
        selectedItemColor: Colors.blue,
        unselectedItemColor: Colors.grey,
        currentIndex: _selectedIndex,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.group),
            label: 'Community',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.chat_bubble_outline),
            label: 'Chat',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.book),
            label: 'Resources',
          ),
        ],
        onTap: (index) {
          _onItemTapped(index, context);
        },
      ),
    );
  }
}
