import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:npo_community/core/services/auth_service.dart';
import 'package:npo_community/core/services/touring_service.dart';

class TouringOverlay extends StatelessWidget {
  final Widget? child;

  const TouringOverlay({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final touring = context.watch<TouringService>();
    if (!touring.isActive) return child ?? const SizedBox.shrink();

    return Stack(
      children: [
        child ?? const SizedBox.shrink(),
        Positioned(
          bottom: 72,
          left: 12,
          right: 12,
          child: _TouringPill(service: touring),
        ),
      ],
    );
  }
}

class _TouringPill extends StatelessWidget {
  final TouringService service;

  const _TouringPill({required this.service});

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthService>();
    final profile = service.activeProfile!;
    final isAdminType = profile.user.isStaff;

    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xE8121212),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: isAdminType
                ? Colors.deepOrangeAccent.withValues(alpha: 0.8)
                : Colors.tealAccent.withValues(alpha: 0.6),
            width: 1.2,
          ),
          boxShadow: const [
            BoxShadow(
              color: Colors.black54,
              blurRadius: 10,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            // Touring badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'TOURING',
                style: TextStyle(
                  color: Colors.amber,
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Prev arrow
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => service.cyclePrev(auth.switchTouringUser),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4),
                child: Icon(
                  Icons.chevron_left,
                  color: Colors.white70,
                  size: 20,
                ),
              ),
            ),
            // Profile label
            Expanded(
              child: GestureDetector(
                onTap: () => _showProfilePicker(context, auth),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      profile.label,
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      profile.roleTag +
                          (profile.user.isStaff ? ' · admin' : ''),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: isAdminType
                            ? Colors.deepOrangeAccent
                            : Colors.tealAccent,
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Next arrow
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => service.cycleNext(auth.switchTouringUser),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4),
                child: Icon(
                  Icons.chevron_right,
                  color: Colors.white70,
                  size: 20,
                ),
              ),
            ),
            const SizedBox(width: 4),
            // Close / deactivate
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => service.deactivate(auth.signOut),
              child: const Padding(
                padding: EdgeInsets.all(4),
                child: Icon(Icons.close, color: Colors.white38, size: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showProfilePicker(BuildContext context, AuthService auth) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) {
        return _ProfilePickerSheet(service: service, auth: auth);
      },
    );
  }
}

class _ProfilePickerSheet extends StatelessWidget {
  final TouringService service;
  final AuthService auth;

  const _ProfilePickerSheet({required this.service, required this.auth});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 16),
        const Text(
          'Switch Profile',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        ...TouringService.profiles.asMap().entries.map((entry) {
          final i = entry.key;
          final profile = entry.value;
          final isActive = service.activeIndex == i;
          return ListTile(
            onTap: () {
              service.activateProfile(i, auth.switchTouringUser);
              Navigator.of(context).pop();
            },
            leading: CircleAvatar(
              backgroundColor: profile.user.isStaff
                  ? Colors.deepOrange.shade900
                  : Colors.teal.shade900,
              child: Text(
                profile.label[0],
                style: const TextStyle(color: Colors.white, fontSize: 14),
              ),
            ),
            title: Text(
              profile.label,
              style: TextStyle(
                color: Colors.white,
                fontWeight:
                    isActive ? FontWeight.w700 : FontWeight.w400,
              ),
            ),
            subtitle: Text(
              profile.roleTag +
                  (profile.user.isStaff ? ' · has admin access' : ''),
              style: TextStyle(
                color: profile.user.isStaff
                    ? Colors.deepOrangeAccent
                    : Colors.teal.shade300,
                fontSize: 12,
              ),
            ),
            trailing: isActive
                ? const Icon(Icons.check_circle, color: Colors.amber)
                : null,
          );
        }),
        const SizedBox(height: 16),
        TextButton.icon(
          onPressed: () {
            service.deactivate(auth.signOut);
            Navigator.of(context).pop();
          },
          icon: const Icon(Icons.exit_to_app, color: Colors.white54),
          label: const Text(
            'Exit Touring Mode',
            style: TextStyle(color: Colors.white54),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}
