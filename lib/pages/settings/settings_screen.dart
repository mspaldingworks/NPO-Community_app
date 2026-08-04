import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:npo_community/core/services/auth_service.dart';
import 'package:npo_community/features/onboarding_tour/controllers/onboarding_tour_controller.dart';
import 'package:npo_community/features/onboarding_tour/services/onboarding_tour_storage.dart';
import 'package:npo_community/features/onboarding_tour/widgets/tour_anchor.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  Future<void> _startTourFromSettings(BuildContext context) async {
    final username = context.read<AuthService>().currentUser?.username;
    if (username == null || username.trim().isEmpty) {
      return;
    }

    final controller = context.read<OnboardingTourController>();
    await controller.load();
    if (controller.totalSteps == 0) return;

    await OnboardingTourStorage.clearPendingStart(username);
    if (!context.mounted) return;
    context.go('/home');

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await controller.startForUser(username);
    });
  }

  Future<void> _confirmAndSignOut(BuildContext context) async {
    final authService = AuthService();

    final shouldSignOut = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Log out?'),
          content: const Text(
            'You will need to log in again to access your account.',
          ),
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
      appBar: AppBar(title: const Text('Settings')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: 8),
          children: [
            Semantics(
              button: true,
              label: 'Info and tour',
              hint: 'Learn about the app and replay the home dashboard tour',
              child: ListTile(
                title: const Text('Info & tour'),
                subtitle: const Text(
                  'Read the overview and replay the guided tour',
                ),
                leading: const Icon(Icons.info_outline),
                trailing: const Icon(Icons.chevron_right),
                minVerticalPadding: 16,
                onTap: () async {
                  final shouldStart = await context.push<bool>('/profile/info');
                  if (shouldStart == true && context.mounted) {
                    await _startTourFromSettings(context);
                  }
                },
              ),
            ),
            Semantics(
              button: true,
              label: 'Log out',
              hint: 'Signs you out of your NPO Community account',
              child: TourAnchor(
                name: 'Log out',
                child: ListTile(
                  title: const Text('Log out'),
                  subtitle: const Text(
                    'You will be returned to the welcome screen',
                  ),
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
