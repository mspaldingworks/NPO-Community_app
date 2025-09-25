// DO NOT CHANGE THIS FILE ANY CHANGE NEEDS A CORROSPONDING API CHANGE DONE BY PAIGE

/// Represents the nested user object within a ChatMessage.
class MessageUser {
  final int id;
  final String username;

  MessageUser({
    required this.id,
    required this.username,
  });

  factory MessageUser.fromJson(Map<String, dynamic> json) {
    return MessageUser(
      id: json['id'] as int,
      username: json['username'] as String,
    );
  }
}

/// Represents a single message object from the chat API.
class ChatMessage {
  final int id;
  final MessageUser sender;
  final MessageUser recipient;
  final String content;
  final DateTime timestamp;
  final bool isRead;

  ChatMessage({
    required this.id,
    required this.sender,
    required this.recipient,
    required this.content,
    required this.timestamp,
    required this.isRead,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'] as int,
      // Parse the nested user objects using the MessageUser model
      sender: MessageUser.fromJson(json['sender'] as Map<String, dynamic>),
      recipient: MessageUser.fromJson(json['recipient'] as Map<String, dynamic>),
      content: json['content'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      isRead: json['is_read'] as bool,
    );
  }
}