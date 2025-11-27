import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class DevMenu extends StatefulWidget {
  final Widget child;
  
  const DevMenu({
    super.key,
    required this.child,
  });

  @override
  State<DevMenu> createState() => _DevMenuState();
}

class _DevMenuState extends State<DevMenu> {
  int _tapCount = 0;
  DateTime? _lastTap;
  
  void _handleTap() {
    final now = DateTime.now();
    
    if (_lastTap != null && now.difference(_lastTap!) < const Duration(seconds: 2)) {
      _tapCount++;
    } else {
      _tapCount = 1;
    }
    
    _lastTap = now;
    
    // Show dev menu after 5 taps
    if (_tapCount >= 5) {
      _tapCount = 0;
      _showDevMenu();
    }
  }
  
  void _showDevMenu() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Developer Menu'),
        content: const Text('Development tools and test screens'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
        actionsOverflowButtonSpacing: 8,
        actionsOverflowDirection: VerticalDirection.down,
        actionsAlignment: MainAxisAlignment.spaceEvenly,
        buttonPadding: const EdgeInsets.all(16),
        actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _handleTap,
      child: widget.child,
    );
  }
}
