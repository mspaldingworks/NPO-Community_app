import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:npo_community/core/services/auth_service.dart';
import 'package:npo_community/core/services/view_mode_service.dart';
import 'package:npo_community/features/events/check_in_screens.dart';
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
            Consumer<AuthService>(
              builder: (context, auth, _) => ListTile(
                key: const Key('my-check-in-code-tile'),
                title: const Text('My check-in code'),
                subtitle: const Text(
                  'Show it at events to be checked in (counts toward awards)',
                ),
                leading: const Icon(Icons.qr_code_2),
                trailing: const Icon(Icons.chevron_right),
                minVerticalPadding: 16,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => MyCheckInCodeScreen(
                      name: auth.realUser?.fullName?.trim().isNotEmpty == true
                          ? auth.realUser!.fullName!.trim()
                          : auth.realUser?.username,
                    ),
                  ),
                ),
              ),
            ),
            // Board view switch — only shown to accounts that may use it, so
            // it is invisible rather than merely disabled for everyone else.
            Consumer<ViewModeService>(
              builder: (context, viewMode, _) {
                if (!viewMode.canUseBoardView) {
                  return const SizedBox.shrink();
                }
                final inBoardView = viewMode.isBoardView;
                return Semantics(
                  button: true,
                  label: inBoardView
                      ? 'Switch to member view'
                      : 'Switch to board view',
                  hint: 'Changes which version of the app you are using',
                  child: ListTile(
                    title: Text(inBoardView ? 'Member view' : 'Board view'),
                    subtitle: Text(
                      inBoardView
                          ? 'Go back to the app as an alum sees it'
                          : 'Board roster, seats and committees',
                    ),
                    leading: Icon(
                      inBoardView
                          ? Icons.people_outline
                          : Icons.account_balance_outlined,
                    ),
                    trailing: const Icon(Icons.swap_horiz),
                    minVerticalPadding: 16,
                    onTap: () async {
                      await viewMode.toggle();
                      if (!context.mounted) return;
                      if (viewMode.isBoardView) {
                        context.push('/board');
                      }
                    },
                  ),
                );
              },
            ),
            Consumer<AuthService>(
              builder: (context, auth, _) {
                if (!auth.canAdmin) return const SizedBox.shrink();
                return ListTile(
                  key: const Key('admin-console-tile'),
                  title: const Text('Control console'),
                  subtitle: const Text(
                    'Members, fundraising, events, volunteers, integrations',
                  ),
                  leading: const Icon(Icons.admin_panel_settings_outlined),
                  trailing: const Icon(Icons.chevron_right),
                  minVerticalPadding: 16,
                  onTap: () => context.push('/admin/console'),
                );
              },
            ),
            Consumer<AuthService>(
              builder: (context, auth, _) {
                if (!auth.canTrackGraduation) return const SizedBox.shrink();
                return ListTile(
                  key: const Key('graduation-tile'),
                  title: const Text('Graduation tracker'),
                  subtitle: const Text(
                    'Each class member\'s fundraising, sessions and volunteer '
                    'hours',
                  ),
                  leading: const Icon(Icons.school_outlined),
                  trailing: const Icon(Icons.chevron_right),
                  minVerticalPadding: 16,
                  onTap: () => context.push('/admin/graduation'),
                );
              },
            ),
            Consumer<AuthService>(
              builder: (context, auth, _) {
                if (!auth.canModerate) return const SizedBox.shrink();
                final waiting = auth.openReports;
                return ListTile(
                  key: const Key('moderation-tile'),
                  title: const Text('Moderation'),
                  subtitle: Text(
                    waiting > 0
                        ? '$waiting ${waiting == 1 ? 'report' : 'reports'} '
                              'waiting · member actions and the audit log'
                        : 'Reports, member actions and the audit log',
                  ),
                  leading: Badge(
                    isLabelVisible: waiting > 0,
                    label: Text('$waiting'),
                    child: const Icon(Icons.shield_outlined),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  minVerticalPadding: 16,
                  onTap: () => context.push('/admin/moderation'),
                );
              },
            ),
            ListTile(
              title: const Text('Blocked members'),
              subtitle: const Text('Members you have blocked; unblock here'),
              leading: const Icon(Icons.block),
              trailing: const Icon(Icons.chevron_right),
              minVerticalPadding: 16,
              onTap: () => context.push('/profile/blocked'),
            ),
            ListTile(
              title: const Text('Open-source licenses'),
              subtitle: const Text('Fonts and software this app is built on'),
              leading: const Icon(Icons.description_outlined),
              trailing: const Icon(Icons.chevron_right),
              minVerticalPadding: 16,
              onTap: () => showLicensePage(
                context: context,
                applicationName: 'Emerge Kentucky Alumni',
              ),
            ),
            Semantics(
              button: true,
              label: 'Log out',
              hint: 'Signs you out of your Emerge Kentucky Alumni account',
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
