import 'package:transconnect/core/services/api_client.dart'; // Import for ApiClient
// Assuming the updated ChatMessage and the required MessageUser are in this file:
import 'package:transconnect/models/chat_message.dart'; 

// --- Helper Model for API Response Mapping ---

/// Represents the other user in a conversation, as returned by the 
/// 'active_conversations' API endpoint. (This maps directly to the API's 
/// output: [{"id": 2, "username": "alice"}, ...])
class ConversationPreview {
  final int id;
  final String username;

  ConversationPreview({
    required this.id,
    required this.username,
  });

  factory ConversationPreview.fromJson(Map<String, dynamic> json) {
    return ConversationPreview(
      id: json['id'] as int,
      username: json['username'] as String,
    );
  }
}

// --- Service Implementation ---

/// Service class for all chat and messaging related API calls.
class ChatService extends ApiClient {
  static const String _messagesBaseUrl = 'api/messages';

  // Function 1: Get all current conversations
  /// Fetches a list of all current conversations, returning the other user's
  /// ID and username for each.
  /// 
  /// Endpoint: GET /api/messages/active_conversations/
  /// Returns: List<ConversationPreview>
  Future<List<ConversationPreview>> getAllConversations() async {
    const urlPath = '$_messagesBaseUrl/active_conversations/';
    try {
      final responseData = await read(urlPath: urlPath, jsonHeaders: authHeaders);
      
      if (responseData is List) {
        // Map the list of JSON objects to ConversationPreview objects
        return responseData
            .map((json) => ConversationPreview.fromJson(json as Map<String, dynamic>))
            .toList();
      }
      
      throw const FormatException('Expected a list for active conversations.');
    } catch (e) {
      // Re-throw the exception with context
      throw Exception('Failed to fetch active conversations: $e');
    }
  }

  // Function 2: Get a conversation's history
  /// Fetches the entirety of a conversation between the current user and 
  /// the user with the given [otherUserId].
  /// 
  /// Endpoint: GET /api/messages/messages_between/?user_id={otherUserId}
  /// Returns: List<ChatMessage>
  Future<List<ChatMessage>> getConversation(int otherUserId) async {
    // Construct the URL path with the user_id query parameter
    final urlPath = '$_messagesBaseUrl/messages_between/?user_id=$otherUserId';
    try {
      final responseData = await read(urlPath: urlPath, jsonHeaders: authHeaders);

      if (responseData is List) {
        // Map the list of JSON message objects to the new ChatMessage objects
        // The new ChatMessage model internally handles the nested 'sender' and 'recipient'
        return responseData
            .map((json) => ChatMessage.fromJson(json as Map<String, dynamic>))
            .toList();
      }

      throw const FormatException('Expected a list of messages for the conversation.');
    } catch (e) {
      // Re-throw the exception with context
      throw Exception('Failed to fetch conversation with user $otherUserId: $e');
    }
  }

  // New Function: Send Message
  /// Sends a new message to the specified recipient.
  ///
  /// Endpoint: POST /api/messages/
  /// Payload: {"recipient": 1, "content": "Hello..."}
  Future<void> sendMessage({required int recipientId, required String content}) async {
    const urlPath = '$_messagesBaseUrl/';
    final payload = {
      // The API expects the ID of the person receiving the message
      'recipient': recipientId, 
      'content': content,
    };
    
    try {
      // Typically, resource creation uses HTTP status code 201 (Created).
      // We assume your API returns 201 on successful message creation.
      await post(
        urlPath: urlPath,
        jsonHeaders: authHeaders,
        jsonPayload: payload,
        expectedStatusCode: 201, 
      );
      // The function returns void upon successful send (HTTP 201)
    } catch (e) {
      // Re-throw the exception with context for the UI/Business Logic layer
      throw Exception('Failed to send message to user $recipientId: $e');
    }
  }
}