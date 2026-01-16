import 'dart:async';

import 'package:flutter/material.dart';
import 'package:transconnect/features/meadow/models/meadow_chat_flower.dart';
import 'package:transconnect/features/meadow/models/online_user.dart';

abstract class MeadowRepository {
  Stream<List<OnlineUser>> watchOnlineUsers();
  Stream<List<MeadowChatFlower>> watchChatFlowers();

  Future<MeadowChatFlower> createChat({
    required String topic,
    required String createdBy,
    required String createdByUserId,
    required Offset position,
    String? description,
  });

  Future<void> joinChat({required String chatId, required String userId});

  Future<void> leaveChat({required String chatId, required String userId});

  Future<void> reportChat({
    required String chatId,
    required String reason,
    String? note,
  });
}

class InMemoryMeadowRepository implements MeadowRepository {
  InMemoryMeadowRepository._();

  static final InMemoryMeadowRepository instance = InMemoryMeadowRepository._();

  final _usersController = StreamController<List<OnlineUser>>.broadcast();
  final _flowersController = StreamController<List<MeadowChatFlower>>.broadcast();

  List<OnlineUser> _users = [];
  List<MeadowChatFlower> _flowers = [];
  final Map<String, Set<String>> _participantsByChatId = {};

  bool get hasSeededUsers => _users.isNotEmpty;

  void reset() {
    _users = [];
    _flowers = [];
    _participantsByChatId.clear();
    _usersController.add(_users);
    _flowersController.add(_flowers);
  }

  void seedUsers(List<OnlineUser> users) {
    _users = List.of(users);
    _usersController.add(_users);
  }

  void seedFlowers(List<MeadowChatFlower> flowers) {
    _flowers = List.of(flowers);
    for (final f in flowers) {
      _participantsByChatId.putIfAbsent(f.id, () => <String>{});
    }
    _flowersController.add(_flowers);
  }

  @override
  Stream<List<OnlineUser>> watchOnlineUsers() async* {
    yield _users;
    yield* _usersController.stream;
  }

  @override
  Stream<List<MeadowChatFlower>> watchChatFlowers() async* {
    yield _flowers;
    yield* _flowersController.stream;
  }

  @override
  Future<MeadowChatFlower> createChat({
    required String topic,
    required String createdBy,
    required String createdByUserId,
    required Offset position,
    String? description,
  }) async {
    final chat = MeadowChatFlower(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      topic: topic,
      createdBy: createdBy,
      position: position,
      description: description,
      expiresAt: DateTime.now().add(const Duration(hours: 2)),
      participantCount: 0,
    );

    _flowers = [..._flowers, chat];
    _participantsByChatId[chat.id] = <String>{};
    _flowersController.add(_flowers);

    await joinChat(chatId: chat.id, userId: createdByUserId);

    return _flowers.firstWhere((f) => f.id == chat.id);
  }

  @override
  Future<void> joinChat({required String chatId, required String userId}) async {
    final participants = _participantsByChatId.putIfAbsent(chatId, () => <String>{});
    final didAdd = participants.add(userId);
    if (!didAdd) return;

    _flowers = _flowers
        .map((flower) => flower.id == chatId
            ? flower.copyWith(participantCount: participants.length)
            : flower)
        .toList();
    _flowersController.add(_flowers);
  }

  @override
  Future<void> leaveChat({required String chatId, required String userId}) async {
    final participants = _participantsByChatId[chatId];
    if (participants == null) return;
    participants.remove(userId);

    if (participants.isEmpty) {
      _participantsByChatId.remove(chatId);
      _flowers.removeWhere((f) => f.id == chatId);
      _flowersController.add(_flowers);
      return;
    }

    _flowers = _flowers
        .map((flower) => flower.id == chatId
            ? flower.copyWith(participantCount: participants.length)
            : flower)
        .toList();
    _flowersController.add(_flowers);
  }

  @override
  Future<void> reportChat({
    required String chatId,
    required String reason,
    String? note,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
  }
}
