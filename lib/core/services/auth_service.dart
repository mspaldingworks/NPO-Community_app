import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:transconnect/core/services/api_client.dart';
import 'package:transconnect/models/user.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:transconnect/core/services/shared_preferences_service.dart';

class AuthService extends ApiClient {

  // Use a StreamController to broadcast user state changes.
  final _authStateController = StreamController<User?>.broadcast();
  final SharedPreferencesService _prefsService = SharedPreferencesService();
  
  // A private variable to hold the current user.
  User? _currentUser;
  
  // Expose the stream to outside classes.
  Stream<User?> get authStateChanges => _authStateController.stream;
  
  // Expose the current user.
  User? get currentUser => _currentUser;
  
  // Private method to save user data.
  Future<void> _saveUser(User user) async {
    _currentUser = user;
    _authStateController.add(user);
    await _prefsService.saveData('user_token', user.token);
  }

  // Private method to clear user data on logout.
  Future<void> _clearUser() async {
    _currentUser = null;
    _authStateController.add(null);
    await _prefsService.clearData('user_token');
  }

  bool isUserAuthenticated(){
    return (_prefsService.getData('user_token') != null);
  }

  Future<void> signUp({
    required String username,
    required String password,
    required String password2,
    required String email,
    required String city,
    required String identity,
    String? statusMessage,
}) async {
    try {
        String urlPath = 'api/signup/';
        final jsonHeaders = {'Content-Type': 'application/json'};
        final jsonPayload = {
                'username': username,
                'password': password,
                'password2': password2,
                'email': email,
                'city': city,
                'flair': identity,
                'status_message': statusMessage,
            };
        final response = await create(urlPath: urlPath, jsonHeaders: jsonHeaders, jsonPayload: jsonPayload);

        print(response.body);

        if (response.statusCode == 201) {
            final Map<String, dynamic> data = jsonDecode(response.body);
            
            // Check for the success message.
            if (data['message'] == 'User registered successfully!') {
                final String token = data['token'];
                print('Sign up successful! Token received.');

                // Now, get the user's full data with the received token.
                await fetchUserFromToken(token);
            } else {
                // This case handles unexpected successful responses.
                throw Exception('Unexpected API response after signup: ${response.body}');
            }
        } else {
            // Handle registration errors from the API.
            throw Exception('Failed to sign up: ${response.body}');
        }
    } catch (e) {
        print('Sign up failed: $e');
        throw e;
    }
  }

  Future<void> fetchUserFromToken(String token) async {
    try {
        String urlPath = '/api/profile/';
        final jsonHeaders = {'Authorization': 'Token $token'};
        final response = await read(urlPath: urlPath, jsonHeaders: jsonHeaders);

        if (response.statusCode == 200) {
            final Map<String, dynamic> userData = jsonDecode(response.body);
            
            // Assuming your profile endpoint returns a JSON object that matches the User model.
            final user = User.fromJson({
                ...userData, // Merges the user data with the token.
                'token': token,
            });
            _saveUser(user);
            print('User data fetched successfully!');
        } else {
            throw Exception('Failed to fetch user data with token: ${response.body}');
        }
    } catch (e) {
        print('Error fetching user data: $e');
        throw e;
    }
  }

  Future<void> signIn({
    required String username, 
    required String password
  }) async {
    try {
      String urlPath = '/api/login/';
      final jsonHeaders = {'Content-Type': 'application/json'};
      final jsonPayload = {'username': username, 'password': password};
      final response = await create(urlPath: urlPath, jsonHeaders: jsonHeaders, jsonPayload: jsonPayload);
      print(response.statusCode);
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        print(response.body);
        // Assuming your API returns a JSON object that matches the User model.
        final user = User(
          uid: data['user']['id'].toString(),
          username: data['user']['username'],
          email: data['user']['email'],
          city: data['user']['city'],
          statusMessage: data['user']['status_message'],
          flair: data['user']['flair'],
          profilePic: data['user']['profile_pic'],
          token: data['token'],
        );

        _saveUser(user);

        print('Login successful!');        
      } else {
        // Handle login errors (e.g., wrong credentials).
        throw Exception('Failed to log in: ${response.body}');
      }
    } catch (e) {
      print('Login failed: $e');
      throw e;
    }
  }

  Future<void> signOut() async {
   //TODO: Add later
  }
}
