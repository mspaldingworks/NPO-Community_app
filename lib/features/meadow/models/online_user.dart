import 'package:flutter/material.dart';

class OnlineUser {
  OnlineUser({
    required this.id,
    required this.name,
    required this.pronounSlots,
    required this.position,
    required this.lastSeen,
    this.activeChatId,
    this.isCurrentUser = false,
  });

  final String id;
  final String name;
  final List<String> pronounSlots;
  final Offset position;
  final DateTime lastSeen;
  final String? activeChatId;
  final bool isCurrentUser;

  OnlineUser copyWith({
    String? id,
    String? name,
    List<String>? pronounSlots,
    Offset? position,
    DateTime? lastSeen,
    String? activeChatId,
    bool? isCurrentUser,
  }) {
    return OnlineUser(
      id: id ?? this.id,
      name: name ?? this.name,
      pronounSlots: pronounSlots ?? this.pronounSlots,
      position: position ?? this.position,
      lastSeen: lastSeen ?? this.lastSeen,
      activeChatId: activeChatId ?? this.activeChatId,
      isCurrentUser: isCurrentUser ?? this.isCurrentUser,
    );
  }
}
