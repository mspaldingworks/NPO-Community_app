import 'package:npo_community/core/services/community_service.dart';
import 'package:npo_community/models/post.dart';

enum ExchangeKind { request, offer }

enum ExchangeCompensation { free, trade, paid }

class ExchangeMetadata {
  final ExchangeKind kind;
  final ExchangeCompensation compensation;
  final String? price;
  final List<String> tags;

  const ExchangeMetadata({
    required this.kind,
    required this.compensation,
    this.price,
    this.tags = const [],
  });

  static ExchangeMetadata? tryParse(String? feeling) {
    if (feeling == null) return null;
    final raw = feeling.trim();
    if (!raw.toLowerCase().startsWith('exchange:')) return null;

    final afterPrefix = raw.substring('exchange:'.length);
    final parts = afterPrefix
        .split(';')
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty);

    final Map<String, String> kv = {};
    for (final part in parts) {
      final eqIndex = part.indexOf('=');
      if (eqIndex <= 0) {
        continue;
      }
      final key = part.substring(0, eqIndex).trim().toLowerCase();
      final value = part.substring(eqIndex + 1).trim();
      if (key.isEmpty) continue;
      kv[key] = value;
    }

    final kindRaw = (kv['kind'] ?? '').toLowerCase();
    final compRaw = (kv['comp'] ?? kv['compensation'] ?? '').toLowerCase();

    final ExchangeKind kind;
    if (kindRaw == 'request') {
      kind = ExchangeKind.request;
    } else if (kindRaw == 'offer') {
      kind = ExchangeKind.offer;
    } else {
      return null;
    }

    final ExchangeCompensation compensation;
    if (compRaw == 'free') {
      compensation = ExchangeCompensation.free;
    } else if (compRaw == 'trade') {
      compensation = ExchangeCompensation.trade;
    } else if (compRaw == 'paid') {
      compensation = ExchangeCompensation.paid;
    } else {
      return null;
    }

    final tagsRaw = kv['tags'];
    final tags = tagsRaw == null
        ? <String>[]
        : tagsRaw
              .split(',')
              .map((t) => t.trim())
              .where((t) => t.isNotEmpty)
              .toList();

    final price = (kv['price'] ?? '').trim();

    return ExchangeMetadata(
      kind: kind,
      compensation: compensation,
      price: price.isEmpty ? null : price,
      tags: tags,
    );
  }

  static String encode({
    required ExchangeKind kind,
    required ExchangeCompensation compensation,
    String? price,
    List<String> tags = const [],
  }) {
    final kindValue = kind == ExchangeKind.request ? 'request' : 'offer';
    final compValue = switch (compensation) {
      ExchangeCompensation.free => 'free',
      ExchangeCompensation.trade => 'trade',
      ExchangeCompensation.paid => 'paid',
    };

    final normalizedTags = tags
        .map((t) => t.trim())
        .where((t) => t.isNotEmpty)
        .toList();

    final buffer = StringBuffer('exchange:v1');
    buffer.write(';kind=$kindValue');
    buffer.write(';comp=$compValue');

    final p = (price ?? '').trim();
    if (p.isNotEmpty) {
      buffer.write(';price=$p');
    }

    if (normalizedTags.isNotEmpty) {
      buffer.write(';tags=${normalizedTags.join(',')}');
    }

    return buffer.toString();
  }
}

class ExchangeService {
  final CommunityService _communityService;

  ExchangeService({CommunityService? communityService})
    : _communityService = communityService ?? CommunityService();

  Future<List<Post>> fetchWorkAndServicesPosts() async {
    final posts = await _communityService.fetchAllPosts();
    final filtered = <Post>[];

    for (final p in posts) {
      final meta = ExchangeMetadata.tryParse(p.feeling);
      if (meta == null) continue;
      if (meta.compensation == ExchangeCompensation.free) continue;
      filtered.add(p);
    }

    return filtered;
  }

  Future<List<Post>> fetchHelpPosts() async {
    final posts = await _communityService.fetchAllPosts();
    final filtered = <Post>[];

    for (final p in posts) {
      final meta = ExchangeMetadata.tryParse(p.feeling);
      if (meta == null) continue;
      if (meta.compensation != ExchangeCompensation.free) continue;
      filtered.add(p);
    }

    return filtered;
  }

  Future<Post> createExchangePost({
    required int groupId,
    required String title,
    required String body,
    required ExchangeKind kind,
    required ExchangeCompensation compensation,
    String? price,
    List<String> tags = const [],
    bool anonymous = false,
    List<String> imageFilePaths = const [],
  }) async {
    if (tags.isEmpty) {
      throw Exception('At least one emoji tag is required.');
    }

    final feeling = ExchangeMetadata.encode(
      kind: kind,
      compensation: compensation,
      price: price,
      tags: tags,
    );

    final primaryEmoji = tags.first;

    return _communityService.createPostMultipart(
      groupId: groupId,
      title: title,
      body: body,
      emoji: primaryEmoji,
      feeling: feeling,
      public: true,
      anonymous: anonymous,
      imageFilePaths: imageFilePaths,
    );
  }
}
