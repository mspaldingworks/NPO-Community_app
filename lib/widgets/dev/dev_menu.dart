import 'package:flutter/material.dart';
import 'package:npo_community/core/services/auth_service.dart';
import 'package:npo_community/core/services/touring_service.dart';
import 'package:provider/provider.dart';

/// Hidden developer menu (five quick taps, staff and superusers only) for
/// touring the app as a sample persona.
class DevMenu extends StatefulWidget {
  final Widget? child;

  const DevMenu({super.key, required this.child});

  @override
  State<DevMenu> createState() => _DevMenuState();
}

class _DevMenuState extends State<DevMenu> {
  int _tapCount = 0;
  DateTime? _lastTap;

  void _handleTap() {
    // The developer menu can switch user types, so the gesture must not exist
    // for ordinary accounts. Judged on the real account rather than
    // currentUser, which touring replaces with a persona.
    if (!AuthService().canTour) {
      _tapCount = 0;
      return;
    }

    final now = DateTime.now();
    if (_lastTap != null &&
        now.difference(_lastTap!) < const Duration(seconds: 2)) {
      _tapCount++;
    } else {
      _tapCount = 1;
    }
    _lastTap = now;

    if (_tapCount >= 5) {
      _tapCount = 0;
      _showDevMenu();
    }
  }

  void _showDevMenu() {
    final touring = Provider.of<TouringService>(context, listen: false);
    final auth = Provider.of<AuthService>(context, listen: false);
    showDialog(
      context: context,
      builder: (dialogContext) => _DevMenuDialog(touring: touring, auth: auth),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: _handleTap,
      onLongPress: _showDevMenu,
      child: widget.child ?? const SizedBox.shrink(),
    );
  }
}

class _DevMenuDialog extends StatelessWidget {
  final TouringService touring;
  final AuthService auth;

  const _DevMenuDialog({required this.touring, required this.auth});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Developer Menu'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Touring Mode',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            ),
            const SizedBox(height: 6),
            if (touring.isActive) ...[
              Text(
                'Active: ${touring.activeProfile?.label ?? "—"}',
                style: const TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: TouringService.profiles.asMap().entries.map((entry) {
                  final i = entry.key;
                  final p = entry.value;
                  final isActive = touring.activeIndex == i;
                  return ActionChip(
                    label: Text(
                      p.label,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: isActive
                            ? FontWeight.w700
                            : FontWeight.w400,
                      ),
                    ),
                    avatar: isActive ? const Icon(Icons.check, size: 14) : null,
                    onPressed: () {
                      touring.activateProfile(i, auth.switchTouringUser);
                      Navigator.pop(context);
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () {
                  // Restore the real account rather than signing out — the
                  // token was never swapped, only the on-screen persona.
                  touring.deactivate(auth.stopTouring);
                  Navigator.pop(context);
                },
                icon: const Icon(Icons.exit_to_app, size: 16),
                label: const Text('Exit Touring Mode'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: const BorderSide(color: Colors.red),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  textStyle: const TextStyle(fontSize: 12),
                ),
              ),
            ] else ...[
              const Text(
                'Pick a profile to start touring:',
                style: TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: TouringService.profiles.asMap().entries.map((entry) {
                  final i = entry.key;
                  final p = entry.value;
                  return ActionChip(
                    label: Text(p.label, style: const TextStyle(fontSize: 11)),
                    avatar: Icon(
                      p.user.isStaff
                          ? Icons.admin_panel_settings
                          : Icons.person,
                      size: 14,
                    ),
                    onPressed: () {
                      touring.activateProfile(i, auth.switchTouringUser);
                      Navigator.pop(context);
                    },
                  );
                }).toList(),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }
}
