// DO NOT CHANGE THIS FILE ANY CHANGE NEEDS A CORROSPONDING API CHANGE DONE BY PAIGE

import 'package:shared_preferences/shared_preferences.dart';

class SharedPreferencesService {
  late SharedPreferences _prefs;

  // Private constructor to prevent direct instantiation.
  // This ensures a single instance (Singleton pattern).
  SharedPreferencesService._privateConstructor();

  static final SharedPreferencesService _instance =
      SharedPreferencesService._privateConstructor();

  factory SharedPreferencesService() {
    return _instance;
  }

  // Method to initialize SharedPreferences instance.
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  // Method to save a key-value pair.
  Future<void> saveData(String key, String value) async {
    await _prefs.setString(key, value);
  }

  // Method to retrieve a value by its key.
  String? getData(String key) {
    return _prefs.getString(key);
  }

  // New method to clear a specific key-value pair
  Future<void> clearData(String key) async {
    await _prefs.remove(key);
  }

  // New method to clear all data
  Future<void> clearAll() async {
    await _prefs.clear();
  }
}
