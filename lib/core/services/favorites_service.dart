import 'package:npo_community/core/services/shared_preferences_service.dart';

class FavoritesService {
  final SharedPreferencesService _prefsService = SharedPreferencesService();
  static const _favoritesKey = 'favorite_events';

  Future<List<String>> getFavorites() async {
    final favoritesString = _prefsService.getData(_favoritesKey);
    if (favoritesString != null && favoritesString.isNotEmpty) {
      return favoritesString.split(',');
    }
    return [];
  }

  Future<void> _saveFavorites(List<String> favorites) async {
    await _prefsService.saveData(_favoritesKey, favorites.join(','));
  }

  Future<bool> isFavorite(String eventId) async {
    final favorites = await getFavorites();
    return favorites.contains(eventId);
  }

  Future<void> addFavorite(String eventId) async {
    final favorites = await getFavorites();
    if (!favorites.contains(eventId)) {
      favorites.add(eventId);
      await _saveFavorites(favorites);
    }
  }

  Future<void> removeFavorite(String eventId) async {
    final favorites = await getFavorites();
    if (favorites.contains(eventId)) {
      favorites.remove(eventId);
      await _saveFavorites(favorites);
    }
  }
}
