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
}
