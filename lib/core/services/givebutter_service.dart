import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:npo_community/features/fundraising/models/givebutter_campaign.dart';
import 'package:npo_community/features/fundraising/models/givebutter_transaction.dart';

class GivebutterService {
  static const _baseUrl = 'https://api.givebutter.com/v1';

  GivebutterService(this._apiKey);

  final String _apiKey;

  bool get isConfigured => _apiKey.isNotEmpty;

  Map<String, String> get _headers => {
        'Authorization': 'Bearer $_apiKey',
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };

  Future<List<GivebutterCampaign>> listCampaigns({String? scope}) async {
    final params = <String, String>{if (scope != null) 'scope': scope};
    final uri = Uri.parse('$_baseUrl/campaigns').replace(
      queryParameters: params.isEmpty ? null : params,
    );
    final response = await http.get(uri, headers: _headers);
    _assertSuccess(response);
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return (body['data'] as List<dynamic>)
        .map((e) => GivebutterCampaign.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<GivebutterCampaign> getCampaign(String id) async {
    final uri = Uri.parse('$_baseUrl/campaigns/$id');
    final response = await http.get(uri, headers: _headers);
    _assertSuccess(response);
    return GivebutterCampaign.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<GivebutterCampaign> createCampaign({
    required String title,
    String? subtitle,
    String? description,
    int? goal,
    String type = 'fundraiser',
    String? endAt,
  }) async {
    final uri = Uri.parse('$_baseUrl/campaigns');
    final payload = <String, dynamic>{
      'title': title,
      'type': type,
      if (subtitle != null && subtitle.isNotEmpty) 'subtitle': subtitle,
      if (description != null && description.isNotEmpty) 'description': description,
      if (goal != null && goal > 0) 'goal': goal,
      if (endAt != null) 'end_at': endAt,
    };
    final response = await http.post(
      uri,
      headers: _headers,
      body: jsonEncode(payload),
    );
    _assertSuccess(response, allowedStatuses: {200, 201});
    return GivebutterCampaign.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<List<GivebutterTransaction>> listTransactions({
    String? campaignCode,
  }) async {
    final params = <String, String>{
      if (campaignCode != null) 'campaign_code': campaignCode,
    };
    final uri = Uri.parse('$_baseUrl/transactions').replace(
      queryParameters: params.isEmpty ? null : params,
    );
    final response = await http.get(uri, headers: _headers);
    _assertSuccess(response);
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return (body['data'] as List<dynamic>)
        .map((e) => GivebutterTransaction.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  void _assertSuccess(
    http.Response response, {
    Set<int> allowedStatuses = const {200},
  }) {
    if (allowedStatuses.contains(response.statusCode)) return;
    String message = 'Givebutter API error ${response.statusCode}';
    try {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      message = (body['message'] as String?) ?? message;
    } catch (_) {}
    throw Exception(message);
  }
}
