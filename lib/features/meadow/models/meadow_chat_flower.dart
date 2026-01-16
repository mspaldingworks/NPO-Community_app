import 'package:flutter/material.dart';

class MeadowChatFlower {
  MeadowChatFlower({
    required this.id,
    required this.topic,
    required this.position,
    required this.createdBy,
    required this.expiresAt,
    required this.participantCount,
    this.description,
  });

  final String id;
  final String topic;
  final Offset position;
  final String createdBy;
  final DateTime expiresAt;
  final int participantCount;
  final String? description;

  MeadowChatFlower copyWith({
    String? id,
    String? topic,
    Offset? position,
    String? createdBy,
    DateTime? expiresAt,
    int? participantCount,
    String? description,
  }) {
    return MeadowChatFlower(
      id: id ?? this.id,
      topic: topic ?? this.topic,
      position: position ?? this.position,
      createdBy: createdBy ?? this.createdBy,
      expiresAt: expiresAt ?? this.expiresAt,
      participantCount: participantCount ?? this.participantCount,
      description: description ?? this.description,
    );
  }
}
