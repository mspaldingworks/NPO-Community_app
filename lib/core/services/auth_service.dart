import 'dart:async';
import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

// TODO: Replace with your own User model if needed.
typedef User = String; 
// TODO: Replace with your own AuthState model if needed.
typedef AuthState = String;

class AuthService {
  final _storage = const FlutterSecureStorage();
  // static const _baseUrl = 'https://api.luxashome.com';
  static const _baseUrl = '';

  final _authStateController = StreamController<String?>.broadcast();

  /// Stream of authentication state changes.
  Stream<String?> get authStateChanges => _authStateController.stream;

  /// Get the current user.
  Future<String?> get currentUser async {
    return await _storage.read(key: 'auth_token');
  }

  /// Sign up a new user.
  Future<void> signUp({
    required String email,
    required String password,
    required String username,
  }) async {
    // TODO: Implement with api.luxashome.com
    // You'll need the registration endpoint and expected request body.
    print('Sign up with $email');
    await Future.delayed(const Duration(seconds: 1));
    // For now, we'll just log the user in with a dummy token after 'signing up'
    const dummyToken = 'dummy_token_for_signup';
    await _storage.write(key: 'auth_token', value: dummyToken);
    _authStateController.add(dummyToken);
  }

  /// Sign in an existing user.
  Future<void> signIn(String username, String password) async {
    // final url = Uri.parse('$_baseUrl/api/token/');
    // try {
    //   final response = await http.post(
    //     url,
    //     headers: {'Content-Type': 'application/json'},
    //     body: jsonEncode(<String, String>{
    //       'username': username, 
    //       'password': password,
    //     }),
    //   );
    //
    //   print('Response Status Code: ${response.statusCode}');
    //   print('Response Body: ${response.body}');
    //
    //   if (response.statusCode == 200) {
    //     final data = jsonDecode(response.body);
    //     final token = data['token']; 
    //     await _storage.write(key: 'auth_token', value: token);
    //     _authStateController.add(token);
    //   } else {
    //     throw Exception('Failed to sign in: ${response.body}');
    //   }
    // } catch (e) {
    //   throw Exception('Failed to sign in: $e');
    // }

    // Temporary fix: bypass network call and use a dummy token
    print('Bypassing sign in and using dummy token');
    const dummyToken = 'dummy_token_for_signin';
    await _storage.write(key: 'auth_token', value: dummyToken);
    _authStateController.add(dummyToken);
  }

  /// Sign out the current user.
  Future<void> signOut() async {
    await _storage.delete(key: 'auth_token');
    _authStateController.add(null);
  }
}
