class ChatMessage {
  final String id;
  final String senderId;
  final String content;
  final DateTime timestamp;

  ChatMessage({
    required this.id,
    required this.senderId,
    required this.content,
    required this.timestamp,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'] as String,
      senderId: json['sender'] as String,
      content: json['content'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
    );
  }
}
