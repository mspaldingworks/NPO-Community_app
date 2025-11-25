import 'package:transconnect/core/constants/api_endpoints.dart';
import 'package:transconnect/core/services/api_client.dart';
import 'package:transconnect/models/chat_message.dart';
import 'package:transconnect/models/conversation.dart';

/// Service class that wraps chat-related API calls.
class ChatService extends ApiClient {
  ChatService();

  Future<List<Conversation>> fetchConversations() async {
    final result = await read(
      urlPath: ApiEndpoints.conversations,
      jsonHeaders: authHeaders,
    );

    if (result is List) {
      return result
          .map((json) => Conversation.fromJson(json as Map<String, dynamic>))
          .toList();
    }
    return [];
  }

  Future<Conversation> getConversation(String conversationId) async {
    final result = await read(
      urlPath: ApiEndpoints.conversation(conversationId),
      jsonHeaders: authHeaders,
    ) as Map<String, dynamic>;
    return Conversation.fromJson(result);
  }

  Future<List<ChatMessage>> getMessages(String conversationId) async {
    final result = await read(
      urlPath: ApiEndpoints.conversationMessages(conversationId),
      jsonHeaders: authHeaders,
    );

    if (result is List) {
      return result
          .map((json) => ChatMessage.fromJson(json as Map<String, dynamic>))
          .toList();
    }
    return [];
  }

  Future<ChatMessage> sendMessage({
    required String conversationId,
    required String content,
  }) async {
    final payload = {
      'content': content,
    };

    final result = await post(
      urlPath: ApiEndpoints.conversationMessages(conversationId),
      jsonHeaders: authHeaders,
      jsonPayload: payload,
      expectedStatusCode: 201,
    ) as Map<String, dynamic>;

    return ChatMessage.fromJson(result);
  }

  Future<Conversation> createChat({
    required List<String> participantIds,
    String? name,
    bool isGroup = false,
    String? groupImage,
  }) async {
    final payload = {
      'participant_ids': participantIds,
      if (name != null) 'name': name,
      'is_group': isGroup,
      if (groupImage != null) 'group_image': groupImage,
    };

    final result = await post(
      urlPath: ApiEndpoints.conversations,
      jsonHeaders: authHeaders,
      jsonPayload: payload,
      expectedStatusCode: 201,
    ) as Map<String, dynamic>;

    return Conversation.fromJson(result);
  }

  Future<Conversation> createGroupChat({
    required String name,
    required List<String> participantIds,
    String? groupImage,
  }) {
    return createChat(
      participantIds: participantIds,
      name: name,
      isGroup: true,
      groupImage: groupImage,
    );
  }

  Future<Conversation> updateConversation({
    required String conversationId,
    String? name,
    List<String>? addParticipants,
    List<String>? removeParticipants,
    String? groupImage,
    bool? isMuted,
  }) async {
    final payload = <String, dynamic>{};
    if (name != null) payload['name'] = name;
    if (addParticipants != null && addParticipants.isNotEmpty) {
      payload['add_participants'] = addParticipants;
    }
    if (removeParticipants != null && removeParticipants.isNotEmpty) {
      payload['remove_participants'] = removeParticipants;
    }
    if (groupImage != null) payload['group_image'] = groupImage;
    if (isMuted != null) payload['is_muted'] = isMuted;

    final result = await update(
      urlPath: ApiEndpoints.conversation(conversationId),
      jsonHeaders: authHeaders,
      jsonPayload: payload,
    ) as Map<String, dynamic>;

    return Conversation.fromJson(result);
  }

  Future<bool> deleteConversation(String conversationId) async {
    try {
      await delete(
        urlPath: ApiEndpoints.conversation(conversationId),
        jsonHeaders: authHeaders,
        expectedStatusCode: 204,
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> markAsRead({
    required String conversationId,
    required List<String> messageIds,
  }) async {
    if (messageIds.isEmpty) return;

    await post(
      urlPath: ApiEndpoints.markAsRead(conversationId),
      jsonHeaders: authHeaders,
      jsonPayload: {'message_ids': messageIds},
      expectedStatusCode: 200,
    );
  }

  Future<bool> muteConversation(String conversationId, {bool mute = true}) async {
    final endpoint = mute
        ? ApiEndpoints.muteConversation(conversationId)
        : ApiEndpoints.unmuteConversation(conversationId);

    try {
      await post(
        urlPath: endpoint,
        jsonHeaders: authHeaders,
        jsonPayload: const {},
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> leaveGroup(String conversationId) async {
    final endpoint = '${ApiEndpoints.conversation(conversationId)}leave/';
    try {
      await post(
        urlPath: endpoint,
        jsonHeaders: authHeaders,
        jsonPayload: const {},
        expectedStatusCode: 204,
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<List<ChatMessage>> searchMessages({
    required String conversationId,
    required String query,
  }) async {
    final result = await read(
      urlPath: ApiEndpoints.searchConversationMessages(conversationId),
      jsonHeaders: authHeaders,
    );

    if (result is List) {
      return result
          .map((json) => ChatMessage.fromJson(json as Map<String, dynamic>))
          .toList();
    }
    return [];
  }
}