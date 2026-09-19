enum AppEnvironment { local, demo, staging, production }

class AppConfig {
  AppConfig._({required this.environment, required this.apiOrigin});

  static const String _environmentValue = String.fromEnvironment(
    'APP_ENV',
    defaultValue: 'local',
  );
  static const String _apiOriginValue = String.fromEnvironment(
    'API_ORIGIN',
    defaultValue: 'http://127.0.0.1:8000',
  );

  static final AppConfig current = AppConfig.fromValues(
    environment: _environmentValue,
    apiOrigin: _apiOriginValue,
  );

  final AppEnvironment environment;
  final Uri apiOrigin;

  bool get networkEnabled => environment != AppEnvironment.demo;

  factory AppConfig.fromValues({
    required String environment,
    required String apiOrigin,
  }) {
    final parsedEnvironment = switch (environment.trim().toLowerCase()) {
      'local' => AppEnvironment.local,
      'demo' => AppEnvironment.demo,
      'staging' => AppEnvironment.staging,
      'production' => AppEnvironment.production,
      _ => throw ArgumentError.value(
        environment,
        'environment',
        'Expected local, demo, staging, or production',
      ),
    };
    final parsedOrigin = Uri.parse(apiOrigin.trim());

    if (!parsedOrigin.hasScheme || parsedOrigin.host.isEmpty) {
      throw ArgumentError.value(
        apiOrigin,
        'apiOrigin',
        'Expected an absolute URL',
      );
    }
    if (parsedOrigin.scheme != 'http' && parsedOrigin.scheme != 'https') {
      throw ArgumentError.value(
        apiOrigin,
        'apiOrigin',
        'Expected HTTP or HTTPS',
      );
    }
    if (parsedOrigin.path.isNotEmpty && parsedOrigin.path != '/' ||
        parsedOrigin.hasQuery ||
        parsedOrigin.hasFragment) {
      throw ArgumentError.value(
        apiOrigin,
        'apiOrigin',
        'Origin must not include a path, query, or fragment',
      );
    }
    if (parsedEnvironment == AppEnvironment.production &&
        parsedOrigin.scheme != 'https') {
      throw ArgumentError('Production API origin must use HTTPS');
    }

    return AppConfig._(
      environment: parsedEnvironment,
      apiOrigin: parsedOrigin.replace(path: ''),
    );
  }

  Uri apiUri(String path) {
    _requireNetworkEnabled();
    return _uriWithScheme(apiOrigin.scheme, path);
  }

  Uri webSocketUri(String path) {
    _requireNetworkEnabled();
    final scheme = apiOrigin.scheme == 'https' ? 'wss' : 'ws';
    return _uriWithScheme(scheme, path);
  }

  void _requireNetworkEnabled() {
    if (!networkEnabled) {
      throw StateError('Network access is disabled in demo mode');
    }
  }

  Uri _uriWithScheme(String scheme, String path) {
    final normalizedPath = path.startsWith('/') ? path : '/$path';
    return apiOrigin.replace(
      scheme: scheme,
      path: normalizedPath,
      query: null,
      fragment: null,
    );
  }
}
