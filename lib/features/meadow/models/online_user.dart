import 'package:flutter/material.dart';

class OnlineUser {
  OnlineUser({
    required this.id,
    required this.name,
    required this.pronounSlots,
    required this.position,
    required this.lastSeen,
    this.isCurrentUser = false,
  });

  final String id;
  final String name;
  final List<String> pronounSlots;
  final Offset position;
  final DateTime lastSeen;
  final bool isCurrentUser;

  OnlineUser copyWith({
    String? id,
    String? name,
    List<String>? pronounSlots,
    Offset? position,
    DateTime? lastSeen,
    bool? isCurrentUser,
  }) {
    return OnlineUser(
      id: id ?? this.id,
      name: name ?? this.name,
      pronounSlots: pronounSlots ?? this.pronounSlots,
      position: position ?? this.position,
      lastSeen: lastSeen ?? this.lastSeen,
      isCurrentUser: isCurrentUser ?? this.isCurrentUser,
    );
  }
}
