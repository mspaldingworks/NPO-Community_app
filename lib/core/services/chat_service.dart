import 'dart:async';

import 'package:transconnect/features/community/models/message_model.dart';

class ChatService {
  // TODO: Implement with api.luxashome.com

  /// Fetches historical messages for a given channel.
  Future<List<Message>> fetchMessages(String channelId) async {
    // TODO: Implement with api.luxashome.com
    return [];
  }

  /// Sends a new message to a channel.
  Future<void> sendMessage({
    required String channelId,
    required String content,
  }) async {
    // TODO: Implement with api.luxashome.com
  }

  /// Subscribes to new messages for a given channel.
  Stream<Message> subscribeToNewMessages(String channelId) {
    // TODO: Implement with api.luxashome.com
    return Stream.empty();
  }
}
