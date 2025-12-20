import 'package:shared_preferences/shared_preferences.dart';

class OnboardingTourStorage {
  static const String seenKeyPrefix = 'onboarding_tour_seen__';
  static const String pendingKeyPrefix = 'onboarding_tour_pending__';

  static String seenKey(String username) => '$seenKeyPrefix$username';
  static String pendingKey(String username) => '$pendingKeyPrefix$username';

  static Future<bool> hasSeen(String username) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(seenKey(username)) ?? false;
  }

  static Future<void> markSeen(String username) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(seenKey(username), true);
  }

  static Future<void> markPendingStart(String username) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(pendingKey(username), true);
  }

  static Future<bool> isPendingStart(String username) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(pendingKey(username)) ?? false;
  }

  static Future<void> clearPendingStart(String username) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(pendingKey(username));
  }

  static Future<bool> consumePendingStart(String username) async {
    final prefs = await SharedPreferences.getInstance();
    final key = pendingKey(username);
    final pending = prefs.getBool(key) ?? false;
    if (pending) {
      await prefs.remove(key);
    }
    return pending;
  }
}
