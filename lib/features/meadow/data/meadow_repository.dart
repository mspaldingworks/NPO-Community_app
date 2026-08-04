import 'dart:async';

import 'package:flutter/material.dart';
import 'package:npo_community/features/meadow/models/meadow_chat_comment.dart';
import 'package:npo_community/features/meadow/models/meadow_chat_flower.dart';
import 'package:npo_community/features/meadow/models/online_user.dart';

abstract class MeadowRepository {
  Stream<List<OnlineUser>> watchOnlineUsers();
  Stream<List<MeadowChatFlower>> watchChatFlowers();
  Stream<MeadowChatFlower> watchChatCreated();

  Stream<List<MeadowChatComment>> watchChatComments({required String chatId});

  Future<void> addChatComment({
    required String chatId,
    required String authorId,
    required String authorName,
    required String content,
  });

  Future<MeadowChatFlower> createChat({
    required String emoji,
    required String topic,
    required String createdBy,
    required String createdByUserId,
    required Offset position,
    String? initialComment,
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
  final _flowersController =
      StreamController<List<MeadowChatFlower>>.broadcast();
  final _chatCreatedController = StreamController<MeadowChatFlower>.broadcast();

  final Map<String, List<MeadowChatComment>> _commentsByChatId = {};
  final Map<String, StreamController<List<MeadowChatComment>>>
  _commentsControllerByChatId = {};

  Timer? _pruneTimer;

  List<OnlineUser> _users = [];
  List<MeadowChatFlower> _flowers = [];
  final Map<String, Set<String>> _participantsByChatId = {};

  bool get hasSeededUsers => _users.isNotEmpty;

  void reset() {
    _users = [];
    _flowers = [];
    _participantsByChatId.clear();
    _commentsByChatId.clear();
    for (final c in _commentsControllerByChatId.values) {
      try {
        c.close();
      } catch (_) {}
    }
    _commentsControllerByChatId.clear();
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
      _commentsByChatId.putIfAbsent(f.id, () => <MeadowChatComment>[]);
    }
    _flowersController.add(_flowers);

    _ensurePruneTimer();
  }

  void _ensurePruneTimer() {
    _pruneTimer ??= Timer.periodic(
      const Duration(minutes: 1),
      (_) => _pruneExpiredChats(),
    );
  }

  void _pruneExpiredChats() {
    final now = DateTime.now();
    final expired = _flowers.where((f) => now.isAfter(f.expiresAt)).toList();
    if (expired.isEmpty) return;

    final expiredIds = expired.map((f) => f.id).toSet();
    _flowers = _flowers.where((f) => !expiredIds.contains(f.id)).toList();
    for (final id in expiredIds) {
      _participantsByChatId.remove(id);
      _commentsByChatId.remove(id);
      final controller = _commentsControllerByChatId.remove(id);
      try {
        controller?.close();
      } catch (_) {}
    }

    // Clear any user pointers to expired chats.
    _users = _users
        .map(
          (u) => expiredIds.contains(u.activeChatId)
              ? u.copyWith(activeChatId: null)
              : u,
        )
        .toList();

    _usersController.add(_users);
    _flowersController.add(_flowers);
  }

  @override
  Stream<List<OnlineUser>> watchOnlineUsers() async* {
    yield _users;
    yield* _usersController.stream;
  }

  @override
  Stream<List<MeadowChatFlower>> watchChatFlowers() async* {
    _pruneExpiredChats();
    yield _flowers;
    yield* _flowersController.stream;
  }

  @override
  Stream<MeadowChatFlower> watchChatCreated() async* {
    yield* _chatCreatedController.stream;
  }

  StreamController<List<MeadowChatComment>> _commentsControllerFor(
    String chatId,
  ) {
    return _commentsControllerByChatId.putIfAbsent(
      chatId,
      () => StreamController<List<MeadowChatComment>>.broadcast(),
    );
  }

  @override
  Stream<List<MeadowChatComment>> watchChatComments({
    required String chatId,
  }) async* {
    _pruneExpiredChats();
    yield List<MeadowChatComment>.of(_commentsByChatId[chatId] ?? const []);
    yield* _commentsControllerFor(chatId).stream;
  }

  @override
  Future<void> addChatComment({
    required String chatId,
    required String authorId,
    required String authorName,
    required String content,
  }) async {
    final trimmed = content.trim();
    if (trimmed.isEmpty) return;

    _pruneExpiredChats();
    if (!_flowers.any((f) => f.id == chatId)) return;

    final now = DateTime.now();
    final c = MeadowChatComment(
      id: 'c-${now.microsecondsSinceEpoch}-$authorId',
      chatId: chatId,
      authorId: authorId,
      authorName: authorName,
      content: trimmed,
      createdAt: now,
    );

    final current = _commentsByChatId.putIfAbsent(
      chatId,
      () => <MeadowChatComment>[],
    );
    current.add(c);
    _commentsControllerFor(chatId).add(List<MeadowChatComment>.of(current));

    // Extend expiry to 24h after last comment.
    _flowers = _flowers
        .map(
          (f) => f.id == chatId
              ? f.copyWith(expiresAt: now.add(const Duration(hours: 24)))
              : f,
        )
        .toList();
    _flowersController.add(_flowers);

    _ensurePruneTimer();
  }

  @override
  Future<MeadowChatFlower> createChat({
    required String emoji,
    required String topic,
    required String createdBy,
    required String createdByUserId,
    required Offset position,
    String? initialComment,
  }) async {
    _pruneExpiredChats();
    _ensurePruneTimer();

    final chat = MeadowChatFlower(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      emoji: emoji,
      topic: topic,
      createdBy: createdBy,
      position: position,
      expiresAt: DateTime.now().add(const Duration(hours: 24)),
      participantCount: 0,
    );

    _flowers = [..._flowers, chat];
    _participantsByChatId[chat.id] = <String>{};
    _commentsByChatId[chat.id] = <MeadowChatComment>[];
    _flowersController.add(_flowers);

    _chatCreatedController.add(chat);

    await joinChat(chatId: chat.id, userId: createdByUserId);

    final initial = (initialComment ?? '').trim();
    if (initial.isNotEmpty) {
      await addChatComment(
        chatId: chat.id,
        authorId: createdByUserId,
        authorName: createdBy,
        content: initial,
      );
    }

    return _flowers.firstWhere((f) => f.id == chat.id);
  }

  @override
  Future<void> joinChat({
    required String chatId,
    required String userId,
  }) async {
    _pruneExpiredChats();
    final participants = _participantsByChatId.putIfAbsent(
      chatId,
      () => <String>{},
    );
    final didAdd = participants.add(userId);
    if (!didAdd) return;

    // Track where users are chatting.
    _users = _users
        .map((u) => u.id == userId ? u.copyWith(activeChatId: chatId) : u)
        .toList();
    _usersController.add(_users);

    _flowers = _flowers
        .map(
          (flower) => flower.id == chatId
              ? flower.copyWith(participantCount: participants.length)
              : flower,
        )
        .toList();
    _flowersController.add(_flowers);
  }

  @override
  Future<void> leaveChat({
    required String chatId,
    required String userId,
  }) async {
    _pruneExpiredChats();
    final participants = _participantsByChatId[chatId];
    if (participants == null) return;
    participants.remove(userId);

    _users = _users
        .map(
          (u) => u.id == userId && u.activeChatId == chatId
              ? u.copyWith(activeChatId: null)
              : u,
        )
        .toList();
    _usersController.add(_users);

    if (participants.isEmpty) {
      _participantsByChatId.remove(chatId);
      _flowers.removeWhere((f) => f.id == chatId);
      _flowersController.add(_flowers);

      _commentsByChatId.remove(chatId);
      final controller = _commentsControllerByChatId.remove(chatId);
      try {
        controller?.close();
      } catch (_) {}
      return;
    }

    _flowers = _flowers
        .map(
          (flower) => flower.id == chatId
              ? flower.copyWith(participantCount: participants.length)
              : flower,
        )
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
