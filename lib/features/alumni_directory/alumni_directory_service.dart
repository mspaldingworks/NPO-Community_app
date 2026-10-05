import 'dart:convert';

import 'package:npo_community/core/services/api_client.dart';
import 'package:npo_community/features/alumni_directory/models/alumni_profile.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Reads the Emerge KY alumni directory from the server-side NGP VAN proxy.
///
/// The VAN API key lives only on the Django API; this service talks to the
/// authenticated `/api/crm/` endpoints via [ApiClient] (Token auth), never to
/// `api.securevan.com` directly.
class AlumniDirectoryService {
  AlumniDirectoryService({ApiClient? client}) : _client = client ?? ApiClient();

  final ApiClient _client;

  static const String _alumniPath = '/api/crm/alumni/';
  static const String _cacheKey = 'alumni_directory_cache';

  Future<List<AlumniProfile>> fetchAlumni({
    String? search,
    int? cohortYear,
    String? volunteerRole,
  }) async {
    final query = <String, String>{};
    if (search != null && search.trim().isNotEmpty) {
      query['search'] = search.trim();
    }
    if (cohortYear != null) {
      query['cohort_year'] = '$cohortYear';
    }
    if (volunteerRole != null && volunteerRole.isNotEmpty) {
      query['volunteer_role'] = volunteerRole;
    }

    final path = query.isEmpty
        ? _alumniPath
        : '$_alumniPath?${Uri(queryParameters: query).query}';

    final data = await _client.read(
      urlPath: path,
      jsonHeaders: _client.authHeaders,
    );

    final results = _extractList(data);

    // Keep an offline copy of the full directory (only the unfiltered
    // response, so the cache is always the complete roster).
    if (search == null && cohortYear == null && volunteerRole == null) {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_cacheKey, jsonEncode(results));
      } catch (_) {
        // Caching is best-effort; never fail the live fetch over it.
      }
    }

    return results
        .whereType<Map<String, dynamic>>()
        .map(AlumniProfile.fromJson)
        .toList();
  }

  /// The last successfully fetched full directory, or null when nothing is
  /// stored. Used as an offline fallback when the live fetch fails.
  Future<List<AlumniProfile>?> loadCached() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_cacheKey);
      if (raw == null) return null;
      final data = jsonDecode(raw);
      if (data is! List) return null;
      return data
          .whereType<Map<String, dynamic>>()
          .map(AlumniProfile.fromJson)
          .toList();
    } catch (_) {
      return null;
    }
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
