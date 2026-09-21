enum AppEnvironment { demo, local, production }

class AppConfig {
  AppConfig._({
    required this.environment,
    required this.apiOrigin,
    required this.sentryDsn,
  });

  final AppEnvironment environment;
  final Uri apiOrigin;
  final String sentryDsn;

  static AppConfig fromEnvironment() {
    const env = String.fromEnvironment('APP_ENV', defaultValue: 'local');
    const apiOrigin = String.fromEnvironment(
      'API_ORIGIN',
      defaultValue: 'http://127.0.0.1:8000',
    );
    const sentryDsn = String.fromEnvironment('SENTRY_DSN', defaultValue: '');
    return AppConfig.fromValues(
      environment: env,
      apiOrigin: apiOrigin,
      sentryDsn: sentryDsn,
    );
  }

  static AppConfig fromValues({
    required String environment,
    required String apiOrigin,
    String sentryDsn = '',
  }) {
    final parsedEnvironment = switch (environment.trim().toLowerCase()) {
      'demo' => AppEnvironment.demo,
      'local' => AppEnvironment.local,
      'production' => AppEnvironment.production,
      _ => throw ArgumentError.value(
        environment,
        'environment',
        'Expected demo, local, or production',
      ),
    };

    final parsedOrigin = Uri.parse(apiOrigin.trim());
    if (!parsedOrigin.hasScheme || parsedOrigin.host.isEmpty) {
      throw ArgumentError.value(apiOrigin, 'apiOrigin', 'Expected absolute URL');
    }
    if (parsedOrigin.scheme != 'http' && parsedOrigin.scheme != 'https') {
      throw ArgumentError.value(apiOrigin, 'apiOrigin', 'Expected HTTP or HTTPS');
    }
    if (parsedOrigin.path.isNotEmpty && parsedOrigin.path != '/') {
      throw ArgumentError.value(
        apiOrigin,
        'apiOrigin',
        'Expected origin without a path',
      );
    }
    if (parsedOrigin.hasQuery || parsedOrigin.hasFragment) {
      throw ArgumentError.value(
        apiOrigin,
        'apiOrigin',
        'Expected origin without query or fragment',
      );
    }
    if (parsedEnvironment == AppEnvironment.production &&
        parsedOrigin.scheme != 'https') {
      throw ArgumentError('Production API origin must use HTTPS');
    }

    return AppConfig._(
      environment: parsedEnvironment,
      apiOrigin: parsedOrigin.replace(path: '', query: null, fragment: null),
      sentryDsn: sentryDsn.trim(),
    );
  }

  bool get networkEnabled => environment != AppEnvironment.demo;

  bool get sentryEnabled => networkEnabled && sentryDsn.isNotEmpty;

  Uri apiUri(String path) {
    if (!networkEnabled) {
      throw StateError('Network access is disabled in demo mode');
    }
    return apiOrigin.replace(path: path.startsWith('/') ? path : '/$path');
  }

  Uri webSocketUri(String path) {
    if (!networkEnabled) {
      throw StateError('Network access is disabled in demo mode');
    }
    final wsScheme = apiOrigin.scheme == 'https' ? 'wss' : 'ws';
    return apiOrigin.replace(
      scheme: wsScheme,
      path: path.startsWith('/') ? path : '/$path',
    );
  }
}
