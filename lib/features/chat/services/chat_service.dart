import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:transconnect/core/services/chat_service.dart' as core;
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:transconnect/core/services/auth_service.dart';
import 'package:transconnect/models/chat_message.dart';
import 'package:transconnect/core/services/api_client.dart';

class ChatService extends ApiClient {
  final AuthService _authService = AuthService();
  final core.ChatService _coreChatService = core.ChatService(); // Use the aliased core service
  WebSocketChannel? _channel;
  final StreamController<ChatMessage> _messageController = StreamController.broadcast();

  Stream<ChatMessage> get messages => _messageController.stream;

  Future<List<core.ConversationPreview>> fetchConversations() async {
    return _coreChatService.getAllConversations();
  }

  Future<List<ChatMessage>> fetchMessages(int otherUserId) async {
    return _coreChatService.getConversation(otherUserId);
  }

  void connect(String conversationId) {
    final token = _authService.currentUser?.token;
    if (token == null) {
      throw Exception('User not authenticated');
    }

    final uri = Uri.parse('wss://api.luxashome.com/ws/chat/$conversationId/?token=$token');

    _channel = WebSocketChannel.connect(uri);

    _channel!.stream.listen(
      (data) {
        try {
          final jsonData = jsonDecode(data);
          final message = ChatMessage.fromJson(jsonData);
          _messageController.add(message);
        } catch (e) {
          debugPrint('Error parsing incoming message: $e');
        }
      },
      onError: (error) {
        debugPrint('WebSocket Error: $error');
      },
      onDone: () {
        debugPrint('WebSocket connection closed');
      },
    );
  }

  void sendMessage(String content) {
    if (_channel != null) {
      final message = {
        'type': 'chat.message',
        'message': content,
      };
      _channel!.sink.add(jsonEncode(message));
    }
  }

  Future<ChatMessage> sendMessageWithPost(
      {required int recipientId, required String content}) async {
    return _coreChatService.sendMessage(recipientId: recipientId, content: content);
  }

  Future<ChatMessage> createConversation({required int userId, required String content}) async {
    // The API doesn't have a dedicated "create conversation" endpoint.
    // Sending the first message implicitly creates it.
    return _coreChatService.sendMessage(recipientId: userId, content: content);
  }

  void dispose() {
    _channel?.sink.close();
    _messageController.close();
  }
}
