// Removed: import 'dart:convert';
// Removed: import 'package:transconnect/core/services/shared_preferences_service.dart';
import 'dart:async';

import 'package:http/http.dart' as http;
import 'package:transconnect/core/services/api_client.dart';
import 'package:transconnect/core/services/shared_preferences_service.dart';
import 'package:transconnect/models/resource.dart';

class _CachedLinkStatus {
  final bool? reachable;
  final DateTime? checkedAt;
  final Future<bool>? inFlight;

  const _CachedLinkStatus({this.reachable, this.checkedAt, this.inFlight});
}

class ResourceService extends ApiClient {
  static const String _favoriteResourcesKey = 'favorite_resources_v1';
  static const Duration _linkStatusMaxAge = Duration(hours: 12);

  final SharedPreferencesService _prefsService = SharedPreferencesService();
  static final Map<String, _CachedLinkStatus> _linkStatusCache = <String, _CachedLinkStatus>{};

  ResourceService();

  // Helper function remains, though it will now work with the output 
  // of the ApiClient's response processing.
  List<Resource> createResourceListFromJson(dynamic jsonList) {
  final List<dynamic> decodedList = jsonList as List<dynamic>;
  return decodedList.map((json) => Resource.fromJson(json)).toList();
  }

  Future<Set<int>> getFavoriteResourceIds() async {
    final raw = _prefsService.getData(_favoriteResourcesKey);
    if (raw == null || raw.trim().isEmpty) {
      return <int>{};
    }
    final ids = raw
        .split(',')
        .map((s) => int.tryParse(s.trim()))
        .whereType<int>()
        .toSet();
    return ids;
  }

  Future<void> setResourceFavorite({required int resourceId, required bool isFavorite}) async {
    final current = await getFavoriteResourceIds();
    final next = <int>{...current};
    if (isFavorite) {
      next.add(resourceId);
    } else {
      next.remove(resourceId);
    }
    await _prefsService.saveData(_favoriteResourcesKey, next.join(','));
  }

  Future<bool?> getCachedLinkReachable(String? url) async {
    if (url == null) return null;
    final normalized = url.trim();
    if (normalized.isEmpty) return null;

    final now = DateTime.now();
    final cached = _linkStatusCache[normalized];
    if (cached != null) {
      final checkedAt = cached.checkedAt;
      final reachable = cached.reachable;
      if (reachable != null && checkedAt != null && now.difference(checkedAt) <= _linkStatusMaxAge) {
        return reachable;
      }
      final inFlight = cached.inFlight;
      if (inFlight != null) {
        return await inFlight;
      }
    }

    final future = _checkUrlReachable(normalized);
    _linkStatusCache[normalized] = _CachedLinkStatus(inFlight: future);

    final reachable = await future;
    _linkStatusCache[normalized] = _CachedLinkStatus(reachable: reachable, checkedAt: DateTime.now());
    return reachable;
  }

  Future<bool> _checkUrlReachable(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasScheme) return false;

    final client = http.Client();
    try {
      try {
        final req = http.Request('HEAD', uri)..followRedirects = true;
        final resp = await client.send(req).timeout(const Duration(seconds: 6));
        final code = resp.statusCode;
        if (code >= 200 && code < 400) return true;
        if (code != 405 && code != 501) return false;
      } catch (_) {}

      try {
        final req = http.Request('GET', uri)
          ..followRedirects = true
          ..headers['Range'] = 'bytes=0-0';
        final resp = await client.send(req).timeout(const Duration(seconds: 6));
        final code = resp.statusCode;
        if (code == 200 || code == 206) return true;
        if (code >= 300 && code < 400) return true;
        return false;
      } catch (_) {
        return false;
      }
    } on TimeoutException {
      return false;
    } catch (_) {
      return false;
    } finally {
      client.close();
    }
  }

  // Fetches all resources.
  Future<List<Resource>> fetchResources() async {
    final result = await read(
      jsonHeaders: authHeaders, // Uses inherited property
      urlPath: 'api/resources/',
    );

    return createResourceListFromJson(result);
  }

  // Adds a new resource.
  Future<Resource> addResource({
    required String name,
    required String description,
    required String type,
    required String url,
    required bool public,
    required String provider,
    required List<String> tags,
  }) async {
    final result = await post(
      urlPath: 'api/resources/',
      jsonHeaders: authHeaders, // Uses inherited property
      jsonPayload: {
        'name': name,
        'description': description,
        'type': type,
        'url': url,
        'public': public,
        'provider': provider,
        'tags': tags,
      },
      expectedStatusCode: 201, // Explicitly set expected status code for POST
    );
    return Resource.fromJson(result as Map<String, dynamic>);
  }

  // Updates an existing resource.
  Future<Resource> updateResource(Resource resource) async {
    final result = await put(
      urlPath: 'api/resources/${resource.id}/',
      jsonHeaders: authHeaders, // Uses inherited property
      jsonPayload: {
        'name': resource.name,
        'description': resource.description,
        'type': resource.type,
        'url': resource.url,
        'provider': resource.provider,
        'public': resource.public,
        'tags': resource.tags,
      },
    );
    return Resource.fromJson(result as Map<String, dynamic>);
  }

  // Deletes a resource.
  Future<void> deleteResource(int resourceId) async {
    await delete(
      urlPath: 'api/resources/$resourceId/',
      jsonHeaders: authHeaders, // Uses inherited property
    );
  }
}