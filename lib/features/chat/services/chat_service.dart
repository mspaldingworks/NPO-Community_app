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
      urlPath: '/api/chat/conversations/',
      jsonHeaders: {'Authorization': 'Token $token'},
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data.map((json) => Conversation.fromJson(json)).toList();
    } else {
      throw Exception('Failed to load conversations');
    }
  }

  void connect(String conversationId) {
    final token = _authService.currentUser?.token;
    if (token == null) {
      throw Exception('User not authenticated');
    }

    // Construct the WebSocket URL
    // Assumes the WebSocket endpoint is at /ws/chat/{conversationId}/
    // and accepts the token as a query parameter.
    final uri = Uri.parse('ws://api.luxashome.com/ws/chat/$conversationId/?token=$token');

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

  void dispose() {
    _channel?.sink.close();
    _messageController.close();
  }
}
