import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/config/app_config.dart';

class PresignedUpload {
  const PresignedUpload({required this.uploadUrl, required this.publicUrl});

  final String uploadUrl;
  final String publicUrl;

  factory PresignedUpload.fromJson(Map<String, dynamic> json) => PresignedUpload(
    uploadUrl: json['upload_url'] as String,
    publicUrl: json['public_url'] as String,
  );
}

class MediaRepository {
  MediaRepository({required this.config, required this.httpClient});

  final AppConfig config;
  final http.Client httpClient;

  Future<PresignedUpload> createUploadUrl({required String filename}) async {
    if (!config.networkEnabled) {
      throw StateError('Demo mode does not request remote media URLs.');
    }

    final response = await httpClient.post(
      config.apiUri('/api/media/presign-upload/'),
      headers: {'content-type': 'application/json'},
      body: jsonEncode({'filename': filename}),
    );
    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    return PresignedUpload.fromJson(payload);
  }
}
