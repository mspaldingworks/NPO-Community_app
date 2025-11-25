// DO NOT CHANGE THIS FILE ANY CHANGE NEEDS A CORROSPONDING API CHANGE DONE BY PAIGE

import 'dart:convert';

/// Represents the nested user object within a ChatMessage.
class MessageUser {
  final int id;
  final String username;
  final String? profilePic;
  final String? firstName;
  final String? lastName;

  MessageUser({
    required this.id,
    required this.username,
    this.profilePic,
    this.firstName,
    this.lastName,
  });

  factory MessageUser.fromJson(Map<String, dynamic> json) {
    return MessageUser(
      id: json['id'] as int,
      username: json['username'] as String? ?? 'Unknown',
      profilePic: json['profile_pic'] as String?,
      firstName: json['first_name'] as String?,
      lastName: json['last_name'] as String?,
    );
  }

  // Factory to handle cases where only a user ID is provided.
  factory MessageUser.fromId(int id) {
    return MessageUser(id: id, username: 'User $id');
  }

  String get displayName => [firstName, lastName].where((n) => n != null && n.isNotEmpty).join(' ').trim();

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      if (profilePic != null) 'profile_pic': profilePic,
      if (firstName != null) 'first_name': firstName,
      if (lastName != null) 'last_name': lastName,
    };
  }
}

/// Represents a single message object from the chat API.
class ChatMessage {
  final String id;
  final MessageUser sender;
  final String content;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  bool isRead;
  final String? conversationId;
  final String? messageType;
  final Map<String, dynamic>? metadata;
  final MessageUser? replyTo;

  ChatMessage({
    required this.id,
    required this.sender,
    required this.content,
    this.createdAt,
    this.updatedAt,
    this.isRead = false,
    this.conversationId,
    this.messageType = 'text',
    this.metadata,
    this.replyTo,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    // Helper to robustly parse user data which might be a map or just an ID.
    MessageUser _parseUser(dynamic userData) {
      if (userData is Map<String, dynamic>) {
        return MessageUser.fromJson(userData);
      } else if (userData is int) {
        return MessageUser.fromId(userData);
      }
      throw ArgumentError('Invalid user data format');
    }

    return ChatMessage(
      id: json['id']?.toString() ?? DateTime
          .now()
          .millisecondsSinceEpoch
          .toString(),
      sender: _parseUser(json['sender']),
      content: json['content'] as String? ?? '',
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())?.toLocal()
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'].toString())?.toLocal()
          : null,
      isRead: json['is_read'] as bool? ?? false,
      conversationId: json['conversation_id']?.toString(),
      messageType: json['message_type'] as String? ?? 'text',
      metadata: json['metadata'] is Map ? Map<String, dynamic>.from(
          json['metadata']) : null,
      replyTo: json['reply_to'] != null ? _parseUser(json['reply_to']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'sender': sender.toJson(),
      'content': content,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
      if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
      'is_read': isRead,
      if (conversationId != null) 'conversation_id': conversationId,
      'message_type': messageType,
      if (metadata != null) 'metadata': metadata,
      if (replyTo != null) 'reply_to': replyTo!.toJson(),
    };
  }

  String toJsonString() => jsonEncode(toJson());

  ChatMessage copyWith({
    String? id,
    MessageUser? sender,
    String? content,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isRead,
    String? conversationId,
    String? messageType,
    Map<String, dynamic>? metadata,
    MessageUser? replyTo,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      sender: sender ?? this.sender,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isRead: isRead ?? this.isRead,
      conversationId: conversationId ?? this.conversationId,
      messageType: messageType ?? this.messageType,
      metadata: metadata ?? this.metadata,
      replyTo: replyTo ?? this.replyTo,
    );
  }

  // Helper method to create a reply message
  ChatMessage createReply(String content, MessageUser currentUser) {
    return ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      sender: currentUser,
      content: content,
      replyTo: sender,
      conversationId: conversationId,
      messageType: 'reply',
    );
  }

  // Check if this is a reply to another message
  bool get isReply => replyTo != null;

  // Get the display time for the message
  String get displayTime {
    if (createdAt == null) return '';

    final now = DateTime.now();
    final difference = now.difference(createdAt!);

    if (difference.inDays > 0) {
      return '${createdAt!.day}/${createdAt!.month}/${createdAt!.year}';
    } else {
      return '${createdAt!.hour.toString().padLeft(2, '0')}:${createdAt!.minute.toString().padLeft(2, '0')}';
    }
  }
}