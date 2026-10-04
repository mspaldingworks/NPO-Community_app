import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:npo_community/core/services/api_client.dart';
import 'package:npo_community/core/services/block_service.dart';
import 'package:npo_community/core/services/shared_preferences_service.dart';
import 'package:npo_community/pages/auth/forgot_password_screen.dart';
import 'package:npo_community/pages/settings/blocked_members_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeBlockService extends BlockService {
  _FakeBlockService(this.rows);

  List<BlockedMember> rows;
  final calls = <String>[];

  @override
  Future<List<BlockedMember>> fetchBlocked() async => rows;

  @override
  Future<void> block(int userId) async => calls.add('block $userId');

  @override
  Future<void> unblock(int userId) async {
    calls.add('unblock $userId');
    rows = rows.where((r) => r.id != userId).toList();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({'user_token': 'test-token'});
    await SharedPreferencesService().init();
  });
  tearDown(() => ApiClient.debugHttpClientOverride = null);

  test('block service talks to /api/blocks/', () async {
    final sent = <http.Request>[];
    ApiClient.debugHttpClientOverride = MockClient((request) async {
      sent.add(request);
      if (request.method == 'GET') {
        return http.Response(
          jsonEncode([
            {
              'id': 7,
              'username': 'bob',
              'display_name': 'Bob',
              'blocked_at': '2026-10-04T12:00:00Z',
            },
          ]),
          200,
        );
      }
      return http.Response('', request.method == 'POST' ? 201 : 204);
    });

    final service = BlockService();
    final blocked = await service.fetchBlocked();
    expect(blocked.single.displayName, 'Bob');
    await service.block(7);
    await service.unblock(7);
    expect(sent.map((r) => '${r.method} ${r.url.path}'), [
      'GET /api/blocks/',
      'POST /api/blocks/',
      'DELETE /api/blocks/7/',
    ]);
    expect(jsonDecode(sent[1].body), {'user_id': 7});
    expect(sent[1].headers['Authorization'], 'Token test-token');
  });

  testWidgets('blocked members list unblocks', (tester) async {
    final service = _FakeBlockService([
      const BlockedMember(id: 7, username: 'bob', displayName: 'Bob'),
    ]);
    await tester.pumpWidget(
      MaterialApp(home: BlockedMembersScreen(service: service)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Bob'), findsOneWidget);
    await tester.tap(find.text('Unblock'));
    await tester.pumpAndSettle();
    expect(service.calls, ['unblock 7']);
    expect(find.textContaining('have not blocked anyone'), findsOneWidget);
  });

  testWidgets('confirmAndBlock asks first, then blocks', (tester) async {
    final service = _FakeBlockService([]);
    bool? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                result = await confirmAndBlock(
                  context,
                  userId: 7,
                  name: 'Bob',
                  service: service,
                );
              },
              child: const Text('go'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    expect(find.text('Block Bob?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(result, isFalse);
    expect(service.calls, isEmpty);

    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Block'));
    await tester.pumpAndSettle();
    expect(result, isTrue);
    expect(service.calls, ['block 7']);
  });

  testWidgets('forgot password requests a code then confirms', (tester) async {
    final calls = <String>[];
    await tester.pumpWidget(
      MaterialApp.router(
        routerConfig: GoRouter(
          initialLocation: '/forgot-password',
          routes: [
            GoRoute(
              path: '/forgot-password',
              builder: (_, _) => ForgotPasswordScreen(
                requestReset: (email) async => calls.add('request $email'),
                confirmReset:
                    ({
                      required email,
                      required code,
                      required password,
                    }) async => calls.add('confirm $email $code $password'),
              ),
            ),
            GoRoute(path: '/login', builder: (_, _) => const Text('login')),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('reset-email')), 'a@b.org');
    await tester.tap(find.text('Send code'));
    await tester.pumpAndSettle();
    expect(calls, ['request a@b.org']);
    expect(find.text('Set new password'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('reset-code')), 'ABCD-2345');
    await tester.enterText(
      find.byKey(const Key('reset-password')),
      'New-Pass-9',
    );
    await tester.enterText(find.byKey(const Key('reset-confirm')), 'nope');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Set new password'));
    await tester.pumpAndSettle();
    expect(find.text('The passwords do not match.'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('reset-confirm')),
      'New-Pass-9',
    );
    await tester.tap(find.text('Set new password'));
    await tester.pumpAndSettle();
    expect(calls.last, 'confirm a@b.org ABCD-2345 New-Pass-9');
    expect(find.text('login'), findsOneWidget);
  });
}
