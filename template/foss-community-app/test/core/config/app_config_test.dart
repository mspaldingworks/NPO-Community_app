import 'package:flutter_test/flutter_test.dart';
import 'package:foss_community/core/config/app_config.dart';

void main() {
  test('production requires HTTPS origin', () {
    expect(
      () => AppConfig.fromValues(
        environment: 'production',
        apiOrigin: 'http://example.com',
      ),
      throwsArgumentError,
    );
  });

  test('demo mode disables network URIs', () {
    final config = AppConfig.fromValues(
      environment: 'demo',
      apiOrigin: 'https://demo.invalid',
    );

    expect(config.networkEnabled, isFalse);
    expect(() => config.apiUri('/api/health/'), throwsStateError);
  });

  test('rejects API origins with query or fragment', () {
    expect(
      () => AppConfig.fromValues(
        environment: 'local',
        apiOrigin: 'https://example.com?x=1',
      ),
      throwsArgumentError,
    );
    expect(
      () => AppConfig.fromValues(
        environment: 'local',
        apiOrigin: 'https://example.com#frag',
      ),
      throwsArgumentError,
    );
  });

  test('builds API and WebSocket URIs from normalized origin', () {
    final config = AppConfig.fromValues(
      environment: 'local',
      apiOrigin: 'https://example.com/',
    );

    expect(config.apiUri('api/public-config/').toString(), 'https://example.com/api/public-config/');
    expect(config.webSocketUri('/ws/notifications/').toString(), 'wss://example.com/ws/notifications/');
  });
}
