// Touring lets an account wear another user type's persona, and the menu that
// reaches it also carries admin tooling — so it must be a superuser function,
// and it must not be possible to strand yourself inside it.

import 'package:flutter_test/flutter_test.dart';
import 'package:npo_community/core/services/auth_service.dart';
import 'package:npo_community/core/services/shared_preferences_service.dart';
import 'package:npo_community/core/services/touring_service.dart';
import 'package:npo_community/models/user.dart';
import 'package:shared_preferences/shared_preferences.dart';

User _user({
  required String username,
  bool isStaff = false,
  bool isSuperuser = false,
}) => User(
  id: 1,
  username: username,
  email: '$username@test.dev',
  isStaff: isStaff,
  isSuperuser: isSuperuser,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await SharedPreferencesService().init();
    await AuthService().signOut();
  });

  group('User model', () {
    test('parses is_superuser from the API', () {
      final user = User.fromJson({
        'id': 1,
        'username': 'root',
        'email': 'root@test.dev',
        'is_staff': true,
        'is_superuser': true,
      });
      expect(user.isSuperuser, isTrue);
      expect(user.isStaff, isTrue);
    });

    test('defaults is_superuser to false when the API omits it', () {
      final user = User.fromJson({
        'id': 1,
        'username': 'x',
        'email': 'x@t.dev',
      });
      expect(user.isSuperuser, isFalse);
    });
  });

  group('canTour', () {
    test('is false when signed out', () {
      expect(AuthService().canTour, isFalse);
    });

    test('is false for an ordinary member', () {
      AuthService().switchTouringUser(_user(username: 'member'));
      expect(AuthService().canTour, isFalse);
    });

    test('is true for a superuser', () {
      AuthService().debugSetCurrentUser(
        _user(username: 'root', isStaff: true, isSuperuser: true),
      );
      expect(AuthService().canTour, isTrue);
    });

    test('is true for staff', () {
      AuthService().debugSetCurrentUser(_user(username: 'ava', isStaff: true));
      expect(AuthService().canTour, isTrue);
    });
  });

  group('touring', () {
    test('an ordinary member cannot start touring', () {
      final member = _user(username: 'member');
      AuthService().debugSetCurrentUser(member);

      AuthService().switchTouringUser(TouringService.profiles.first.user);

      expect(AuthService().isTouring, isFalse);
      expect(AuthService().currentUser?.username, 'member');
    });

    test('wearing a non-staff persona does not revoke the right to tour', () {
      // The trap: touring replaces currentUser, so a gate reading currentUser
      // would lock a superuser inside the volunteer persona with no way out.
      AuthService().debugSetCurrentUser(
        _user(username: 'root', isStaff: true, isSuperuser: true),
      );

      final volunteer = TouringService.profiles.firstWhere(
        (p) => !p.user.isStaff,
      );
      AuthService().switchTouringUser(volunteer.user);

      expect(AuthService().currentUser?.isStaff, isFalse);
      expect(AuthService().realUser?.username, 'root');
      expect(AuthService().canTour, isTrue, reason: 'must not be stranded');
    });

    test('stopTouring restores the real account without signing out', () {
      final root = _user(username: 'root', isStaff: true, isSuperuser: true);
      AuthService().debugSetCurrentUser(root);

      AuthService().switchTouringUser(TouringService.profiles.first.user);
      expect(AuthService().isTouring, isTrue);

      AuthService().stopTouring();

      expect(AuthService().isTouring, isFalse);
      expect(AuthService().currentUser?.username, 'root');
      expect(AuthService().currentUser?.isSuperuser, isTrue);
    });

    test('signing out while touring clears the remembered account', () async {
      AuthService().debugSetCurrentUser(
        _user(username: 'root', isStaff: true, isSuperuser: true),
      );
      AuthService().switchTouringUser(TouringService.profiles.first.user);

      await AuthService().signOut();

      expect(AuthService().realUser, isNull);
      expect(AuthService().canTour, isFalse);
      expect(AuthService().isTouring, isFalse);
    });
  });
}
