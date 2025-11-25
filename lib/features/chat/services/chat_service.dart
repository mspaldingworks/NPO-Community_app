import 'package:transconnect/core/constants/api_endpoints.dart';
import 'package:transconnect/core/services/api_client.dart';
import 'package:transconnect/models/chat_message.dart';
import 'package:transconnect/models/conversation.dart';

class ChatService extends ApiClient {
  ChatService();

  /// Returns all conversations for the current user.
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

  /// Fetches the details of a single conversation and returns the `Conversation` model.
  Future<Conversation> getConversation(String conversationId) async {
    final result = await read(
      urlPath: ApiEndpoints.conversation(conversationId),
      jsonHeaders: authHeaders,
    ) as Map<String, dynamic>;
    return Conversation.fromJson(result);
  }

  /// Returns the messages for a particular conversation.
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

  /// Sends a message to an existing conversation.
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

  /// Creates a new conversation with the supplied participant ids. When more than
  /// one participant is provided, the caller can supply a `name` and `isGroup`
  /// flag to control backend behaviour.
  Future<Conversation> createChat({
    required List<String> participantIds,
    String? name,
    bool? isGroup,
  }) async {
    final payload = {
      'participant_ids': participantIds,
      if (name != null) 'name': name,
      if (isGroup != null) 'is_group': isGroup,
    };

    final result = await post(
      urlPath: ApiEndpoints.conversations,
      jsonHeaders: authHeaders,
      jsonPayload: payload,
      expectedStatusCode: 201,
    ) as Map<String, dynamic>;

    return Conversation.fromJson(result);
  }

  /// Deletes a conversation, returning true on success.
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

  /// Marks the provided message ids as read in the conversation.
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
}
