import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:npo_community/core/config/app_config.dart';
import 'package:npo_community/core/services/auth_service.dart';
import 'package:npo_community/core/services/community_service.dart';
import 'package:npo_community/core/services/home_alert_service.dart';
import 'package:npo_community/core/services/touring_service.dart';
import 'package:npo_community/core/services/view_mode_service.dart';
import 'package:go_router/go_router.dart';
import 'package:npo_community/features/alumni_directory/alumni_directory_screen.dart';
import 'package:npo_community/features/alumni_running/campaign_hub_controller.dart';
import 'package:npo_community/features/alumni_running/campaign_hub_routes.dart';
import 'package:npo_community/features/onboarding_tour/controllers/onboarding_tour_controller.dart';
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
      return _DemoApp(config: config);
    }

    return _FullApp(config: config);
  }
}

/// Demo builds: synthetic data only, no authentication, no network.
class _DemoApp extends StatefulWidget {
  const _DemoApp({required this.config});

  final AppConfig config;

  @override
  State<_DemoApp> createState() => _DemoAppState();
}

class _DemoAppState extends State<_DemoApp> {
  late final _router = GoRouter(
    initialLocation: '/directory',
    routes: [
      GoRoute(
        path: '/directory',
        builder: (context, state) {
          final search = state.uri.queryParameters['search'];
          return AlumniDirectoryScreen(
            key: ValueKey('directory:${search ?? ''}'),
            initialSearch: search,
          );
        },
      ),
      campaignHubRoute(),
    ],
  );

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => CampaignHubController(
        repository: createCampaignRepository(widget.config),
      ),
      child: MaterialApp.router(
        title: 'Emerge Kentucky Alumni',
        debugShowCheckedModeBanner: kDebugMode,
        theme: AppTheme.lightTheme,
        routerConfig: _router,
      ),
    );
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
  final _viewModeService = ViewModeService();
  late final _router = AppRouter(authService: _authService).router;

  @override
  void initState() {
    super.initState();
    unawaited(_authService.init().then((_) => _viewModeService.restore()));
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: _authService),
        ChangeNotifierProvider.value(value: _touringService),
        ChangeNotifierProvider.value(value: _viewModeService),
        ChangeNotifierProvider(create: (_) => HomeAlertService()),
        ChangeNotifierProvider(create: (_) => OnboardingTourController()),
        Provider(create: (_) => CommunityService()),
        ChangeNotifierProvider(
          create: (_) => CampaignHubController(
            repository: createCampaignRepository(widget.config),
            isPreviewActive: () => _touringService.isActive,
            previewChanges: _touringService,
            sessionChanges: _authService.authStateChanges,
          ),
        ),
      ],
      child: MaterialApp.router(
        title: 'Emerge Kentucky Alumni',
        debugShowCheckedModeBanner: kDebugMode,
        theme: AppTheme.lightTheme,
        routerConfig: _router,
        builder: (context, child) {
          return DevMenu(child: TouringOverlay(child: child));
        },
      ),
    );
  }
}
