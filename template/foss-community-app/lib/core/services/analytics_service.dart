import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../config/public_config.dart';

abstract interface class AnalyticsService {
  Future<void> trackEvent(String name, {Map<String, String>? data});
}

class NoopAnalyticsService implements AnalyticsService {
  const NoopAnalyticsService();

  @override
  Future<void> trackEvent(String name, {Map<String, String>? data}) async {}
}

class MatomoAnalyticsService implements AnalyticsService {
  MatomoAnalyticsService({
    required this.config,
    required this.publicConfig,
    required this.userOptIn,
  });

  final AppConfig config;
  final PublicConfig publicConfig;
  final bool userOptIn;

  @override
  Future<void> trackEvent(String name, {Map<String, String>? data}) async {
    if (!userOptIn || !config.networkEnabled || !publicConfig.matomoConfigured) {
      return;
    }

    final baseUri = Uri.parse(publicConfig.matomoUrl);
    final normalizedBasePath = baseUri.path.endsWith('/')
        ? baseUri.path.substring(0, baseUri.path.length - 1)
        : baseUri.path;
    final queryParameters = <String, String>{
      ...baseUri.queryParameters,
      'idsite': publicConfig.matomoSiteId,
      'rec': '1',
      'e_c': 'app',
      'e_a': name,
      'e_n': jsonEncode(data ?? const <String, String>{}),
    };
    final endpoint = baseUri.replace(
      path: '$normalizedBasePath/matomo.php',
      queryParameters: queryParameters,
    );
    await http.get(endpoint);
  }
}
