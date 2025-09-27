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
      username: json['username'] as String? ?? 'Unknown',
    );
  }

  // Factory to handle cases where only a user ID is provided.
  factory MessageUser.fromId(int id) {
    return MessageUser(id: id, username: '...'); // Placeholder username
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
    // Helper to robustly parse user data which might be a map or just an ID.
    MessageUser _parseUser(dynamic userData) {
      if (userData is Map<String, dynamic>) {
        return MessageUser.fromJson(userData);
      } else if (userData is int) {
        return MessageUser.fromId(userData);
      }
      // Fallback for unexpected format
      return MessageUser(id: 0, username: 'Unknown');
    }

    return ChatMessage(
      id: json['id'] as int,
      sender: _parseUser(json['sender']),
      recipient: _parseUser(json['recipient']),
      content: json['content'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      isRead: json['is_read'] as bool? ?? false, // Safely handle is_read
    );
  }
}