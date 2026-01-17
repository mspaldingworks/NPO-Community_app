import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:transconnect/core/services/auth_service.dart';
import 'package:transconnect/core/services/community_service.dart';
import 'package:transconnect/core/services/mock_community_service.dart';
import 'package:transconnect/core/services/shared_preferences_service.dart';
import 'package:transconnect/features/geocaching/repositories/geocache_repository.dart';
import 'package:transconnect/features/geocaching/repositories/local_geocache_repository.dart';
import 'package:transconnect/features/meadow/services/meadow_alert_service.dart';
import 'package:transconnect/features/meadow/widgets/meadow_toast_host.dart';
import 'package:transconnect/features/onboarding_tour/controllers/onboarding_tour_controller.dart';
import 'package:transconnect/features/onboarding_tour/widgets/onboarding_tour_host.dart';
import 'package:transconnect/core/services/home_alert_service.dart';
import 'package:transconnect/navigation/app_router.dart';
import 'package:transconnect/theme/app_theme.dart';
import 'package:transconnect/widgets/dev/dev_menu.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SharedPreferencesService().init();
  final sharedPreferences = await SharedPreferences.getInstance();
  final authService = AuthService();
  await authService.init();
  runApp(MyApp(sharedPreferences: sharedPreferences));
}

class MyApp extends StatefulWidget {
  final SharedPreferences sharedPreferences;
  const MyApp({super.key, required this.sharedPreferences});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final GlobalKey<ScaffoldMessengerState> _scaffoldMessengerKey =
      GlobalKey<ScaffoldMessengerState>();

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<SharedPreferences>.value(value: widget.sharedPreferences),
        ChangeNotifierProvider<AuthService>(
          create: (context) => AuthService(),
        ),
        ChangeNotifierProvider<OnboardingTourController>(
          create: (context) => OnboardingTourController(),
        ),
        ChangeNotifierProvider<MeadowAlertService>(
          create: (context) => MeadowAlertService(),
        ),
        ChangeNotifierProxyProvider<MeadowAlertService, HomeAlertService>(
          create: (context) => HomeAlertService(),
          update: (context, meadowAlerts, homeAlerts) {
            final service = homeAlerts ?? HomeAlertService();
            service.setMeadowAlerts(meadowAlerts.hasUnread);
            return service;
          },
        ),
        Provider<CommunityService>(
          create: (context) => kDebugMode ? MockCommunityService() : CommunityService(),
        ),
        Provider<GeocacheRepository>(
          create: (context) => LocalGeocacheRepository(),
          dispose: (context, repo) {
            if (repo is LocalGeocacheRepository) {
              repo.dispose();
            }
          },
        ),
      ],
      child: Builder(
        builder: (context) {
          final authService = Provider.of<AuthService>(context, listen: false);
          final appRouter = AppRouter(authService: authService);

          final app = MaterialApp.router(
            title: 'TransConnect',
            theme: AppTheme.lightTheme,
            routerConfig: appRouter.router,
            scaffoldMessengerKey: _scaffoldMessengerKey,
            builder: (context, child) {
              final safeChild = child ?? const SizedBox.shrink();
              final maybeDev = kDebugMode ? DevMenu(child: safeChild) : safeChild;
              return MeadowToastHost(
                scaffoldMessengerKey: _scaffoldMessengerKey,
                child: OnboardingTourHost(child: maybeDev),
              );
            },
          );

          return app;
        },
      ),
    );
  }
}
