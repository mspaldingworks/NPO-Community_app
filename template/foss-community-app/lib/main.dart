import 'package:adaptive_theme/adaptive_theme.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

import 'core/config/app_config.dart';
import 'core/config/public_config.dart';
import 'core/services/analytics_service.dart';
import 'core/services/error_reporting.dart';
import 'core/services/push_notifications.dart';
import 'data/repositories/public_config_repository.dart';
import 'navigation/app_router.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final config = AppConfig.fromEnvironment();

  await initializeErrorReporting(config, () async {
    final httpClient = http.Client();
    final publicConfig = await PublicConfigRepository(
      config: config,
      httpClient: httpClient,
    ).fetch();

    runApp(
      MultiProvider(
        providers: [
          Provider<AppConfig>.value(value: config),
          Provider<PublicConfig>.value(value: publicConfig),
          Provider<AnalyticsService>.value(
            value: MatomoAnalyticsService(
              config: config,
              publicConfig: publicConfig,
              httpClient: httpClient,
              userOptIn: false,
            ),
          ),
          Provider<PushNotificationService>.value(
            value: const DisabledPushNotificationService(),
          ),
        ],
        child: const FossCommunityApp(),
      ),
    );
  });
}

class FossCommunityApp extends StatelessWidget {
  const FossCommunityApp({super.key});

  @override
  Widget build(BuildContext context) {
    final router = AppRouter.create();
    return AdaptiveTheme(
      light: AppTheme.light(),
      dark: AppTheme.dark(),
      initial: AdaptiveThemeMode.light,
      builder: (theme, darkTheme) => MaterialApp.router(
        title: 'FOSS Community',
        theme: theme,
        darkTheme: darkTheme,
        routerConfig: router,
      ),
    );
  }
}
