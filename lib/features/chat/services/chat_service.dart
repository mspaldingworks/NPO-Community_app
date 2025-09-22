import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:transconnect/models/conversation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:transconnect/core/services/auth_service.dart';
import 'package:transconnect/models/chat_message.dart';
import 'package:transconnect/core/services/api_client.dart';

class ChatService extends ApiClient {
  final AuthService _authService = AuthService();
  WebSocketChannel? _channel;
  final StreamController<ChatMessage> _messageController = StreamController.broadcast();

  Stream<ChatMessage> get messages => _messageController.stream;

  Future<List<Conversation>> fetchConversations() async {
    final token = _authService.currentUser?.token;
    if (token == null) {
      throw Exception('User not authenticated');
    }

    final response = await read(
      urlPath: '/api/messages/',
      jsonHeaders: {'Authorization': 'Token $token'},
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data.map((json) => Conversation.fromJson(json)).toList();
    } else {
      throw Exception('Failed to load conversations');
    }
  }

  Future<List<ChatMessage>> fetchMessages(String conversationId) async {
    final token = _authService.currentUser?.token;
    if (token == null) {
      throw Exception('User not authenticated');
    }

    final response = await read(
      urlPath: '/api/messages/$conversationId/messages/',
      jsonHeaders: {'Authorization': 'Token $token'},
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data.map((json) => ChatMessage.fromJson(json)).toList();
    } else {
      throw Exception('Failed to load messages');
    }
  }

  void connect(String conversationId) {
    final token = _authService.currentUser?.token;
    if (token == null) {
      throw Exception('User not authenticated');
    }

    // Construct the WebSocket URL
    // Assumes the WebSocket endpoint is at /ws/messages/{conversationId}/
    // and accepts the token as a query parameter.
    final uri = Uri.parse('wss://api.luxashome.com/ws/messages/$conversationId/?token=$token');

    _channel = WebSocketChannel.connect(uri);

    _channel!.stream.listen(
      (data) {
        try {
          final jsonData = jsonDecode(data);
          // Assuming the backend broadcasts the full message object directly.
          final message = ChatMessage.fromJson(jsonData);
          _messageController.add(message);
        } catch (e) {
          debugPrint('Error parsing incoming message: $e');
        }
      },
      onError: (error) {
        debugPrint('WebSocket Error: $error');
        // Optionally, handle reconnection logic here.
      },
      onDone: () {
        debugPrint('WebSocket connection closed');
        // Optionally, handle cleanup or reconnection here.
      },
    );
  }

  // Sends a message via WebSocket for real-time communication
  void sendMessage(String content) {
    if (_channel != null) {
      // This format is more typical for a Django Channels consumer,
      // which uses the 'type' field to route the message.
      final message = {
        'type': 'chat.message',
        'message': content,
      };
      _channel!.sink.add(jsonEncode(message));
    }
  }

  // Sends a message via POST request
  Future<ChatMessage> sendMessageWithPost(
      {required String conversationId, required String content}) async {
    final token = _authService.currentUser?.token;
    if (token == null) {
      throw Exception('User not authenticated');
    }

    final response = await post(
      urlPath: '/api/messages/$conversationId/messages/',
      jsonHeaders: {
        'Content-Type': 'application/json',
        'Authorization': 'Token $token'
      },
      jsonPayload: {'content': content},
    );

    if (response.statusCode == 201) {
      return ChatMessage.fromJson(json.decode(response.body));
    } else {
      throw Exception('Failed to send message. Status code: ${response.statusCode}');
    }
  }

  Future<Conversation> createConversation({required List<int> userIds}) async {
    final token = _authService.currentUser?.token;
    if (token == null) {
      throw Exception('User not authenticated');
    }

    final response = await post(
      urlPath: '/api/messages/',
      jsonHeaders: {
        'Content-Type': 'application/json',
        'Authorization': 'Token $token'
      },
      jsonPayload: {'participants': userIds},
    );

    if (response.statusCode == 201) {
      return Conversation.fromJson(json.decode(response.body));
    } else {
      throw Exception('Failed to create conversation. Status code: ${response.statusCode}');
    }
  }

  void dispose() {
    _channel?.sink.close();
    _messageController.close();
  }
}
