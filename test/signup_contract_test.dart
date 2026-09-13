// Pins the client half of the signup contract.
//
// The API requires date_of_birth, adult_attestation and
// conduct_policy_accepted. The client did not send them, so every signup came
// back 400, no account was ever created, and the symptom people reported was
// "login doesn't work". The API side is pinned in
// NPO-Community_api/npo_community_api/test_signup_contract.py; this is the
// other half, so the two cannot drift apart silently again.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:npo_community/core/services/api_client.dart';
import 'package:npo_community/core/services/auth_service.dart';
import 'package:npo_community/core/services/shared_preferences_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Must match REQUIRED_SIGNUP_FIELDS in the API's test_signup_contract.py.
const requiredSignupFields = <String>{
  'username',
  'password',
  'password2',
  'city',
  'program_year',
  'date_of_birth',
  'adult_attestation',
  'conduct_policy_accepted',
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await SharedPreferencesService().init();
  });

  tearDown(() {
    ApiClient.debugHttpClientOverride = null;
  });

  test('signUp sends every field the API requires', () async {
    Map<String, dynamic>? sent;

    ApiClient.debugHttpClientOverride = MockClient((request) async {
      if (request.url.path.contains('/api/signup/')) {
        sent = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(
          jsonEncode({'message': 'ok', 'token': 't'}),
          201,
          headers: {'content-type': 'application/json'},
        );
      }
      return http.Response(
        jsonEncode({
          'token': 't',
          'user': {'id': 1, 'username': 'contract', 'email': 'c@test.dev'},
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    });

    await AuthService().signUp(
      email: 'c@test.dev',
      password: 'C0ntr@ct!Str0ng',
      password2: 'C0ntr@ct!Str0ng',
      username: 'contract',
      city: '40218',
      programYear: 2015,
      dateOfBirth: DateTime(1990, 4, 17),
      adultAttestation: true,
      conductPolicyAccepted: true,
    );

    expect(sent, isNotNull, reason: 'signUp never posted to /api/signup/');
    expect(
      sent!.keys.toSet(),
      containsAll(requiredSignupFields),
      reason:
          'signUp dropped a field the API requires. Signups will 400 and it '
          'will look like login is broken. Keep this in step with '
          'REQUIRED_SIGNUP_FIELDS in the API repo.',
    );
  });

  test('signUp formats date_of_birth as the API expects', () async {
    Map<String, dynamic>? sent;

    ApiClient.debugHttpClientOverride = MockClient((request) async {
      if (request.url.path.contains('/api/signup/')) {
        sent = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(
          jsonEncode({'message': 'ok', 'token': 't'}),
          201,
          headers: {'content-type': 'application/json'},
        );
      }
      return http.Response(
        jsonEncode({
          'token': 't',
          'user': {'id': 1, 'username': 'contract', 'email': 'c@test.dev'},
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    });

    await AuthService().signUp(
      email: 'c@test.dev',
      password: 'C0ntr@ct!Str0ng',
      password2: 'C0ntr@ct!Str0ng',
      username: 'contract',
      city: '40218',
      programYear: 2015,
      // Single digits must be zero-padded, not '1990-4-7'.
      dateOfBirth: DateTime(1990, 4, 7),
      adultAttestation: true,
      conductPolicyAccepted: true,
    );

    expect(sent!['date_of_birth'], '1990-04-07');
    expect(sent!['adult_attestation'], isTrue);
    expect(sent!['conduct_policy_accepted'], isTrue);
  });
}
