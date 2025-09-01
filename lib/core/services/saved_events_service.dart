import 'package:shared_preferences/shared_preferences.dart';

class SavedEventsService {
  static const _savedEventsKey = 'savedEvents';

  Future<List<String>> getSavedEvents() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_savedEventsKey) ?? [];
  }

  Future<void> saveEvent(String eventId) async {
    final prefs = await SharedPreferences.getInstance();
    final savedEvents = await getSavedEvents();
    if (!savedEvents.contains(eventId)) {
      savedEvents.add(eventId);
      await prefs.setStringList(_savedEventsKey, savedEvents);
    }
  }

  Future<void> unsaveEvent(String eventId) async {
    final prefs = await SharedPreferences.getInstance();
    final savedEvents = await getSavedEvents();
    if (savedEvents.contains(eventId)) {
      savedEvents.remove(eventId);
      await prefs.setStringList(_savedEventsKey, savedEvents);
    }
  }

  Future<bool> isEventSaved(String eventId) async {
    final savedEvents = await getSavedEvents();
    return savedEvents.contains(eventId);
  }
}
