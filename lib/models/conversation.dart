import 'package:transconnect/models/user.dart';
import 'package:transconnect/models/chat_message.dart';

class Conversation {
  final String id;
  final String? name;
  final List<User> participants;
  final ChatMessage? lastMessage;
  final DateTime? lastMessageAt;
  final bool isGroup;
  final String? groupImage;
  final User? createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int unreadCount;
  final bool isMuted;

  Conversation({
    required this.id,
    this.name,
    required this.participants,
    this.lastMessage,
    this.lastMessageAt,
    this.isGroup = false,
    this.groupImage,
    this.createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
    int unreadCount = 0,
    bool isMuted = false,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now(),
        unreadCount = unreadCount,
        isMuted = isMuted;

  factory Conversation.fromJson(Map<String, dynamic> json) {
    return Conversation(
      id: json['id'] as String,
      name: json['name'] as String?,
      participants: (json['participants'] as List<dynamic>?)
              ?.map((userJson) => User.fromJson(userJson as Map<String, dynamic>))
              .toList() ??
          [],
      lastMessage: json['last_message'] != null
          ? ChatMessage.fromJson(
              json['last_message'] as Map<String, dynamic>,
            )
          : null,
      lastMessageAt: json['last_message_at'] != null
          ? DateTime.parse(json['last_message_at'] as String)
          : null,
      isGroup: json['is_group'] as bool? ?? false,
      groupImage: json['group_image'] as String?,
      createdBy: json['created_by'] != null
          ? User.fromJson(json['created_by'] as Map<String, dynamic>)
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
      unreadCount: json['unread_count'] is int
          ? json['unread_count'] as int
          : int.tryParse(json['unread_count']?.toString() ?? '') ?? 0,
      isMuted: json['is_muted'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    List<Map<String, dynamic>> participantMaps = participants
        .map((user) => {
              'id': user.id,
              'username': user.username,
              'email': user.email,
            })
        .toList();

    return {
      'id': id,
      if (name != null) 'name': name,
      'participants': participantMaps,
      if (lastMessage != null) 'last_message': lastMessage!,
      if (lastMessageAt != null) 'last_message_at': lastMessageAt!.toIso8601String(),
      'is_group': isGroup,
      if (groupImage != null) 'group_image': groupImage,
      if (createdBy != null)
        'created_by': {
          'id': createdBy!.id,
          'username': createdBy!.username,
          'email': createdBy!.email,
        },
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'unread_count': unreadCount,
      'is_muted': isMuted,
    };
  }

  Conversation copyWith({
    String? id,
    String? name,
    List<User>? participants,
    ChatMessage? lastMessage,
    DateTime? lastMessageAt,
    bool? isGroup,
    String? groupImage,
    User? createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? unreadCount,
    bool? isMuted,
  }) {
    return Conversation(
      id: id ?? this.id,
      name: name ?? this.name,
      participants: participants ?? this.participants,
      lastMessage: lastMessage ?? this.lastMessage,
      lastMessageAt: lastMessageAt ?? this.lastMessageAt,
      isGroup: isGroup ?? this.isGroup,
      groupImage: groupImage ?? this.groupImage,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      unreadCount: unreadCount ?? this.unreadCount,
      isMuted: isMuted ?? this.isMuted,
    );
  }
}
