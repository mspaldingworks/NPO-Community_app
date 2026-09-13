import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:npo_community/core/services/auth_service.dart';
import 'package:npo_community/pages/auth/register_screen.dart';

void main() {
  testWidgets('register screen labels the location field as City', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: RegisterScreen()));

    expect(find.text('City'), findsOneWidget);
    expect(find.text('ZIP Code'), findsNothing);
  });

  testWidgets('register screen shows non-username validation details', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: RegisterScreen(
          onSignUp:
              ({
                required String email,
                required String password,
                required String password2,
                required String username,
                required String city,
                required int programYear,
                required DateTime dateOfBirth,
                required bool adultAttestation,
                required bool conductPolicyAccepted,
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

    // Program year is required too. The API call for the year list fails in
    // tests, so ProgramService falls back to a locally computed range.
    final yearField = find.byType(DropdownButtonFormField<int>);
    await tester.ensureVisible(yearField);
    await tester.tap(yearField);
    await tester.pumpAndSettle();
    await tester.tap(find.text('${DateTime.now().year}').last);
    await tester.pumpAndSettle();

    // Date of birth and both attestations are required before the form will
    // submit; the picker's default selection is the 18-years-ago date.
    await tester.ensureVisible(find.text('Tap to select'));
    await tester.tap(find.text('Tap to select'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    for (var i = 0; i < 2; i++) {
      await tester.ensureVisible(find.byType(Checkbox).at(i));
      await tester.tap(find.byType(Checkbox).at(i));
      await tester.pump();
    }

    final signUpButton = find.widgetWithText(ElevatedButton, 'Sign Up');
    await tester.ensureVisible(signUpButton);
    await tester.tap(signUpButton);
    await tester.pump();

    // userMessage() joins the field errors into a single snackbar line.
    expect(
      find.text(
        'Password: Password must include a symbol.\n'
        'City: Enter a real city name.',
      ),
      findsOneWidget,
    );
  });
}
