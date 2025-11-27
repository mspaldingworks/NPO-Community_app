import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

import 'package:collection/collection.dart';
import 'package:logging/logging.dart';
import 'package:transconnect/core/constants/api_endpoints.dart';
import 'package:transconnect/core/services/api_client.dart';
import 'package:transconnect/models/chat_message.dart';
import 'package:transconnect/models/ws_message.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/status.dart' as status;
import 'package:web_socket_channel/web_socket_channel.dart';

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

/// Service class for all chat and messaging related API calls and WebSocket connections.
class ChatService extends ApiClient {
  static const _reconnectDelay = Duration(seconds: 5);
  static const _maxReconnectAttempts = 5;
  
  final _logger = Logger('ChatService');
  
  // WebSocket channels by channel ID
  final Map<String, WebSocketChannel> _channels = {};
  
  // Stream controllers for real-time updates by channel ID
  final Map<String, StreamController<WSMessage>> _messageControllers = {};
  
  // Reconnection state
  final Map<String, int> _reconnectAttempts = {};
  final Map<String, Timer> _reconnectTimers = {};
  
  // Typing indicators by channel ID
  final Map<String, Set<int>> _typingUsers = {};
  
  // Message subscriptions by channel ID
  final Map<String, StreamSubscription> _subscriptions = {};
  
  // Callback for when connection status changes
  void Function(String channelId, bool isConnected)? onConnectionStatusChanged;
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

  /// Sends a new message to the specified recipient.
  ///
  /// Endpoint: POST /api/messages/
  /// Payload: {"recipient": 1, "content": "Hello..."}
  Future<void> sendMessage({required int recipientId, required String content}) async {
    const urlPath = '$_messagesBaseUrl/';
    final payload = {
      'recipient': recipientId, 
      'content': content,
    };
    
    try {
      await post(
        urlPath: urlPath,
        jsonHeaders: authHeaders,
        jsonPayload: payload,
        expectedStatusCode: 201, 
      );
    } catch (e) {
      throw Exception('Failed to send message to user $recipientId: $e');
    }
  }

  Future<void> sendMessageMultipart({
    required int recipientId,
    String content = '',
    String? imageFilePath,
  }) async {
    final uri = Uri.parse('${ApiEndpoints.host}/api/messages/');
    final request = http.MultipartRequest('POST', uri)
      ..headers['Authorization'] = 'Token $authToken'
      ..fields['recipient'] = recipientId.toString()
      ..fields['content'] = content;

    if (imageFilePath != null && imageFilePath.isNotEmpty) {
      request.files.add(await http.MultipartFile.fromPath('image', imageFilePath));
    }

    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);
    if (response.statusCode != 201) {
      throw Exception('Failed to send message: ${response.statusCode} ${response.body}');
    }
  }
  /// Fetches all messages for a specific channel
  ///
  /// GET /api/chat/{channelId}/messages
  /// 
  /// [channelId] The ID of the channel to fetch messages for
  /// [limit] Maximum number of messages to return
  /// [before] Return only messages before this message ID (for pagination)
  Future<List<ChatMessage>> getChannelMessages(
    String channelId, {
    int? limit,
    int? before,
  }) async {
    try {
      var urlPath = 'api/chat/$channelId/messages';
      final queryParams = <String, dynamic>{};
      
      if (limit != null) queryParams['limit'] = limit;
      if (before != null) queryParams['before'] = before;
      
      if (queryParams.isNotEmpty) {
        final queryString = Uri(queryParameters: queryParams).query;
        urlPath = '$urlPath?$queryString';
      }
      
      final response = await read(
        urlPath: urlPath,
        jsonHeaders: authHeaders,
      );
      
      if (response is List) {
        return response
            .map<ChatMessage>((json) => 
                ChatMessage.fromJson(json as Map<String, dynamic>))
            .toList();
      }
      
      throw const FormatException('Expected a list of messages');
    } catch (e, stackTrace) {
      _logger.severe(
        'Failed to fetch messages for channel $channelId',
        e,
        stackTrace,
      );
      rethrow;
    }
  }

  /// Sends a new message to a specific channel
  ///
  /// POST /api/chat/{channelId}/messages
  /// 
  /// [channelId] The ID of the channel to send the message to
  /// [content] The message content
  /// [tempId] Optional temporary ID for optimistic UI updates
  Future<ChatMessage> sendChannelMessage({
    required String channelId,
    required String content,
    String? tempId,
  }) async {
    final urlPath = 'api/chat/$channelId/messages';
    
    try {
      final response = await post(
        urlPath: urlPath,
        jsonHeaders: authHeaders,
        jsonPayload: {
          'content': content,
          if (tempId != null) 'temp_id': tempId,
        },
        expectedStatusCode: 201,
      );
      
      if (response is Map<String, dynamic>) {
        return ChatMessage.fromJson(response);
      }
      
      throw const FormatException('Invalid response format when sending message');
    } catch (e, stackTrace) {
      _logger.severe(
        'Failed to send message to channel $channelId',
        e,
        stackTrace,
      );
      rethrow;
    }
  }

  /// Connects to a WebSocket for real-time chat updates
  ///
  /// wss://api.luxashome.com/ws/chat/{channelId}/
  /// 
  /// [channelId] The ID of the channel to connect to
  /// [autoReconnect] Whether to automatically attempt to reconnect if the connection is lost
  Stream<WSMessage> connectToChatChannel(
    String channelId, {
    bool autoReconnect = true,
  }) {
    // Close existing connection if any
    _disconnectChannel(channelId, notify: false);
    
    // Cancel any pending reconnection
    _cancelReconnect(channelId);
    
    // Reset reconnect attempts
    _reconnectAttempts[channelId] = 0;
    
    try {
      // Create new WebSocket connection
      final wsUrl = 'wss://api.luxashome.com/ws/chat/$channelId/';
      final channel = IOWebSocketChannel.connect(
        Uri.parse(wsUrl),
        protocols: [
          'authorization',
          'Bearer ${authToken.replaceAll('Token ', '')}',
        ],
      );
      
      // Store the channel
      _channels[channelId] = channel;
      
      // Create a new stream controller if one doesn't exist
      _messageControllers.putIfAbsent(
        channelId,
        () => StreamController<WSMessage>.broadcast(
          onCancel: () => _disconnectChannel(channelId),
        ),
      );
      
      // Notify connection established
      onConnectionStatusChanged?.call(channelId, true);
      
      // Listen to WebSocket messages
      _subscriptions[channelId] = channel.stream.listen(
        (message) {
          try {
            final wsMessage = WSMessage.fromJsonString(message as String);
            _handleIncomingMessage(channelId, wsMessage);
          } catch (e, stackTrace) {
            _logger.severe('Error processing WebSocket message', e, stackTrace);
            _messageControllers[channelId]?.addError(e, stackTrace);
          }
        },
        onError: (error, stackTrace) {
          _logger.severe('WebSocket error for channel $channelId', error, stackTrace);
          _messageControllers[channelId]?.addError(error, stackTrace);
          _handleDisconnect(channelId, autoReconnect);
        },
        onDone: () {
          _logger.info('WebSocket closed for channel $channelId');
          _handleDisconnect(channelId, autoReconnect);
        },
        cancelOnError: false,
      );
      
      return _messageControllers[channelId]!.stream;
    } catch (e, stackTrace) {
      _logger.severe('Failed to connect to WebSocket', e, stackTrace);
      _handleDisconnect(channelId, autoReconnect);
      rethrow;
    }
  }
  
  /// Handles incoming WebSocket messages
  void _handleIncomingMessage(String channelId, WSMessage message) {
    if (message.isTyping) {
      // Handle typing indicator
      final userId = message.data['user_id'] as int?;
      final isTyping = message.data['is_typing'] as bool? ?? false;
      
      if (userId != null) {
        _typingUsers.putIfAbsent(channelId, () => <int>{});
        
        if (isTyping) {
          _typingUsers[channelId]!.add(userId);
          // Automatically remove typing indicator after 5 seconds
          Timer(const Duration(seconds: 5), () {
            _typingUsers[channelId]?.remove(userId);
          });
        } else {
          _typingUsers[channelId]?.remove(userId);
        }
      }
    }
    
    // Forward the message to listeners
    _messageControllers[channelId]?.add(message);
  }
  
  /// Handles WebSocket disconnection
  void _handleDisconnect(String channelId, bool autoReconnect) {
    _disconnectChannel(channelId);
    
    if (autoReconnect) {
      _scheduleReconnect(channelId);
    }
  }
  
  /// Schedules a reconnection attempt
  void _scheduleReconnect(String channelId) {
    _cancelReconnect(channelId);
    
    final attempts = _reconnectAttempts[channelId] ?? 0;
    if (attempts >= _maxReconnectAttempts) {
      _logger.warning('Max reconnection attempts reached for channel $channelId');
      return;
    }
    
    _reconnectAttempts[channelId] = attempts + 1;
    final delay = Duration(
      milliseconds: _reconnectDelay.inMilliseconds * (attempts + 1),
    );
    
    _logger.info(
      'Scheduling reconnection attempt ${attempts + 1} for channel $channelId in ${delay.inSeconds}s',
    );
    
    _reconnectTimers[channelId] = Timer(delay, () {
      _reconnectTimers.remove(channelId);
      connectToChatChannel(channelId, autoReconnect: true);
    });
  }
  
  /// Cancels a pending reconnection attempt
  void _cancelReconnect(String channelId) {
    _reconnectTimers[channelId]?.cancel();
    _reconnectTimers.remove(channelId);
  }
  
  /// Disconnects from a WebSocket channel
  /// 
  /// [channelId] The ID of the channel to disconnect from
  /// [notify] Whether to notify listeners about the disconnection
  void disconnectFromChatChannel(String channelId, {bool notify = true}) {
    _disconnectChannel(channelId, notify: notify);
  }
  
  /// Internal method to disconnect from a channel
  void _disconnectChannel(String channelId, {bool notify = true}) {
    _cancelReconnect(channelId);
    
    // Close the WebSocket connection
    try {
      _channels[channelId]?.sink.close(
        status.goingAway,
        'Client disconnected',
      );
    } catch (e) {
      _logger.warning('Error closing WebSocket for channel $channelId', e);
    } finally {
      _channels.remove(channelId);
    }
    
    // Close the subscription
    _subscriptions[channelId]?.cancel();
    _subscriptions.remove(channelId);
    
    // Notify listeners if requested
    if (notify) {
      onConnectionStatusChanged?.call(channelId, false);
    }
  }
  
  /// Sends a typing indicator to the specified channel
  /// 
  /// [channelId] The ID of the channel to send the typing indicator to
  /// [isTyping] Whether the user is typing or not
  Future<void> sendTypingIndicator(String channelId, bool isTyping) async {
    final channel = _channels[channelId];
    if (channel == null) return;
    
    try {
      final message = WSMessage(
        type: WSMessageType.typing,
        data: {'is_typing': isTyping},
      );
      
      channel.sink.add(message.toJsonString());
    } catch (e, stackTrace) {
      _logger.severe('Failed to send typing indicator', e, stackTrace);
      rethrow;
    }
  }
  
  /// Gets the list of user IDs who are currently typing in the specified channel
  /// 
  /// [channelId] The ID of the channel to get typing users for
  Set<int> getTypingUsers(String channelId) {
    return Set.from(_typingUsers[channelId] ?? const {});
  }
  
  /// Sends a read receipt for a message
  /// 
  /// [channelId] The ID of the channel the message is in
  /// [messageId] The ID of the message to mark as read
  Future<void> sendReadReceipt(String channelId, int messageId) async {
    final channel = _channels[channelId];
    if (channel == null) return;
    
    try {
      final message = WSMessage(
        type: WSMessageType.readReceipt,
        data: {'message_id': messageId},
      );
      
      channel.sink.add(message.toJsonString());
    } catch (e, stackTrace) {
      _logger.severe('Failed to send read receipt', e, stackTrace);
      rethrow;
    }
  }
  
  /// Checks if the WebSocket is connected for a channel
  bool isConnected(String channelId) => _channels.containsKey(channelId);
  
  /// Cleans up all WebSocket connections
  void dispose() {
    // Close all WebSocket connections
    for (final channelId in _channels.keys.toList()) {
      _disconnectChannel(channelId, notify: false);
    }
    
    // Cancel all timers
    for (final timer in _reconnectTimers.values) {
      timer.cancel();
    }
    _reconnectTimers.clear();
    
    _channels.clear();
    
    // Cancel all subscriptions
    for (final subscription in _subscriptions.values) {
      subscription.cancel();
    }
    _subscriptions.clear();
    
    // Close all stream controllers
    for (final controller in _messageControllers.values) {
      try {
        if (!controller.isClosed) {
          controller.close();
        }
      } catch (e) {
        _logger.warning('Error closing stream controller', e);
      }
    }
    _messageControllers.clear();
    
    // Clear other state
    _typingUsers.clear();
    _reconnectAttempts.clear();
  }
}