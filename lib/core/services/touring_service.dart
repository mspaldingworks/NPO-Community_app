import 'package:flutter/foundation.dart';
import 'package:npo_community/models/user.dart';

class TouringProfile {
  final String label;
  final String roleTag;
  final User user;

  TouringProfile({
    required this.label,
    required this.roleTag,
    required this.user,
  });
}

class TouringService extends ChangeNotifier {
  static final TouringService _instance = TouringService._internal();
  factory TouringService() => _instance;
  TouringService._internal();

  bool _active = false;
  int _activeIndex = 0;

  bool get isActive => _active;
  int get activeIndex => _activeIndex;
  TouringProfile? get activeProfile => _active ? profiles[_activeIndex] : null;

  static final List<TouringProfile> profiles = [
    TouringProfile(
      label: 'Volunteer — Sam',
      roleTag: 'volunteer',
      user: User(
        id: 2,
        username: 'volunteer_sam',
        email: 'sam@example.com',
        city: 'Louisville',
        fullName: 'Sam V.',
        userType: 'volunteer',
        isStaff: false,
      ),
    ),
    TouringProfile(
      label: 'Admin — River',
      roleTag: 'admin',
      user: User(
        id: 4,
        username: 'admin_river',
        email: 'river@example.com',
        city: 'Louisville',
        fullName: 'River A.',
        userType: 'admin',
        isStaff: true,
      ),
    ),
    TouringProfile(
      label: 'Alumni — Jen',
      roleTag: 'alumni',
      user: User(
        id: 1,
        username: 'alumni_jen',
        email: 'jen@example.com',
        city: 'Louisville',
        fullName: 'Jen A.',
        userType: 'alumni',
        isStaff: false,
      ),
    ),
    TouringProfile(
      label: 'Staff — Ava (Admin)',
      roleTag: 'staff',
      user: User(
        id: 3,
        username: 'staff_ava',
        email: 'ava@example.com',
        city: 'Louisville',
        fullName: 'Ava S.',
        userType: 'staff',
        isStaff: true,
      ),
    ),
    TouringProfile(
      label: 'Board — Casey',
      roleTag: 'board_member',
      user: User(
        id: 7,
        username: 'board_casey',
        email: 'casey@example.com',
        city: 'Louisville',
        fullName: 'Casey B.',
        userType: 'board_member',
        isStaff: false,
      ),
    ),
  ];

  void activateProfile(int index, void Function(User) switchUser) {
    _active = true;
    _activeIndex = index.clamp(0, profiles.length - 1);
    switchUser(profiles[_activeIndex].user);
    notifyListeners();
  }

  void cycleNext(void Function(User) switchUser) {
    activateProfile((_activeIndex + 1) % profiles.length, switchUser);
  }

  void cyclePrev(void Function(User) switchUser) {
    activateProfile(
      (_activeIndex - 1 + profiles.length) % profiles.length,
      switchUser,
    );
  }

  /// Ends touring and hands control back to the caller to restore the real
  /// account. Touring never changed the stored token, so this is a UI
  /// restoration, not a sign-out.
  void deactivate(void Function() onRestore) {
    _active = false;
    onRestore();
    notifyListeners();
  }
}
