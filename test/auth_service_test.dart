import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:npo_community/core/services/api_client.dart';
import 'package:npo_community/core/services/auth_service.dart';
import 'package:npo_community/core/services/shared_preferences_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await SharedPreferencesService().init();
    ApiClient.debugHttpClientOverride = null;
    await AuthService().signOut();
  });

  tearDown(() {
    ApiClient.debugHttpClientOverride = null;
  });

  test('signIn saves the logged-in user and token from a valid response', () async {
    String? transmittedPassword;

    ApiClient.debugHttpClientOverride = MockClient((request) async {
      expect(request.url.path, '/api/login/');
      final payload = jsonDecode(request.body) as Map<String, dynamic>;
      transmittedPassword = payload['password'] as String;
      return http.Response(
        jsonEncode({
          'token': 'test-token',
          'user': {'id': 7, 'username': 'member', 'email': 'member@test.dev'},
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    });

    await AuthService().signIn(username: 'member', password: '  Secret  ');

    expect(transmittedPassword, '  Secret  ');
    expect(AuthService().currentUser?.username, 'member');
    expect(await AuthService().getToken(), 'test-token');
    expect(SharedPreferencesService().getData('password'), isNull);
  });

  test('signIn surfaces invalid credential errors from the API', () async {
    ApiClient.debugHttpClientOverride = MockClient(
      (_) async => http.Response(
        jsonEncode({'error': 'Invalid Credentials'}),
        400,
        headers: {'content-type': 'application/json'},
      ),
    );

    await expectLater(
      AuthService().signIn(username: 'member', password: 'Secret'),
      throwsA(
        isA<ApiClientException>().having(
          (error) => error.toString(),
          'message',
          'Invalid Credentials',
        ),
      ),
    );
  });

  test('signIn surfaces detail errors from the API', () async {
    ApiClient.debugHttpClientOverride = MockClient(
      (_) async => http.Response(
        jsonEncode({'detail': 'Account disabled'}),
        403,
        headers: {'content-type': 'application/json'},
      ),
    );

    await expectLater(
      AuthService().signIn(username: 'member', password: 'Secret'),
      throwsA(
        isA<ApiClientException>().having(
          (error) => error.toString(),
          'message',
          'Account disabled',
        ),
      ),
    );
  });

  test('signIn formats field validation errors from the API', () async {
    ApiClient.debugHttpClientOverride = MockClient(
      (_) async => http.Response(
        jsonEncode({
          'username': ['This field is required.'],
          'password': ['This field is required.'],
        }),
        400,
        headers: {'content-type': 'application/json'},
      ),
    );

    await expectLater(
      AuthService().signIn(username: '', password: ''),
      throwsA(
        isA<ApiClientException>().having(
          (error) => error.toString(),
          'message',
          'Username: This field is required.\nPassword: This field is required.',
        ),
      ),
    );
  });

  test('signIn rejects malformed success payloads', () async {
    ApiClient.debugHttpClientOverride = MockClient(
      (_) async => http.Response(
        jsonEncode({
          'token': 'test-token',
          'user': {'username': 'member'},
        }),
        200,
        headers: {'content-type': 'application/json'},
      ),
    );

    await expectLater(
      AuthService().signIn(username: 'member', password: 'Secret'),
      throwsA(
        isA<AuthException>().having(
          (error) => error.toString(),
          'message',
          'Login succeeded but the server returned an invalid account response.',
        ),
      ),
    );
  });

  test('signIn explains unreachable API origins without leaking credentials', () async {
    ApiClient.debugHttpClientOverride = MockClient(
      (_) async => throw const SocketException('Connection refused'),
    );

    await expectLater(
      AuthService().signIn(username: 'member', password: 'Secret'),
      throwsA(
        isA<ApiClientException>().having(
          (error) => error.toString(),
          'message',
          allOf(
            contains('http://127.0.0.1:8000'),
            contains('--dart-define=API_ORIGIN'),
            contains('reachable from this device'),
          ),
        ),
      ),
    );
  });

  test('signUp accepts a valid 200 response with user and token', () async {
    ApiClient.debugHttpClientOverride = MockClient((request) async {
      expect(request.url.path, '/api/signup/');
      final payload = jsonDecode(request.body) as Map<String, dynamic>;
      expect(payload['city'], 'Louisville');
      return http.Response(
        jsonEncode({
          'token': 'signup-token',
          'user': {
            'id': 11,
            'username': 'newmember',
            'email': 'newmember@test.dev',
            'city': 'Louisville',
          },
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    });

    await AuthService().signUp(
      email: 'newmember@test.dev',
      password: 'C@\$S3cur3!',
      password2: 'C@\$S3cur3!',
      username: 'newmember',
      city: 'Louisville',
      dateOfBirth: DateTime(1990, 4, 17),
      adultAttestation: true,
      conductPolicyAccepted: true,
    );

    expect(AuthService().currentUser?.username, 'newmember');
    expect(AuthService().currentUser?.city, 'Louisville');
    expect(await AuthService().getToken(), 'signup-token');
  });

  test('signUp preserves API validation errors for password and city', () async {
    ApiClient.debugHttpClientOverride = MockClient(
      (_) async => http.Response(
        jsonEncode({
          'password': ['Password must include a symbol.'],
          'city': ['Enter a real city name.'],
        }),
        400,
        headers: {'content-type': 'application/json'},
      ),
    );

    await expectLater(
      AuthService().signUp(
        email: 'newmember@test.dev',
        password: 'Secret123',
        password2: 'Secret123',
        username: 'newmember',
        city: '40218',
        dateOfBirth: DateTime(1990, 4, 17),
        adultAttestation: true,
        conductPolicyAccepted: true,
      ),
      throwsA(
        isA<SignUpException>()
            .having(
              (error) => error.errors['password'],
              'password errors',
              ['Password must include a symbol.'],
            )
            .having(
              (error) => error.errors['city'],
              'city errors',
              ['Enter a real city name.'],
            )
            .having(
              (error) => error.userMessage(
                fieldLabels: const {'password': 'Password', 'city': 'City'},
              ),
              'user message',
              'Password: Password must include a symbol.\nCity: Enter a real city name.',
            ),
      ),
    );
  });
}
