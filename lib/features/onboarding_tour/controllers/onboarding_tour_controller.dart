import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:transconnect/features/onboarding_tour/models/onboarding_tour_models.dart';

class OnboardingTourController extends ChangeNotifier {
  static const String defaultAssetPath = 'assets/onboarding_tour.json';
  static const String _seenKeyPrefix = 'onboarding_tour_seen__';
  static const String defaultSeenKeyPrefix = _seenKeyPrefix;
  static const String meadowSeenKeyPrefix = 'meadow_tour_seen__';

  OnboardingTourConfig? _config;
  bool _active = false;
  int _index = 0;
  String? _username;
  String _seenKeyPrefixValue = defaultSeenKeyPrefix;
  String _loadedAssetPath = defaultAssetPath;

  bool get active => _active;

  int get currentIndex => _index;

  int get totalSteps => _config?.tour.length ?? 0;

  TourStep? get currentStep {
    if (_config == null) return null;
    if (_config!.tour.isEmpty) return null;
    final safeIndex = min(max(_index, 0), _config!.tour.length - 1);
    return _config!.tour[safeIndex];
  }

  Future<void> load({String assetPath = defaultAssetPath}) async {
    if (_config != null && _loadedAssetPath == assetPath) return;
    try {
      final raw = await rootBundle.loadString(assetPath);
      _config = OnboardingTourConfig.fromJsonString(raw);
      _loadedAssetPath = assetPath;
    } catch (_) {
      _config = OnboardingTourConfig.empty();
      _loadedAssetPath = assetPath;
    }
  }

  String _seenKey(String username) => '$_seenKeyPrefixValue$username';

  void setSeenKeyPrefix(String prefix) {
    _seenKeyPrefixValue = prefix;
  }

  void resetSeenKeyPrefix() {
    _seenKeyPrefixValue = defaultSeenKeyPrefix;
  }

  Future<bool> hasSeenForUser(String username) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_seenKey(username)) ?? false;
  }

  Future<void> markSeenForUser(String username) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_seenKey(username), true);
  }

  Future<void> startForUser(String username) async {
    await load(assetPath: _loadedAssetPath);
    if ((_config?.tour ?? const <TourStep>[]).isEmpty) return;

    _username = username;
    _index = 0;
    _active = true;
    notifyListeners();
  }

  Future<void> stopAndMarkSeen() async {
    final username = _username;
    _username = null;
    _active = false;
    _index = 0;
    notifyListeners();

    if (username != null && username.trim().isNotEmpty) {
      await markSeenForUser(username);
    }
  }

  void stopWithoutMarkingSeen() {
    _username = null;
    _active = false;
    _index = 0;
    notifyListeners();
  }

  Future<void> next() async {
    if (!_active) return;
    if (totalSteps == 0) {
      await stopAndMarkSeen();
      return;
    }

    if (_index >= totalSteps - 1) {
      await stopAndMarkSeen();
      return;
    }

    _index += 1;
    notifyListeners();
  }

  void previous() {
    if (!_active) return;
    if (_index <= 0) return;
    _index -= 1;
    notifyListeners();
  }
}
