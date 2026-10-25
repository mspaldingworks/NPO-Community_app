import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:npo_community/core/services/api_client.dart';
import 'package:npo_community/core/services/shared_preferences_service.dart';
import 'package:npo_community/features/class_fundraising/class_fundraising_service.dart';
import 'package:npo_community/features/class_fundraising/class_fundraising_view.dart';
import 'package:shared_preferences/shared_preferences.dart';

Map<String, dynamic> _json({String mode = 'preview', bool available = true}) =>
    {
      'year': 2026,
      'goal_cents': 100000,
      'mode': mode,
      'available': available,
      'total_raised_cents': 159000,
      'total_goal_cents': 300000,
      'members': [
        {
          'id': 2,
          'display_name': 'Zoe',
          'raised_cents': 34000,
          'donors': 4,
          'url': '',
          'joined': true,
          'is_me': true,
        },
        {
          'id': 1,
          'display_name': 'Ada',
          'raised_cents': 125000,
          'donors': 18,
          'url': 'https://givebutter.com/class-2026/ada',
          'joined': true,
          'is_me': false,
        },
        {
          'id': 3,
          'display_name': 'Bea',
          'raised_cents': 0,
          'donors': 0,
          'url': '',
          'joined': false,
          'is_me': false,
        },
      ],
    };

class _Fake extends ClassFundraisingService {
  _Fake(this.json);

  final Map<String, dynamic> json;

  @override
  Future<ClassFundraising> fetch() async => ClassFundraising.fromJson(json);
}

void main() {
  test('reads /api/class-fundraising/', () async {
    SharedPreferences.setMockInitialValues({'user_token': 'test-token'});
    await SharedPreferencesService().init();
    final sent = <http.Request>[];
    ApiClient.debugHttpClientOverride = MockClient((request) async {
      sent.add(request);
      return http.Response(jsonEncode(_json()), 200);
    });
    addTearDown(() => ApiClient.debugHttpClientOverride = null);

    final data = await ClassFundraisingService().fetch();
    expect(sent.single.url.path, '/api/class-fundraising/');
    expect(sent.single.headers['Authorization'], 'Token test-token');
    expect(data.isPreview, isTrue);
    expect(data.me!.displayName, 'Zoe');
    expect(data.members, hasLength(3));
  });

  testWidgets('one bar per member from \$0 to the goal, labelled as samples', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: ClassFundraisingList(service: _Fake(_json()))),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('class-fundraising-preview')), findsOneWidget);
    expect(find.text('Zoe (you)'), findsOneWidget);
    expect(find.text('\$340 of \$1,000'), findsOneWidget);
    expect(find.text('\$1,250 of \$1,000'), findsOneWidget);
    expect(find.text('Goal met'), findsOneWidget);
    expect(find.text('\$0 of \$1,000'), findsOneWidget);
    expect(find.text('\$1,590 of \$3,000'), findsOneWidget); // class total

    final bars = tester
        .widgetList<LinearProgressIndicator>(
          find.byType(LinearProgressIndicator),
        )
        .map((bar) => bar.value)
        .toList();
    expect(bars, [0.53, 0.34, 1.0, 0.0]);
    // Only a member with a Givebutter page gets a give button.
    expect(find.byTooltip('Give to Ada'), findsOneWidget);
    expect(find.byTooltip('Give to Bea'), findsNothing);
  });

  testWidgets('live figures carry no sample label', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ClassFundraisingList(service: _Fake(_json(mode: 'live'))),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('class-fundraising-preview')), findsNothing);
  });

  testWidgets('Givebutter down shows a message, not zeros', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ClassFundraisingList(
            service: _Fake(_json(mode: 'live', available: false)),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('unavailable right now'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsNothing);
  });

  testWidgets('Home card shows my own bar', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: MyClassFundraisingCard(service: _Fake(_json()))),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Your fundraising goal'), findsOneWidget);
    expect(find.text('\$340 of \$1,000'), findsOneWidget);
    expect(find.text('Sample'), findsOneWidget);
  });
}
