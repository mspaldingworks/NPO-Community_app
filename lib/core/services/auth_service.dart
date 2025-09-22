import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:transconnect/core/services/api_client.dart';
import 'package:transconnect/models/user.dart';
import 'package:transconnect/core/services/shared_preferences_service.dart';

class AuthService extends ApiClient with ChangeNotifier {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  // Use a StreamController to broadcast user state changes.
  final _authStateController = StreamController<User?>.broadcast();
  final SharedPreferencesService _prefsService = SharedPreferencesService();
  
  // A private variable to hold the current user.
  User? _currentUser;
  
  // Expose the stream to outside classes.
  Stream<User?> get authStateChanges => _authStateController.stream;
  
  // Expose the current user.
  User? get currentUser => _currentUser;

  /// Initializes the service, loading the user session from storage.
  Future<void> init() async {
    String? token = _prefsService.getData('user_token');
    if (token != null) {
      await fetchUserFromToken(token);
    }
  }
  
  // Private method to save user data.
  Future<void> _saveUser(User user) async {
    _currentUser = user;
    _authStateController.add(user);
    if (user.token != null) {
      await _prefsService.saveData('user_token', user.token!);
    } else {
      // This case should not happen for a newly authenticated user.
      // Handle error or log if necessary.
    }
    notifyListeners(); // Notify listeners of the change
  }

  // Private method to clear user data on logout.
  Future<void> _clearUser() async {
    _currentUser = null;
    _authStateController.add(null);
    await _prefsService.clearData('user_token');
    notifyListeners(); // Notify listeners of the change
  }

  Future<bool> isUserAuthenticated() async {
    // Now that init() loads the user, we can just check the current state.
    return _currentUser != null;
  }

  Future<void> signUp({
    required String email,
    required String password,
    required String password2,
    required String username,
    required String city,
    required String identity,
    required String userType,
  }) async {
    try {
      String urlPath = '/api/register/';
      final jsonHeaders = {'Content-Type': 'application/json'};
      final jsonPayload = {
        'email': email,
        'password': password,
        'password2': password2,
        'username': username,
        'city': city,
        'identity': identity,
        'user_type': userType,
      };
      final response = await post(urlPath: urlPath, jsonHeaders: jsonHeaders, jsonPayload: jsonPayload);
      if (response.statusCode == 201) {
        // After successful registration, sign in the user to get the token
        await signIn(username: username, password: password);
      } else {
        throw Exception('Failed to register: ${response.body}');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<bool> fetchUserFromToken(String token) async {
    try {
      String urlPath = '/api/profile/';
      final jsonHeaders = {'Authorization': 'Token $token'};
      final response = await read(urlPath: urlPath, jsonHeaders: jsonHeaders);

      if (response.statusCode == 200) {
        final Map<String, dynamic> userData = jsonDecode(response.body);
        
        // Add the token to the user data before parsing
        userData['token'] = token;
        final user = User.fromJson({...userData});

        _saveUser(user);
        return true;
      } else {
        throw Exception('Failed to fetch user data with token: ${response.body}');            
      }
    } catch (e) {
      return false;
    }
  }

  Future<void> signIn({
    required String username, 
    required String password,
  }) async {
    try {
      String urlPath = '/api/login/';
      final jsonHeaders = {'Content-Type': 'application/json'};
      final jsonPayload = {'username': username, 'password': password};
      final response = await post(urlPath: urlPath, jsonHeaders: jsonHeaders, jsonPayload: jsonPayload);
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        
        // The user data is nested under the 'user' key.
        // We need to extract it and add the token before creating the User object.
        if (data.containsKey('user') && data.containsKey('token')) {
          final Map<String, dynamic> userData = data['user'];
          userData['token'] = data['token'];
          final user = User.fromJson(userData);
          _saveUser(user);
        } else {
          throw Exception('Invalid response format from login API.');
        }

      } else {
        // Handle login errors (e.g., wrong credentials).
        throw Exception('Failed to log in: ${response.body}');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<void> signOut() async {
    _clearUser();
  }
}
