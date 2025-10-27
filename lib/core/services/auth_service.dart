import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:transconnect/core/services/api_client.dart';
import 'package:transconnect/models/user.dart';
import 'package:transconnect/core/services/shared_preferences_service.dart';

class AuthService extends ApiClient with ChangeNotifier {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  // ApiClient() constructor is implicitly called here.
  AuthService._internal();

  // Define the key used for the auth token in shared preferences. 
  // It MUST match the key used in _saveUser and the key expected by ApiClient (which we assume is 'user_token' now).
  static const String _tokenKey = 'user_token';
  static const String _usernameKey = 'username';
  static const String _passwordKey = 'password'; 
  
  // Use a StreamController to broadcast user state changes.
  final _authStateController = StreamController<User?>.broadcast();
  // final SharedPreferencesService _prefsService = SharedPreferencesService(); // REMOVED
  
  // A private variable to hold the current user.
  User? _currentUser;
  
  // Expose the stream to outside classes.
  Stream<User?> get authStateChanges => _authStateController.stream;
  
  // Expose the current user.
  User? get currentUser => _currentUser;

  Future<User> getCurrentUser() async {
    if (_currentUser != null) {
      return _currentUser!;
    }

    final token = await getToken();
    if (token == null) {
      throw Exception('User not authenticated');
    }

    final userData = await read(
      urlPath: 'api/user/me/',
      jsonHeaders: authHeaders,
    ) as Map<String, dynamic>;

    _currentUser = User.fromJson(userData);
    return _currentUser!;
  }

  Future<void> logout() async {
    await _clearUser();
  }

  /// Initializes the service, loading the user session from storage.
  /// Uses the inherited _prefsService (which is private to ApiClient).
  Future<void> init() async {
    // Access the shared preferences data via the inherited methods (must use the same keys).
    // Note: Since _prefsService is private in ApiClient, we'll access it 
    // indirectly or assume a public method is available if needed, but for now 
    // we use the private fields that ApiClient's constructor uses.
    // However, since the keys used in ApiClient and AuthService differ ('authToken' vs 'user_token'), 
    // we must temporarily use a direct SharedPreferencesService instance or adjust ApiClient.
    // Assuming the ApiClient token key is now 'user_token' for this service.
    
    // TEMPORARY SOLUTION: Since ApiClient's constructor is private, we must rely on 
    // the inherited ApiClient's instance of SharedPreferencesService. 
    // Since we can't access ApiClient's private _prefsService, 
    // we'll temporarily re-introduce the singleton access to get the initial data.
    // BEST PRACTICE: ApiClient should provide a public getter for the prefs service 
    // or expose a method to get data by key. Given the constraints, we'll re-add the singleton access.
    
    final prefsService = SharedPreferencesService();
    final token = prefsService.getData(_tokenKey);
    final username = prefsService.getData(_usernameKey);
    final password = prefsService.getData(_passwordKey);

    if (token != null && username != null && password != null) {
      try {
        // We can't use fetchUserFromToken because we don't know the password
        // The original logic re-signs in the user.
        await signIn(username: username, password: password);
      } catch (e) {
        // If sign-in fails (e.g., token expired, password changed), clear session.
        await signOut();
      }
    }
  
  // Private method to save user data.
  Future<void> _saveUser(User user, String token, {String? password}) async {
    _currentUser = user;
    _authStateController.add(user);

    final prefsService = SharedPreferencesService();
    await prefsService.saveData(_tokenKey, token);
    await prefsService.saveData(_usernameKey, user.username);
    if (password != null) {
      await prefsService.saveData(_passwordKey, password);
    }
    notifyListeners(); // Notify listeners of the change
  }

  // Private method to clear user data on logout.
  Future<void> _clearUser() async {
    _currentUser = null;
{{ ... }}
    final prefsService = SharedPreferencesService();
    await prefsService.clearData(_tokenKey);
    await prefsService.clearData(_usernameKey);
    await prefsService.clearData(_passwordKey);
    notifyListeners(); // Notify listeners of the change
  }

  Future<bool> isUserAuthenticated() async {
    return _currentUser != null;
  }

  Future<void> signUp({
    required String email,
    required String password,
    required String password2,
    required String username,
    required String city,
    required String flair,
    required String statusMessage,
  }) async {
    // No headers required for a public endpoint (Content-Type is handled in the post method).
    final jsonHeaders = {'Content-Type': 'application/json'};
    
    final jsonPayload = {
      'email': email,
      'password': password,
      'password2': password2,
      'username': username,
      'city': city,
      'flair': flair,
      'status_message': statusMessage,
    };
    // The post method now processes the response for us.
    // We expect a 201 Created on success.
    await post(
      urlPath: '/api/signup/', 
      jsonHeaders: jsonHeaders, 
      jsonPayload: jsonPayload,
      expectedStatusCode: 201,
    ); 
    
    // After successful registration, sign in the user to get the token
    await signIn(username: username, password: password);
  }

  Future<void> signIn({
    required String username, 
    required String password,
  }) async {
    // No headers required for a public endpoint (Content-Type is handled in the post method).
    final jsonHeaders = {'Content-Type': 'application/json'};
    
    final jsonPayload = {'username': username, 'password': password};
    
    // The post method now processes the response for us and returns the decoded body on 200 OK.
    final data = await post(
      urlPath: '/api/login/',
      jsonHeaders: jsonHeaders, 
      jsonPayload: jsonPayload
    ) as Map<String, dynamic>;

    if (data.containsKey('user') && data.containsKey('token')) {
      final Map<String, dynamic> userData = data['user'];
      final String token = data['token'];
      final user = User.fromJson(userData);
      
      // Save the user data including the token and (unrecommended) password.
      await _saveUser(user, token, password: password);
    } else {
      // Throw an exception if the format is unexpected, which will be caught by the calling function.
      throw Exception('Invalid response format from login API. Missing user or token.');
    }
  }

  Future<User> getProfile() async {
    final userData = await read(
      urlPath: '/api/profile/',
      jsonHeaders: authHeaders,
    ) as Map<String, dynamic>;

    final user = User.fromJson(userData);
    _currentUser = user; // Update the local user cache
    notifyListeners();
    return user;
  }

  Future<String?> getToken() async {
    final prefsService = SharedPreferencesService();
    return prefsService.getData(_tokenKey);
  }

  Future<void> signOut() async {
    await _clearUser();
  }

  Future<User> updateProfile(Map<String, dynamic> updates) async {
    final data = await update(
      urlPath: '/api/profile/',
      jsonHeaders: authHeaders,
      jsonPayload: updates,
    ) as Map<String, dynamic>;

    final user = User.fromJson(data);
    await _saveUser(user, authToken);
    return user;
  }

  Future<List<User>> getAllUsers() async {
    try {
      final result = await read(
        urlPath: 'api/users/',
        jsonHeaders: authHeaders,
      );
      if (result is List) {
        if (result.isEmpty) {
          return [];
        }
        final List<User> users = result
            .map((userJson) => User.fromJson(userJson as Map<String, dynamic>))
            .toList();

        return users;
      } else {
        return [];
      }
    } catch (e) {
      return [];
    }
  }
}