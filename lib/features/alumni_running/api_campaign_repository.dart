import 'package:npo_community/core/config/app_config.dart';
import 'package:npo_community/core/services/api_client.dart';
import 'package:npo_community/core/services/chat_service.dart';
import 'package:npo_community/features/alumni_running/campaign_repository.dart';
import 'package:npo_community/features/alumni_running/models/alumni_candidate.dart';
import 'package:npo_community/features/alumni_running/models/campaign_channel.dart';
import 'package:npo_community/features/alumni_running/models/campaign_shift.dart';
import 'package:npo_community/models/chat_message.dart';

/// Live Campaign Support Hub data from the authenticated `/api/campaigns/`
/// endpoints (see `docs/campaign-hub-api.md`).
///
/// Request URLs here reveal which campaigns the user supports, so both
/// clients are built with request logging turned off.
class ApiCampaignRepository implements CampaignRepository {
  ApiCampaignRepository({
    ApiClient? client,
    ChatService? chatService,
    Uri? mediaOrigin,
  }) : _client = client ?? ApiClient(logRequests: false),
       _chat = chatService ?? ChatService(logRequests: false),
       _mediaOrigin = mediaOrigin ?? AppConfig.current.apiOrigin;

  final ApiClient _client;
  final ChatService _chat;
  final Uri _mediaOrigin;

  static const String _base = '/api/campaigns';

  @override
  bool get supportsWrites => true;

  @override
  Future<List<AlumniCandidate>> fetchCandidates() async {
    final data = await _client.read(
      urlPath: '$_base/candidates/',
      jsonHeaders: _client.authHeaders,
    );
    return _parseList(
      data,
      (json) => AlumniCandidate.fromJson(json, mediaOrigin: _mediaOrigin),
    );
  }

  @override
  Future<List<CampaignChannelMembership>> fetchMyChannels() async {
    final data = await _client.read(
      urlPath: '$_base/channels/',
      jsonHeaders: _client.authHeaders,
    );
    return _parseList(data, CampaignChannelMembership.fromJson);
  }

  @override
  Future<CampaignChannelMembership> joinChannel(String candidateId) async {
    final data = await _client.post(
      urlPath: '$_base/candidates/${_seg(candidateId)}/channel/join/',
      jsonHeaders: _client.authHeaders,
      jsonPayload: const {},
    );
    if (data is! Map<String, dynamic>) {
      throw const ApiClientException('Unexpected response joining channel.');
    }
    return CampaignChannelMembership.fromJson(data);
  }

  @override
  Future<void> leaveChannel(String candidateId) async {
    await _client.delete(
      urlPath: '$_base/candidates/${_seg(candidateId)}/channel/membership/',
      jsonHeaders: _client.authHeaders,
    );
  }

  @override
  Future<List<ChatMessage>> fetchChannelMessages(String channelId) =>
      _chat.getChannelMessages(channelId);

  @override
  Future<ChatMessage> sendChannelMessage(String channelId, String content) =>
      _chat.sendChannelMessage(channelId: channelId, content: content);

  @override
  Stream<void> watchChannel(String channelId) {
    try {
      return _chat
          .connectToChatChannel(channelId)
          .where((event) => event.isMessage);
    } catch (_) {
      return const Stream.empty();
    }
  }

  @override
  void unwatchChannel(String channelId) =>
      _chat.disconnectFromChatChannel(channelId, notify: false);

  @override
  Future<List<CampaignShift>> fetchShifts(String candidateId) async {
    final data = await _client.read(
      urlPath: '$_base/candidates/${_seg(candidateId)}/shifts/',
      jsonHeaders: _client.authHeaders,
    );
    return _parseList(
      data,
      (json) => CampaignShift.fromJson(json, candidateId: candidateId),
    );
  }

  @override
  Future<List<CampaignShift>> fetchMyShifts() async {
    final data = await _client.read(
      urlPath: '$_base/my-shifts/',
      jsonHeaders: _client.authHeaders,
    );
    return _parseList(data, CampaignShift.fromJson);
  }

  @override
  Future<CampaignShift> signUpForShift(CampaignShift shift) async {
    final data = await _client.post(
      urlPath: '$_base/shifts/${_seg(shift.id)}/signup/',
      jsonHeaders: _client.authHeaders,
      jsonPayload: const {},
      expectedStatusCode: 201,
    );
    return _parseShift(data, shift);
  }

  @override
  Future<CampaignShift> cancelShift(CampaignShift shift) async {
    final data = await _client.delete(
      urlPath: '$_base/shifts/${_seg(shift.id)}/signup/',
      jsonHeaders: _client.authHeaders,
      expectedStatusCode: 200,
    );
    return _parseShift(data, shift);
  }

  CampaignShift _parseShift(dynamic data, CampaignShift original) {
    if (data is! Map<String, dynamic>) {
      throw const ApiClientException('Unexpected response for shift.');
    }
    return CampaignShift.fromJson(data, candidateId: original.candidateId);
  }

  static String _seg(String id) => Uri.encodeComponent(id);

  /// Accepts a bare list or a DRF `{"results": [...]}` envelope and skips
  /// malformed entries rather than failing the whole list.
  static List<T> _parseList<T>(
    dynamic data,
    T Function(Map<String, dynamic>) parse,
  ) {
    final List<dynamic> items;
    if (data is List) {
      items = data;
    } else if (data is Map<String, dynamic> && data['results'] is List) {
      items = data['results'] as List<dynamic>;
    } else {
      items = const [];
    }
    final out = <T>[];
    for (final item in items.whereType<Map<String, dynamic>>()) {
      try {
        out.add(parse(item));
      } on FormatException {
        continue;
      }
    }
    return out;
  }
}
