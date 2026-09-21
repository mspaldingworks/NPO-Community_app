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
    required this.httpClient,
    required this.userOptIn,
  });

  final AppConfig config;
  final PublicConfig publicConfig;
  final http.Client httpClient;
  final bool userOptIn;

  @override
  Future<void> trackEvent(String name, {Map<String, String>? data}) async {
    if (!userOptIn || !config.networkEnabled || !publicConfig.matomoConfigured) {
      return;
    }

    final endpoint = Uri.parse(publicConfig.matomoUrl).replace(path: '/matomo.php');
    await httpClient.post(
      endpoint,
      headers: {'content-type': 'application/json'},
      body: jsonEncode({
        'site_id': publicConfig.matomoSiteId,
        'event_name': name,
        'event_data': data ?? const <String, String>{},
      }),
    );
  }
}
