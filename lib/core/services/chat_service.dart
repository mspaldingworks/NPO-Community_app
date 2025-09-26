import 'package:transconnect/core/services/api_client.dart'; // Assuming ApiClient.dart is in this path
import 'package:transconnect/models/chat_message.dart'; // Assuming ChatMessage.dart is in this path

/// Represents the other user in a conversation, as returned by the 
/// 'active_conversations' API endpoint.
class ConversationPreview {
  final int id;
  final String username;
  final int unreadCount;

  ConversationPreview({
    required this.id,
    required this.username,
    this.unreadCount = 0,
  });

  factory ConversationPreview.fromJson(Map<String, dynamic> json) {
    return ConversationPreview(
      id: json['id'] as int,
      username: json['username'] as String,
      unreadCount: json['unread_count'] as int? ?? 0,
    );
  }
}

/// Service class for all chat and messaging related API calls.
class ChatService extends ApiClient {
  static const String _messagesBaseUrl = 'api/messages';

  /// Fetches a list of all current conversations, returning the other user's
  /// The endpoint used is: GET /api/messages/active_conversations/
  Future<List<ConversationPreview>> getAllConversations() async {
    const urlPath = '$_messagesBaseUrl/active_conversations/';
    try {
      final responseData = await read(urlPath: urlPath, jsonHeaders: authHeaders);
      
      if (responseData is List) {
        return responseData
            .map((json) => ConversationPreview.fromJson(json as Map<String, dynamic>))
            .toList();
      }
      
      throw const FormatException('Expected a list for active conversations.');
    } catch (e) {
      throw Exception('Failed to fetch active conversations: $e');
    }
  }

  /// Fetches the entirety of a conversation between the current user and 
  /// the user with the given [otherUserId].
  /// The endpoint used is: GET /api/messages/messages_between/?user_id={otherUserId}
  /// The response is mapped to a list of [ChatMessage] objects.
  Future<List<ChatMessage>> getConversation(int otherUserId) async {
    final urlPath = '$_messagesBaseUrl/messages_between/?user_id=$otherUserId';
    try {
      final responseData = await read(urlPath: urlPath, jsonHeaders: authHeaders);

      if (responseData is List) {
        return responseData
            .map((json) => ChatMessage.fromJson(json as Map<String, dynamic>))
            .toList();
      }

      throw const FormatException('Expected a list of messages for the conversation.');
    } catch (e) {
      throw Exception('Failed to fetch conversation with user $otherUserId: $e');
    }
  }

  /// Fetches all messages involving the authenticated user.
  Future<List<ChatMessage>> getAllMessages() async {
    const urlPath = '$_messagesBaseUrl/';
    try {
      final responseData = await read(urlPath: urlPath, jsonHeaders: authHeaders);
      
      if (responseData is List) {
        return responseData
            .map((json) => ChatMessage.fromJson(json as Map<String, dynamic>))
            .toList();
      }
      
      throw const FormatException('Expected a list for all messages.');
    } catch (e) {
      throw Exception('Failed to fetch all messages: $e');
    }
  }

  /// Fetches a single message by its ID.
  Future<ChatMessage> getMessageById(int messageId) async {
    final urlPath = '$_messagesBaseUrl/$messageId/';
    try {
      final responseData = await read(urlPath: urlPath, jsonHeaders: authHeaders);
      
      return ChatMessage.fromJson(responseData as Map<String, dynamic>);
    } catch (e) {
      throw Exception('Failed to fetch message with ID $messageId: $e');
    }
  }
  
  Future<ChatMessage> sendMessage({required int recipientId, required String content}) async {
    const urlPath = '$_messagesBaseUrl/';
    final payload = {
      'recipient': recipientId,
      'content': content,
    };
    try {
      // Expected status code for creation is typically 201 Created or 200 OK. 
      // Using 201 as a common REST practice for creation.
      final responseData = await post(
        urlPath: urlPath,
        jsonHeaders: authHeaders,
        jsonPayload: payload,
        expectedStatusCode: 201, 
      );
      return ChatMessage.fromJson(responseData as Map<String, dynamic>);
    } catch (e) {
      throw Exception('Failed to send message: $e');
    }
  }
}