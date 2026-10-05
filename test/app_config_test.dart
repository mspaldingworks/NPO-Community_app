import 'package:flutter_test/flutter_test.dart';
import 'package:npo_community/core/config/app_config.dart';

void main() {
  group('AppConfig', () {
    test('derives API and WebSocket URIs from one HTTPS origin', () {
      final config = AppConfig.fromValues(
        environment: 'staging',
        apiOrigin: 'https://api.example.org',
      );

      expect(
        config.apiUri('/api/profile/').toString(),
        'https://api.example.org/api/profile/',
      );
      expect(
        config.webSocketUri('ws/chat/42/').toString(),
        'wss://api.example.org/ws/chat/42/',
      );
    });

    test('keeps a query string as a query, not part of the path', () {
      final config = AppConfig.fromValues(
        environment: 'staging',
        apiOrigin: 'https://api.example.org',
      );

      expect(
        config.apiUri('/api/events/?when=all&group=3').toString(),
        'https://api.example.org/api/events/?when=all&group=3',
      );
      expect(config.apiUri('/api/crm/alumni/?search=a%20b').queryParameters, {
        'search': 'a b',
      });
    });

    test('disables network access in demo mode', () {
      final config = AppConfig.fromValues(
        environment: 'demo',
        apiOrigin: 'http://127.0.0.1:8000',
      );

      expect(config.networkEnabled, isFalse);
      expect(() => config.apiUri('/api/profile/'), throwsStateError);
      expect(() => config.webSocketUri('/ws/chat/1/'), throwsStateError);
    });

    test('requires HTTPS in production', () {
      expect(
        () => AppConfig.fromValues(
          environment: 'production',
          apiOrigin: 'http://api.example.org',
        ),
        throwsArgumentError,
      );
    });

    test('rejects unknown environments and origins with paths', () {
      expect(
        () => AppConfig.fromValues(
          environment: 'preview',
          apiOrigin: 'https://api.example.org',
        ),
        throwsArgumentError,
      );
      expect(
        () => AppConfig.fromValues(
          environment: 'local',
          apiOrigin: 'http://127.0.0.1:8000/api',
        ),
        throwsArgumentError,
      );
    });
  });
}
