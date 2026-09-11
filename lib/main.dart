import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:npo_community/core/config/app_config.dart';
import 'package:npo_community/core/services/auth_service.dart';
import 'package:npo_community/core/services/community_service.dart';
import 'package:npo_community/core/services/home_alert_service.dart';
import 'package:npo_community/core/services/touring_service.dart';
import 'package:npo_community/features/meadow/services/meadow_alert_service.dart';
import 'package:npo_community/features/onboarding_tour/controllers/onboarding_tour_controller.dart';
import 'package:npo_community/features/supporter_hub/supporter_hub_controller.dart';
import 'package:npo_community/features/supporter_hub/supporter_hub_screen.dart';
import 'package:npo_community/navigation/app_router.dart';
import 'package:npo_community/core/services/shared_preferences_service.dart';
import 'package:npo_community/theme/app_theme.dart';
import 'package:npo_community/widgets/dev/dev_menu.dart';
import 'package:npo_community/widgets/dev/touring_overlay.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SharedPreferencesService().init();
  runApp(NpoCommunityApp(config: AppConfig.current));
}

class NpoCommunityApp extends StatelessWidget {
  const NpoCommunityApp({required this.config, super.key});

  final AppConfig config;

  @override
  Widget build(BuildContext context) {
    if (config.environment == AppEnvironment.demo) {
      return ChangeNotifierProvider(
        create: (_) => SupporterHubController.demo(),
        child: MaterialApp(
          title: 'NPO Community',
          debugShowCheckedModeBanner: kDebugMode,
          theme: AppTheme.lightTheme,
          home: const SupporterHubScreen(),
        ),
      );
    }

    return _FullApp(config: config);
  }
}

class _FullApp extends StatefulWidget {
  const _FullApp({required this.config});

  final AppConfig config;

  @override
  State<_FullApp> createState() => _FullAppState();
}

class _FullAppState extends State<_FullApp> {
  final _authService = AuthService();
  final _touringService = TouringService();
  late final _router = AppRouter(authService: _authService).router;

  @override
  void initState() {
    super.initState();
    unawaited(_authService.init());
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: _authService),
        ChangeNotifierProvider.value(value: _touringService),
        ChangeNotifierProvider(create: (_) => HomeAlertService()),
        ChangeNotifierProvider(create: (_) => MeadowAlertService()),
        ChangeNotifierProvider(create: (_) => OnboardingTourController()),
        Provider(create: (_) => CommunityService()),
      ],
      child: MaterialApp.router(
        title: 'NPO Community',
        debugShowCheckedModeBanner: kDebugMode,
        theme: AppTheme.lightTheme,
        routerConfig: _router,
        builder: (context, child) {
          return DevMenu(
            child: TouringOverlay(child: child),
          );
        },
      ),
    );
  }
}
