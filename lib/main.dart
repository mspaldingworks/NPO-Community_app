import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:npo_community/core/config/app_config.dart';
import 'package:npo_community/core/services/givebutter_service.dart';
import 'package:npo_community/features/fundraising/fundraising_controller.dart';
import 'package:npo_community/features/supporter_hub/supporter_hub_controller.dart';
import 'package:npo_community/features/supporter_hub/supporter_hub_screen.dart';
import 'package:npo_community/theme/app_theme.dart';
import 'package:provider/provider.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(NpoCommunityApp(config: AppConfig.current));
}

class NpoCommunityApp extends StatelessWidget {
  const NpoCommunityApp({required this.config, super.key});

  final AppConfig config;

  @override
  Widget build(BuildContext context) {
    final home = config.environment == AppEnvironment.demo
        ? MultiProvider(
            providers: [
              ChangeNotifierProvider(
                create: (_) => SupporterHubController.demo(),
              ),
              ChangeNotifierProvider(
                create: (_) {
                  final controller = FundraisingController(
                    GivebutterService(AppConfig.givebutterApiKey),
                  );
                  controller.loadCampaigns();
                  return controller;
                },
              ),
            ],
            child: const SupporterHubScreen(),
          )
        : _EnvironmentGate(environment: config.environment);

    return MaterialApp(
      title: 'NPO Community',
      debugShowCheckedModeBanner: kDebugMode,
      theme: AppTheme.lightTheme,
      home: home,
    );
  }
}

class _EnvironmentGate extends StatelessWidget {
  const _EnvironmentGate({required this.environment});

  final AppEnvironment environment;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.shield_outlined, size: 40),
                  const SizedBox(height: 20),
                  Text(
                    'Secure access is not configured',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '${environment.name} mode requires the NPO Community '
                    'stakeholder API and authorization flow.',
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
