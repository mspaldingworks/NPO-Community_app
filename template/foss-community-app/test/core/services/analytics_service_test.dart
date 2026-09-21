import 'package:flutter_test/flutter_test.dart';
import 'package:foss_community/core/config/app_config.dart';
import 'package:foss_community/core/config/public_config.dart';
import 'package:foss_community/core/services/analytics_service.dart';

void main() {
  test('no-op analytics accepts events', () async {
    const service = NoopAnalyticsService();
    await service.trackEvent('opened_app', data: {'source': 'test'});
  });

  test('matomo analytics short-circuits when not opted in', () async {
    final service = MatomoAnalyticsService(
      config: AppConfig.fromValues(
        environment: 'local',
        apiOrigin: 'http://localhost:8000',
      ),
      publicConfig: PublicConfig.defaults(),
      userOptIn: false,
    );

    await service.trackEvent('ignored_event');
  });
}
