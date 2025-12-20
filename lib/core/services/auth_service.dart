import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:transconnect/core/services/api_client.dart';
import 'package:transconnect/models/user.dart';
import 'package:transconnect/core/services/shared_preferences_service.dart';
import 'package:transconnect/features/onboarding_tour/services/onboarding_tour_storage.dart';

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
        // We can't use fetchUserFromToken because we don't know the password.
        // The original logic re-signs in the user.
        await signIn(username: username, password: password);
      } catch (_) {
        // If sign-in fails (e.g., token expired, password changed), clear session.
        await signOut();
      }
    }
  }

  // Private method to save user data.
  Future<void> _saveUser(User user, String token, {String? password, bool setTourPending = false}) async {
    _currentUser = user;
    _authStateController.add(user);

    final prefsService = SharedPreferencesService();
    await prefsService.saveData(_tokenKey, token);
    await prefsService.saveData(_usernameKey, user.username);
    if (password != null) {
      await prefsService.saveData(_passwordKey, password);
    }

    if (setTourPending) {
      final username = user.username;
      if (username.trim().isNotEmpty) {
        final seen = await OnboardingTourStorage.hasSeen(username);
        if (!seen) {
          await OnboardingTourStorage.markPendingStart(username);
        }
      }
    }
    notifyListeners(); // Notify listeners of the change
  }

  // Private method to clear user data on logout.
  Future<void> _clearUser() async {
    _currentUser = null;
    _authStateController.add(null);
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
    required List<String> pronouns,
    required String statusMessage,
    File? profileImage,
  }) async {
    final uri = Uri.parse('https://api.luxashome.com/api/signup/');
    final cleanedPronouns =
        pronouns.map((p) => p.trim()).where((p) => p.isNotEmpty).toList();
    final pronounString = cleanedPronouns.join(', ');

    Future<http.Response> sendMultipart(File imageFile) async {
      final request = http.MultipartRequest('POST', uri)
        ..fields['email'] = email
        ..fields['password'] = password
        ..fields['password2'] = password2
        ..fields['username'] = username
        ..fields['city'] = city
        ..fields['flair'] = pronounString
        ..fields['status_message'] = statusMessage;

      request.files.add(await http.MultipartFile.fromPath(
        'profile_pic',
        imageFile.path,
      ));

      final streamedResponse = await request.send();
      return http.Response.fromStream(streamedResponse);
    }

    Future<http.Response> sendJson() async {
      final payload = jsonEncode({
        'email': email,
        'password': password,
        'password2': password2,
        'username': username,
        'city': city,
        'flair': pronounString,
        'status_message': statusMessage,
      });

      return http.post(
        uri,
        headers: const {'Content-Type': 'application/json'},
        body: payload,
      );
    }

    http.Response response;
    try {
      response = profileImage != null
          ? await sendMultipart(profileImage)
          : await sendJson();
    } catch (e) {
      throw SignUpException(
        message:
            'Unable to reach the server. Please check your connection and try again.',
      );
    }

    if (response.statusCode == 201) {
      await signIn(username: username, password: password);
      return;
    }

    Map<String, dynamic>? decodedBody;
    try {
      if (response.body.isNotEmpty) {
        decodedBody = jsonDecode(response.body) as Map<String, dynamic>;
      }
    } catch (_) {
      // Ignore decoding errors; fall back to generic messaging below.
    }

    if (decodedBody != null) {
      final errors = <String, List<String>>{};
      String? message;

      decodedBody.forEach((key, value) {
        if (key == 'detail' && value is String) {
          message = value;
        } else if (value is List) {
          errors[key] = value.map((item) => item.toString()).toList();
        } else if (value is String) {
          errors[key] = [value];
        }
      });

      throw SignUpException(
        message: message ?? 'Registration failed. Please review your details.',
        errors: errors,
      );
    }

    throw SignUpException(
      message: 'Registration failed with status code ${response.statusCode}.',
    );
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
      await _saveUser(user, token, password: password, setTourPending: true);
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

class SignUpException implements Exception {
  final String? message;
  final Map<String, List<String>> errors;

  SignUpException({this.message, Map<String, List<String>>? errors})
      : errors = errors ?? {};

  @override
  String toString() => message ?? 'Sign up failed.';
}