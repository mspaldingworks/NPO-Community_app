import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

class LinkPreviewMetadata {
  final Uri url;
  final String? siteName;
  final String? title;
  final String? description;
  final Uri? imageUrl;

  const LinkPreviewMetadata({
    required this.url,
    this.siteName,
    this.title,
    this.description,
    this.imageUrl,
  });

  bool get isEffectivelyEmpty {
    final t = title?.trim() ?? '';
    final d = description?.trim() ?? '';
    return t.isEmpty && d.isEmpty && imageUrl == null;
  }
}

class LinkPreviewService {
  LinkPreviewService._();

  static final LinkPreviewService instance = LinkPreviewService._();

  factory LinkPreviewService() => instance;

  final http.Client _client = http.Client();

  final Map<String, LinkPreviewMetadata?> _cache = {};
  final Map<String, Future<LinkPreviewMetadata?>> _inFlight = {};

  Uri? extractFirstUrl(String? text) {
    if (text == null) return null;

    final match = RegExp(
      r'(https?:\/\/[^\s<>()]+|www\.[^\s<>()]+)',
      caseSensitive: false,
    ).firstMatch(text);
    final raw = match?.group(0);
    if (raw == null || raw.trim().isEmpty) return null;

    var candidate = raw.trim();
    while (candidate.isNotEmpty &&
        RegExp(r'[\]\[\)\(\}\{\.,!?:;]$').hasMatch(candidate)) {
      candidate = candidate.substring(0, candidate.length - 1);
    }

    if (candidate.startsWith('www.')) {
      candidate = 'https://$candidate';
    }

    final uri = Uri.tryParse(candidate);
    if (uri == null || uri.host.isEmpty) return null;
    if (uri.scheme != 'http' && uri.scheme != 'https') return null;

    return uri;
  }

  String normalizeKey(Uri uri) {
    final normalized = uri.replace(
      fragment: '',
      path: uri.path.isEmpty ? '/' : uri.path,
    );

    final scheme = normalized.scheme.toLowerCase();
    final host = normalized.host.toLowerCase();

    final hasDefaultPort =
        (scheme == 'http' && normalized.hasPort && normalized.port == 80) ||
        (scheme == 'https' && normalized.hasPort && normalized.port == 443);

    final portPart = normalized.hasPort && !hasDefaultPort
        ? ':${normalized.port}'
        : '';

    var path = normalized.path;
    if (path.endsWith('/') && path.length > 1) {
      path = path.substring(0, path.length - 1);
    }

    final query = normalized.query.isEmpty ? '' : '?${normalized.query}';
    return '$scheme://$host$portPart$path$query';
  }

  Future<LinkPreviewMetadata?> fetchMetadata(Uri uri) {
    final key = normalizeKey(uri);

    if (_cache.containsKey(key)) {
      return Future.value(_cache[key]);
    }

    final inflight = _inFlight[key];
    if (inflight != null) {
      return inflight;
    }

    final future = _fetchAndParse(uri)
        .then((value) {
          _cache[key] = value;
          _inFlight.remove(key);
          return value;
        })
        .catchError((_) {
          _cache[key] = null;
          _inFlight.remove(key);
          return null;
        });

    _inFlight[key] = future;
    return future;
  }

  Future<LinkPreviewMetadata?> _fetchAndParse(Uri uri) async {
    final response = await _client
        .get(
          uri,
          headers: const {
            'User-Agent':
                'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120 Safari/537.36',
            'Accept': 'text/html,application/xhtml+xml',
          },
        )
        .timeout(const Duration(seconds: 8));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      return null;
    }

    final html = utf8.decode(response.bodyBytes, allowMalformed: true);
    final baseUrl = response.request?.url ?? uri;

    final siteName =
        _extractMetaContent(html, property: 'og:site_name') ?? baseUrl.host;

    final title =
        _extractMetaContent(html, property: 'og:title') ?? _extractTitle(html);

    final description =
        _extractMetaContent(html, property: 'og:description') ??
        _extractMetaContent(html, name: 'description') ??
        _extractMetaContent(html, name: 'Description');

    final rawImage = _extractMetaContent(html, property: 'og:image');
    final imageUrl = _resolveMaybeRelative(baseUrl, rawImage);

    final metadata = LinkPreviewMetadata(
      url: baseUrl,
      siteName: _normalizeWhitespace(siteName),
      title: _normalizeWhitespace(title),
      description: _normalizeWhitespace(description),
      imageUrl: imageUrl,
    );

    if (metadata.isEffectivelyEmpty) {
      return null;
    }

    return metadata;
  }

  Uri? _resolveMaybeRelative(Uri base, String? raw) {
    final s = raw?.trim();
    if (s == null || s.isEmpty) return null;

    final parsed = Uri.tryParse(s);
    if (parsed == null) return null;

    if (parsed.hasScheme) {
      return parsed;
    }

    try {
      return base.resolveUri(parsed);
    } catch (_) {
      return null;
    }
  }

  String? _extractMetaContent(String html, {String? property, String? name}) {
    final key = property ?? name;
    if (key == null) return null;

    final attrName = property != null ? 'property' : 'name';

    final metaTag = RegExp(
      '<meta[^>]*\\s$attrName\\s*=\\s*["\']${RegExp.escape(key)}["\'][^>]*>',
      caseSensitive: false,
      dotAll: true,
    ).firstMatch(html);

    final tag = metaTag?.group(0);
    if (tag == null) return null;

    final contentMatch = RegExp(
      'content\\s*=\\s*["\']([^"\']+)["\']',
      caseSensitive: false,
    ).firstMatch(tag);

    return contentMatch?.group(1);
  }

  String? _extractTitle(String html) {
    final match = RegExp(
      '<title[^>]*>(.*?)</title>',
      caseSensitive: false,
      dotAll: true,
    ).firstMatch(html);

    return match?.group(1);
  }

  String? _normalizeWhitespace(String? raw) {
    if (raw == null) return null;
    final s = raw
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll(RegExp(r'\u00A0'), ' ')
        .trim();
    return s.isEmpty ? null : s;
  }
}
