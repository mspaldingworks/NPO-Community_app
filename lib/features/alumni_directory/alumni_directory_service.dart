import 'package:npo_community/core/services/api_client.dart';
import 'package:npo_community/features/alumni_directory/models/alumni_profile.dart';

/// Reads the Emerge KY alumni directory from the server-side NGP VAN proxy.
///
/// The VAN API key lives only on the Django API; this service talks to the
/// authenticated `/api/crm/` endpoints via [ApiClient] (Token auth), never to
/// `api.securevan.com` directly.
class AlumniDirectoryService {
  AlumniDirectoryService({ApiClient? client}) : _client = client ?? ApiClient();

  final ApiClient _client;

  static const String _alumniPath = '/api/crm/alumni/';

  Future<List<AlumniProfile>> fetchAlumni({
    String? search,
    int? cohortYear,
  }) async {
    final query = <String, String>{};
    if (search != null && search.trim().isNotEmpty) {
      query['search'] = search.trim();
    }
    if (cohortYear != null) {
      query['cohort_year'] = '$cohortYear';
    }

    final path = query.isEmpty
        ? _alumniPath
        : '$_alumniPath?${Uri(queryParameters: query).query}';

    final data = await _client.read(
      urlPath: path,
      jsonHeaders: _client.authHeaders,
    );

    final results = _extractList(data);
    return results
        .whereType<Map<String, dynamic>>()
        .map(AlumniProfile.fromJson)
        .toList();
  }

  Future<void> addNote(int vanId, String note) async {
    await _client.post(
      urlPath: '$_alumniPath$vanId/notes/',
      jsonHeaders: _client.authHeaders,
      jsonPayload: {'note': note},
      expectedStatusCode: 201,
    );
  }

  /// Accepts either a bare JSON list or a DRF-style paginated
  /// `{"results": [...]}` envelope.
  List<dynamic> _extractList(dynamic data) {
    if (data is List) return data;
    if (data is Map<String, dynamic> && data['results'] is List) {
      return data['results'] as List<dynamic>;
    }
    return const [];
  }
}
