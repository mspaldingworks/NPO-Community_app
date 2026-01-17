import 'package:flutter/foundation.dart';
import 'package:transconnect/features/meadow/models/meadow_chat_flower.dart';

class MeadowAlertService extends ChangeNotifier {
  int _unreadChats = 0;
  MeadowChatFlower? _latestChat;

  int get unreadChats => _unreadChats;
  MeadowChatFlower? get latestChat => _latestChat;
  bool get hasUnread => _unreadChats > 0;

  void registerNewChat(MeadowChatFlower chat) {
    _unreadChats += 1;
    _latestChat = chat;
    notifyListeners();
  }

  void markAllRead() {
    if (_unreadChats == 0) return;
    _unreadChats = 0;
    notifyListeners();
  }
}
