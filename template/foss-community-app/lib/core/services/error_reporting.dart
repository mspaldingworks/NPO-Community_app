import 'package:sentry_flutter/sentry_flutter.dart';

import '../config/app_config.dart';

Future<void> initializeErrorReporting(
  AppConfig config,
  Future<void> Function() appRunner,
) async {
  if (!config.sentryEnabled) {
    await appRunner();
    return;
  }

  await SentryFlutter.init(
    (options) {
      options.dsn = config.sentryDsn;
    },
    appRunner: appRunner,
  );
}
