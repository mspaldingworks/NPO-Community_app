import 'package:flutter/material.dart';

class MeadowChatFlower {
  MeadowChatFlower({
    required this.id,
    required this.emoji,
    required this.topic,
    required this.position,
    required this.createdBy,
    required this.expiresAt,
    required this.participantCount,
  });

  final String id;
  final String emoji;
  final String topic;
  final Offset position;
  final String createdBy;
  final DateTime expiresAt;
  final int participantCount;

  MeadowChatFlower copyWith({
    String? id,
    String? emoji,
    String? topic,
    Offset? position,
    String? createdBy,
    DateTime? expiresAt,
    int? participantCount,
  }) {
    return MeadowChatFlower(
      id: id ?? this.id,
      emoji: emoji ?? this.emoji,
      topic: topic ?? this.topic,
      position: position ?? this.position,
      createdBy: createdBy ?? this.createdBy,
      expiresAt: expiresAt ?? this.expiresAt,
      participantCount: participantCount ?? this.participantCount,
    );
  }
}
