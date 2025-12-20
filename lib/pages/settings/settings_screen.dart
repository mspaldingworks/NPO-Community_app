import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:transconnect/core/services/auth_service.dart';
import 'package:transconnect/features/onboarding_tour/widgets/tour_anchor.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  Future<void> _confirmAndSignOut(BuildContext context) async {
    final authService = AuthService();

    final shouldSignOut = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Log out?'),
          content: const Text('You will need to log in again to access your account.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Log out'),
            ),
          ],
        );
      },
    );

    if (shouldSignOut != true) return;
    await authService.signOut();
    if (!context.mounted) return;
    context.go('/splash');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: 8),
          children: [
            Semantics(
              button: true,
              label: 'Log out',
              hint: 'Signs you out of your TransConnect account',
              child: TourAnchor(
                name: 'Log out',
                child: ListTile(
                  title: const Text('Log out'),
                  subtitle: const Text('You will be returned to the welcome screen'),
                  leading: const Icon(Icons.logout),
                  trailing: const Icon(Icons.chevron_right),
                  minVerticalPadding: 16,
                  onTap: () => _confirmAndSignOut(context),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
