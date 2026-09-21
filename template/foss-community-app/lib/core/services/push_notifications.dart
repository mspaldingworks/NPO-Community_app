import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';

abstract interface class PushNotificationService {
  Future<void> registerEndpoint(String endpoint);
}

class DisabledPushNotificationService implements PushNotificationService {
  const DisabledPushNotificationService();

  @override
  Future<void> registerEndpoint(String endpoint) async {}
}

class NtfyPushNotificationService implements PushNotificationService {
  NtfyPushNotificationService({
    required this.config,
    required this.httpClient,
    required this.topic,
  });

  final AppConfig config;
  final http.Client httpClient;
  final String topic;

  @override
  Future<void> registerEndpoint(String endpoint) async {
    if (!config.networkEnabled || topic.isEmpty) {
      return;
    }

    await httpClient.post(
      config.apiUri('/api/push/subscribe/'),
      headers: {'content-type': 'application/json'},
      body: jsonEncode({'provider': 'ntfy', 'topic': topic, 'endpoint': endpoint}),
    );
  }
}
