import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:npo_community/core/services/auth_service.dart';
import 'package:npo_community/features/onboarding_tour/controllers/onboarding_tour_controller.dart';
import 'package:npo_community/features/onboarding_tour/services/onboarding_tour_storage.dart';
import 'package:npo_community/features/onboarding_tour/widgets/onboarding_tour_overlay.dart';

class OnboardingTourHost extends StatefulWidget {
  final Widget child;

  const OnboardingTourHost({super.key, required this.child});

  @override
  State<OnboardingTourHost> createState() => _OnboardingTourHostState();
}

class _OnboardingTourHostState extends State<OnboardingTourHost> {
  String? _lastUsername;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
  }

  Future<void> _tryAutoStart() async {
    if (!mounted) return;

    final auth = context.read<AuthService>();
    final username = auth.currentUser?.username;
    if (username == null || username.trim().isEmpty) return;

    final pending = await OnboardingTourStorage.isPendingStart(username);
    if (!pending) return;

    final seen = await OnboardingTourStorage.hasSeen(username);
    if (seen) return;

    if (!mounted) return;
    final controller = context.read<OnboardingTourController>();
    await controller.load();
    if (controller.totalSteps == 0) return;

    final hasSeenInfo = await OnboardingTourStorage.hasSeenInfo(username);
    if (!hasSeenInfo) {
      await OnboardingTourStorage.markInfoSeen(username);
      await OnboardingTourStorage.clearPendingStart(username);
      if (!mounted) return;

      final shouldStart = await context.push<bool>('/profile/info');
      if (!mounted) return;
      if (shouldStart == true) {
        context.go('/home');
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          await controller.startForUser(username);
        });
      }
      return;
    }

    await OnboardingTourStorage.clearPendingStart(username);
    if (!mounted) return;
    context.go('/home');
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await controller.startForUser(username);
    });
  }

  @override
  Widget build(BuildContext context) {
    final username = context.select<AuthService, String?>(
      (a) => a.currentUser?.username,
    );
    if (username != _lastUsername) {
      _lastUsername = username;
      WidgetsBinding.instance.addPostFrameCallback((_) => _tryAutoStart());
    }

    final controller = context.watch<OnboardingTourController>();

    return Stack(
      children: [
        widget.child,
        if (controller.active) OnboardingTourOverlay(controller: controller),
      ],
    );
  }
}
