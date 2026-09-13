import 'package:flutter/foundation.dart';
import 'package:npo_community/core/services/auth_service.dart';
import 'package:npo_community/core/services/shared_preferences_service.dart';

enum ViewMode { member, board }

/// Which context the app is being used in: as an alum/member, or as the board.
///
/// This is deliberately not touring. Touring previews *another user type's*
/// experience with a fake persona; this switches the real account's own
/// working context and the data it is looking at.
///
/// Access is currently limited to superusers while the board side is built
/// out. Widening it to actual board members later means changing
/// [canUseBoardView] alone.
class ViewModeService extends ChangeNotifier {
  static final ViewModeService _instance = ViewModeService._internal();
  factory ViewModeService() => _instance;
  ViewModeService._internal();

  static const String _storageKey = 'view_mode';

  ViewMode _mode = ViewMode.member;
  ViewMode get mode => _mode;
  bool get isBoardView => _mode == ViewMode.board;

  /// Superusers only, for now. Judged on the real account rather than
  /// [AuthService.currentUser], so wearing a touring persona neither grants
  /// board access nor strips it from the superuser wearing it.
  bool get canUseBoardView => AuthService().realUser?.isSuperuser ?? false;

  /// Restores the last-used mode for this device.
  ///
  /// Falls back to member view whenever the current account may not use the
  /// board view, so a stored preference can never be a way in.
  void restore() {
    if (!canUseBoardView) {
      _setMode(ViewMode.member, persist: false);
      return;
    }
    final stored = SharedPreferencesService().getData(_storageKey);
    _setMode(
      stored == ViewMode.board.name ? ViewMode.board : ViewMode.member,
      persist: false,
    );
  }

  Future<void> setMode(ViewMode mode) async {
    if (mode == ViewMode.board && !canUseBoardView) {
      return;
    }
    _setMode(mode, persist: true);
    await SharedPreferencesService().saveData(_storageKey, mode.name);
  }

  Future<void> toggle() =>
      setMode(isBoardView ? ViewMode.member : ViewMode.board);

  /// Drops back to member view and forgets the stored preference. Call on
  /// sign-out so the next account on the device does not inherit it.
  Future<void> reset() async {
    _setMode(ViewMode.member, persist: false);
    await SharedPreferencesService().clearData(_storageKey);
  }

  void _setMode(ViewMode mode, {required bool persist}) {
    if (_mode == mode) {
      return;
    }
    _mode = mode;
    notifyListeners();
  }
}
