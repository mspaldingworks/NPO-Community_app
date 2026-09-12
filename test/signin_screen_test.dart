import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:npo_community/pages/auth/signin_screen.dart';

void main() {
  testWidgets('sign in trims the username but preserves the exact password', (
    tester,
  ) async {
    String? receivedUsername;
    String? receivedPassword;

    await tester.pumpWidget(
      MaterialApp(
        home: SignInScreen(
          onSignIn:
              ({required String username, required String password}) async {
                receivedUsername = username;
                receivedPassword = password;
              },
        ),
      ),
    );

    await tester.enterText(find.byType(TextFormField).at(0), '  volunteer  ');
    await tester.enterText(find.byType(TextFormField).at(1), '  Secret  ');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Sign In'));
    await tester.pumpAndSettle();

    expect(receivedUsername, 'volunteer');
    expect(receivedPassword, '  Secret  ');
  });
}
