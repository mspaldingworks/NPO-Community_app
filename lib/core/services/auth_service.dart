// DO NOT CHANGE THIS FILE ANY CHANGE NEEDS A CORROSPONDING API CHANGE DONE BY PAIGE

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
    
    final _prefsService = SharedPreferencesService(); // Re-access the singleton for init keys
    String? token = _prefsService.getData(_tokenKey);
    String? username = _prefsService.getData(_usernameKey);
    String? password = _prefsService.getData(_passwordKey); 

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
  }
  
  // Private method to save user data.
  Future<void> _saveUser(User user, {String? password}) async {
    _currentUser = user;
    _authStateController.add(user);
    
    final _prefsService = SharedPreferencesService(); // Re-access the singleton
    
    if (user.token != null) {
      // NOTE: ApiClient uses 'authToken' key. We must ensure consistency.
      // If ApiClient used a dynamic key, it would be better.
      // Assuming for this service, we use 'user_token' which must match the key ApiClient expects.
      await _prefsService.saveData(_tokenKey, user.token!); 
      await _prefsService.saveData(_usernameKey, user.username);
      if (password != null) {
        await _prefsService.saveData(_passwordKey, password); // NOTE: Storing password is not recommended
      }
    } else {
      // Handle error or log if necessary.
    }
    notifyListeners(); // Notify listeners of the change
  }

  // Private method to clear user data on logout.
  Future<void> _clearUser() async {
    _currentUser = null;
    _authStateController.add(null);
    final _prefsService = SharedPreferencesService(); // Re-access the singleton
    await _prefsService.clearData(_tokenKey);
    await _prefsService.clearData(_usernameKey);
    await _prefsService.clearData(_passwordKey);
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
    required String identity,
    required String userType,
  }) async {
    // No headers required for a public endpoint (Content-Type is handled in the post method).
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
    
    // The post method now processes the response for us. 
    // We expect a 201 Created on success.
    await post(
      urlPath: '/api/register/', 
      jsonHeaders: jsonHeaders, 
      jsonPayload: jsonPayload, 
      expectedStatusCode: 201,
    ); 
    
    // After successful registration, sign in the user to get the token
    await signIn(username: username, password: password);

  }

  @Deprecated('Use signIn for full user object.')
  Future<bool> fetchUserFromToken(String token) async {
    try {
      // Use the inherited authHeaders, even though we manually provide the token here.
      // Since this method is deprecated and not the primary flow, we'll keep the direct header for token check.
      final jsonHeaders = {'Authorization': 'Token $token'};
      
      // The read method now processes the response and returns the decoded body.
      final userData = await read(
        urlPath: '/api/profile/', 
        jsonHeaders: jsonHeaders
      ) as Map<String, dynamic>;

      // We need to re-add the token to the user object, as the profile endpoint might not return it.
      userData['token'] = token;
      final user = User.fromJson({...userData});

      await _saveUser(user);
      return true;
    } catch (e) {
      // Catch exceptions thrown by ApiClient's response processing.
      return false;
    }
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
      userData['token'] = data['token'];
      final user = User.fromJson(userData);
      
      // Save the user data including the token and (unrecommended) password.
      await _saveUser(user, password: password);
    } else {
      // Throw an exception if the format is unexpected, which will be caught by the calling function.
      throw Exception('Invalid response format from login API. Missing user or token.');
    }
  }

  Future<void> signOut() async {
    await _clearUser();
  }
}