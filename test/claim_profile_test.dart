import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:npo_community/models/user.dart';
import 'package:npo_community/pages/auth/claim_profile_screen.dart';
import 'package:npo_community/pages/auth/pending_verification_screen.dart';

Widget _routed(Widget screen) => MaterialApp.router(
  routerConfig: GoRouter(
    initialLocation: '/claim',
    routes: [
      GoRoute(path: '/claim', builder: (_, _) => screen),
      GoRoute(path: '/login', builder: (_, _) => const Text('login')),
      GoRoute(path: '/home', builder: (_, _) => const Text('home')),
    ],
  ),
);

void main() {
  test('only unverified non-staff accounts wait', () {
    User user(Map<String, dynamic> extra) =>
        User.fromJson({'id': 1, 'username': 'u', ...extra});
    expect(
      user({'verification_tier': 'unverified'}).isAwaitingVerification,
      isTrue,
    );
    expect(
      user({'verification_tier': 'verified'}).isAwaitingVerification,
      isFalse,
    );
    expect(
      user({
        'verification_tier': 'unverified',
        'is_staff': true,
      }).isAwaitingVerification,
      isFalse,
    );
  });

  testWidgets('claim flow checks the code then signs in', (tester) async {
    final redeemed = <String>[];
    await tester.pumpWidget(
      _routed(
        ClaimProfileScreen(
          checkClaim: ({required code, required email}) async => {
            'display_name': 'Ada Example',
            'username': 'ada-example',
            'program_year': 2020,
          },
          redeemClaim:
              ({
                required code,
                required email,
                required password,
                required adultAttestation,
                required conductPolicyAccepted,
              }) async {
                redeemed.add(
                  '$code $email $password $adultAttestation $conductPolicyAccepted',
                );
              },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('claim-email')),
      'ada@example.org',
    );
    await tester.enterText(find.byKey(const Key('claim-code')), 'ABCD-2345');
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Welcome, Ada Example (Class of 2020)'),
      findsOneWidget,
    );

    await tester.enterText(
      find.byKey(const Key('claim-password')),
      'Correct-Horse-42',
    );
    await tester.enterText(
      find.byKey(const Key('claim-confirm')),
      'Correct-Horse-42',
    );
    await tester.pumpAndSettle();
    final claim = find.widgetWithText(FilledButton, 'Claim my profile');
    expect(
      tester.widget<FilledButton>(claim).onPressed,
      isNull,
    ); // boxes unticked

    await tester.tap(find.byKey(const Key('claim-adult')));
    await tester.tap(find.byKey(const Key('claim-conduct')));
    await tester.pumpAndSettle();
    await tester.tap(claim);
    await tester.pumpAndSettle();
    expect(redeemed, ['ABCD-2345 ada@example.org Correct-Horse-42 true true']);
    expect(find.text('home'), findsOneWidget);
  });

  testWidgets('pending screen re-checks and signs out', (tester) async {
    var refreshed = 0;
    var signedOut = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: PendingVerificationScreen(
          refresh: () async => refreshed++,
          signOut: () async => signedOut++,
        ),
      ),
    );
    expect(
      find.text('Your account is waiting for verification'),
      findsOneWidget,
    );
    await tester.tap(find.text('Check again'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sign out'));
    await tester.pumpAndSettle();
    expect((refreshed, signedOut), (1, 1));
  });
}
