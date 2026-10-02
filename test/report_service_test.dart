import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:npo_community/core/services/api_client.dart';
import 'package:npo_community/core/services/report_service.dart';
import 'package:npo_community/core/services/shared_preferences_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({'user_token': 'test-token'});
    await SharedPreferencesService().init();
  });

  tearDown(() => ApiClient.debugHttpClientOverride = null);

  test('reports post to the moderators queue', () async {
    late http.Request sent;
    ApiClient.debugHttpClientOverride = MockClient((request) async {
      sent = request;
      return http.Response(
        jsonEncode({'id': 1, 'status': 'open', 'created': true}),
        201,
      );
    });

    await ReportService().submitReport(
      const ReportRequest(
        type: ReportTargetType.message,
        reason: 'Harassment or bullying',
        details: 'Repeated',
        targetId: 42,
        targetUserId: 7,
      ),
    );

    expect(sent.method, 'POST');
    expect(sent.url.path, '/api/reports/');
    expect(sent.headers['Authorization'], 'Token test-token');
    expect(jsonDecode(sent.body), {
      'target_type': 'message',
      'target_id': '42',
      'reason': 'Harassment or bullying',
      'details': 'Repeated',
      'target_user_id': 7,
    });
  });

  test('a refused report surfaces the server message', () async {
    ApiClient.debugHttpClientOverride = MockClient(
      (_) async => http.Response(
        jsonEncode({'detail': 'You cannot report yourself.'}),
        400,
      ),
    );

    await expectLater(
      ReportService().submitReport(
        const ReportRequest(
          type: ReportTargetType.post,
          reason: 'Spam',
          targetId: 1,
        ),
      ),
      throwsA(isA<ApiClientException>()),
    );
  });
}
