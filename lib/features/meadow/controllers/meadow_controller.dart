import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:transconnect/features/meadow/data/meadow_repository.dart';
import 'package:transconnect/features/meadow/models/meadow_chat_flower.dart';
import 'package:transconnect/features/meadow/models/online_user.dart';

class MeadowController extends ChangeNotifier {
  MeadowController({
    required MeadowRepository repository,
    required String currentUserId,
    required String currentUserName,
    required List<String> currentUserPronouns,
  })  : _repository = repository,
        _currentUserId = currentUserId,
        _currentUserName = currentUserName,
        _currentUserPronouns = currentUserPronouns;

  final MeadowRepository _repository;
  final String _currentUserId;
  final String _currentUserName;
  final List<String> _currentUserPronouns;

  final _subscriptions = <StreamSubscription<dynamic>>[];
  final _random = Random();

  List<OnlineUser> _onlineUsers = [];
  List<MeadowChatFlower> _flowers = [];
  MeadowChatFlower? _selectedFlower;
  Offset? _flyTarget;

  List<OnlineUser> get onlineUsers => _onlineUsers;
  List<MeadowChatFlower> get flowers => _flowers;
  MeadowChatFlower? get selectedFlower => _selectedFlower;
  Offset? get flyTarget => _flyTarget;

  String get currentUserId => _currentUserId;

  OnlineUser? get currentUser {
    for (final user in _onlineUsers) {
      if (user.id == _currentUserId) return user;
    }
    return null;
  }

  void initialize({
    List<OnlineUser>? seededUsers,
    List<MeadowChatFlower>? seededFlowers,
  }) {
    if (seededUsers != null) {
      _onlineUsers = seededUsers;
    }
    if (seededFlowers != null) {
      _flowers = seededFlowers;
    }
    if (seededUsers != null || seededFlowers != null) {
      notifyListeners();
    }

    _subscriptions
      ..add(_repository.watchOnlineUsers().listen((users) {
        _onlineUsers = users;
        notifyListeners();
      }))
      ..add(_repository.watchChatFlowers().listen((flowers) {
        _flowers = flowers;
        if (_selectedFlower != null && !_flowers.any((f) => f.id == _selectedFlower!.id)) {
          clearFlight();
        } else {
          notifyListeners();
        }
      }));
  }

  void startFlyTo(MeadowChatFlower flower) {
    _selectedFlower = flower;
    _flyTarget = flower.position;
    notifyListeners();
  }

  void clearFlight() {
    _selectedFlower = null;
    _flyTarget = null;
    notifyListeners();
  }

  Future<MeadowChatFlower> createChat({
    required String topic,
    required Size meadowSize,
    required EdgeInsets padding,
    String? description,
  }) async {
    final position = _randomPosition(meadowSize, padding);
    return _repository.createChat(
      topic: topic,
      createdBy: _currentUserName,
      createdByUserId: _currentUserId,
      position: position,
      description: description,
    );
  }

  Future<void> joinChat(String chatId) {
    return _repository.joinChat(chatId: chatId, userId: _currentUserId);
  }

  Future<void> leaveChat(String chatId) {
    return _repository.leaveChat(chatId: chatId, userId: _currentUserId);
  }

  Future<void> reportChat({
    required String chatId,
    required String reason,
    String? note,
  }) {
    return _repository.reportChat(chatId: chatId, reason: reason, note: note);
  }

  Offset _randomPosition(Size meadowSize, EdgeInsets padding) {
    final dx = padding.left + _random.nextDouble() * (meadowSize.width - padding.horizontal);
    final dy = padding.top + _random.nextDouble() * (meadowSize.height - padding.vertical);
    return Offset(dx, dy);
  }

  List<String> get fallbackPronouns {
    if (_currentUserPronouns.isNotEmpty) return _currentUserPronouns;
    return const ['She/Her', 'They/Them', 'He/Him'];
  }

  @override
  void dispose() {
    for (final sub in _subscriptions) {
      sub.cancel();
    }
    super.dispose();
  }
}
