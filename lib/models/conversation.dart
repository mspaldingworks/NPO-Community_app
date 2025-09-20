import 'package:transconnect/models/chat_message.dart';

class Conversation {
  final String id;
  final List<String> participants; // For now, just a list of user IDs/names
  final ChatMessage? lastMessage;

  Conversation({
    required this.id,
    required this.participants,
    this.lastMessage,
  });

  factory Conversation.fromJson(Map<String, dynamic> json) {
    var participantsList = json['participants'] as List? ?? [];
    List<String> participants = participantsList.map((i) => i.toString()).toList();

    return Conversation(
      id: json['id'] as String,
      participants: participants,
      lastMessage: json['last_message'] != null
          ? ChatMessage.fromJson(json['last_message'])
          : null,
    );
  }
}
