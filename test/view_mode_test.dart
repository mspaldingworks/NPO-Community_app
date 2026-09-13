// Board view is a privilege, not a preference — a stored value must never be
// a way in, and it must not survive to the next account on the device.

import 'package:flutter_test/flutter_test.dart';
import 'package:npo_community/core/services/auth_service.dart';
import 'package:npo_community/core/services/shared_preferences_service.dart';
import 'package:npo_community/core/services/touring_service.dart';
import 'package:npo_community/core/services/view_mode_service.dart';
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
    await ViewModeService().reset();
  });

  test('member view is the default', () {
    expect(ViewModeService().mode, ViewMode.member);
    expect(ViewModeService().isBoardView, isFalse);
  });

  test('an ordinary member may not use the board view', () {
    AuthService().debugSetCurrentUser(_user(username: 'member'));
    expect(ViewModeService().canUseBoardView, isFalse);
  });

  test('staff alone is not enough — superuser only, for now', () {
    AuthService().debugSetCurrentUser(_user(username: 'ava', isStaff: true));
    expect(ViewModeService().canUseBoardView, isFalse);
  });

  test('a superuser may use the board view', () {
    AuthService().debugSetCurrentUser(
      _user(username: 'root', isStaff: true, isSuperuser: true),
    );
    expect(ViewModeService().canUseBoardView, isTrue);
  });

  test('setMode is refused for an account that may not use it', () async {
    AuthService().debugSetCurrentUser(_user(username: 'member'));

    await ViewModeService().setMode(ViewMode.board);

    expect(ViewModeService().isBoardView, isFalse);
  });

  test('a superuser can switch to board view and back', () async {
    AuthService().debugSetCurrentUser(
      _user(username: 'root', isStaff: true, isSuperuser: true),
    );

    await ViewModeService().setMode(ViewMode.board);
    expect(ViewModeService().isBoardView, isTrue);

    await ViewModeService().setMode(ViewMode.member);
    expect(ViewModeService().isBoardView, isFalse);
  });

  test('a stored board preference cannot let an ordinary member in', () async {
    // Simulate a device where a superuser previously chose board view.
    SharedPreferences.setMockInitialValues({'view_mode': 'board'});
    await SharedPreferencesService().init();
    AuthService().debugSetCurrentUser(_user(username: 'member'));

    ViewModeService().restore();

    expect(ViewModeService().isBoardView, isFalse);
  });

  test('signing out drops board view for the next account', () async {
    AuthService().debugSetCurrentUser(
      _user(username: 'root', isStaff: true, isSuperuser: true),
    );
    await ViewModeService().setMode(ViewMode.board);
    expect(ViewModeService().isBoardView, isTrue);

    await AuthService().signOut();

    expect(ViewModeService().isBoardView, isFalse);
    expect(ViewModeService().canUseBoardView, isFalse);
  });

  test('a touring persona neither grants nor strips board access', () async {
    AuthService().debugSetCurrentUser(
      _user(username: 'root', isStaff: true, isSuperuser: true),
    );
    final volunteer = TouringService.profiles.firstWhere(
      (p) => !p.user.isStaff,
    );
    AuthService().switchTouringUser(volunteer.user);

    // Judged on the real account, so the superuser keeps access while wearing
    // a volunteer persona — and the persona itself confers nothing.
    expect(ViewModeService().canUseBoardView, isTrue);
    expect(AuthService().currentUser?.isSuperuser, isFalse);
  });
}
