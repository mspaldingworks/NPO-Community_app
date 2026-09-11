import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:npo_community/core/services/auth_service.dart';
import 'package:npo_community/pages/auth/register_screen.dart';

void main() {
  testWidgets('register screen labels the location field as City', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: RegisterScreen()),
    );

    expect(find.text('City'), findsOneWidget);
    expect(find.text('ZIP Code'), findsNothing);
  });

  testWidgets('register screen shows non-username validation details', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: RegisterScreen(
          onSignUp: ({
            required String email,
            required String password,
            required String password2,
            required String username,
            required String city,
            profileImage,
          }) async {
            throw SignUpException(
              errors: {
                'password': ['Password must include a symbol.'],
                'city': ['Enter a real city name.'],
              },
            );
          },
        ),
      ),
    );

    await tester.enterText(find.byType(TextFormField).at(0), 'member');
    await tester.enterText(find.byType(TextFormField).at(1), 'member@test.dev');
    await tester.enterText(find.byType(TextFormField).at(2), 'Secret123');
    await tester.enterText(find.byType(TextFormField).at(3), 'Secret123');
    await tester.enterText(find.byType(TextFormField).at(4), '40218');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Sign Up'));
    await tester.pump();

    expect(find.text('Password: Password must include a symbol.'), findsOneWidget);
    expect(find.text('City: Enter a real city name.'), findsOneWidget);
  });
}
