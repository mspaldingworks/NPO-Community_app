import 'package:npo_community/core/services/shared_preferences_service.dart';

class ChatFavoritesService {
  static const String _favoritesKey = 'favorite_chat_ids_v1';
  final SharedPreferencesService _prefsService = SharedPreferencesService();

  Future<Set<int>> getFavoriteChatIds() async {
    final raw = _prefsService.getData(_favoritesKey);
    if (raw == null || raw.trim().isEmpty) {
      return <int>{};
    }
    return raw
        .split(',')
        .map((value) => int.tryParse(value.trim()))
        .whereType<int>()
        .toSet();
  }

  Future<void> setChatFavorite({
    required int chatId,
    required bool isFavorite,
  }) async {
    final current = await getFavoriteChatIds();
    if (isFavorite) {
      current.add(chatId);
    } else {
      current.remove(chatId);
    }
    await _prefsService.saveData(_favoritesKey, current.join(','));
  }
}
