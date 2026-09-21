import 'package:adaptive_theme/adaptive_theme.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:scoped_model/scoped_model.dart';

import 'core/config/app_config.dart';
import 'core/config/public_config.dart';
import 'core/services/analytics_service.dart';
import 'core/services/capability_service.dart';
import 'core/services/error_reporting.dart';
import 'core/services/push_notifications.dart';
import 'core/state/template_state_model.dart';
import 'data/repositories/public_config_repository.dart';
import 'navigation/app_router.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final config = AppConfig.fromEnvironment();

  await initializeErrorReporting(config, () async {
    final sharedPreferences = await SharedPreferences.getInstance();
    final analyticsOptIn =
        sharedPreferences.getBool('analytics_opt_in') ?? false;
    final savedThemeMode = await AdaptiveTheme.getThemeMode();
    final PublicConfigSource publicConfigSource = config.networkEnabled
        ? HttpPublicConfigSource(config: config)
        : const DemoPublicConfigSource();
    final publicConfig = await publicConfigSource.fetch();
    final capabilityService = CapabilityService.empty();
    final analyticsService =
        analyticsOptIn && publicConfig.matomoConfigured && config.networkEnabled
        ? MatomoAnalyticsService(
            config: config,
            publicConfig: publicConfig,
            userOptIn: true,
          )
        : const NoopAnalyticsService();

    runApp(
      MultiProvider(
        providers: [
          Provider<AppConfig>.value(value: config),
          Provider<PublicConfig>.value(value: publicConfig),
          Provider<CapabilityService>.value(value: capabilityService),
          Provider<AnalyticsService>.value(value: analyticsService),
          Provider<PushNotificationService>.value(
            value: const DisabledPushNotificationService(),
          ),
        ],
        child: FossCommunityApp(
          initialThemeMode: savedThemeMode ?? AdaptiveThemeMode.light,
        ),
      ),
    );
  });
}

class FossCommunityApp extends StatelessWidget {
  const FossCommunityApp({super.key, required this.initialThemeMode});

  static final TemplateStateModel _stateModel = TemplateStateModel();
  final AdaptiveThemeMode initialThemeMode;

  @override
  Widget build(BuildContext context) {
    final capabilityService = context.read<CapabilityService>();
    final router = AppRouter.create(capabilityService: capabilityService);
    return AdaptiveTheme(
      light: AppTheme.light(),
      dark: AppTheme.dark(),
      initial: initialThemeMode,
      builder: (theme, darkTheme) => ScopedModel<TemplateStateModel>(
        model: _stateModel,
        child: MaterialApp.router(
          title: 'FOSS Community',
          theme: theme,
          darkTheme: darkTheme,
          routerConfig: router,
        ),
      ),
    );
  }
}
