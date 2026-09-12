import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:npo_community/core/config/app_config.dart';
import 'package:npo_community/core/services/api_client.dart';
import 'package:npo_community/models/user.dart';
import 'package:npo_community/core/services/shared_preferences_service.dart';
import 'package:npo_community/features/onboarding_tour/services/onboarding_tour_storage.dart';

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

    final userData =
        await read(urlPath: 'api/user/me/', jsonHeaders: authHeaders)
            as Map<String, dynamic>;

    _currentUser = User.fromJson(userData);
    return _currentUser!;
  }

  Future<void> logout() async {
    await _clearUser();
  }

  /// Initializes the service, restoring the session from the stored token.
  ///
  /// The token alone is enough to re-establish the session, so no password is
  /// kept on the device. Any password persisted by an older build is deleted
  /// the first time this runs.
  Future<void> init() async {
    final prefsService = SharedPreferencesService();

    // Migration: older builds stored the password in plain text.
    if (prefsService.getData(_passwordKey) != null) {
      await prefsService.clearData(_passwordKey);
    }

    final token = prefsService.getData(_tokenKey);
    if (token == null) {
      return;
    }

    try {
      final userData =
          await read(urlPath: 'api/user/me/', jsonHeaders: authHeaders)
              as Map<String, dynamic>;
      await _saveUser(User.fromJson(userData), token);
    } catch (_) {
      // Token rejected, revoked, or the server is unreachable — start signed out.
      await signOut();
    }
  }

  // Private method to save user data.
  Future<void> _saveUser(
    User user,
    String token, {
    bool setTourPending = false,
  }) async {
    _currentUser = user;
    _authStateController.add(user);

    final prefsService = SharedPreferencesService();
    await prefsService.saveData(_tokenKey, token);
    await prefsService.saveData(_usernameKey, user.username);

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
    required DateTime dateOfBirth,
    required bool adultAttestation,
    required bool conductPolicyAccepted,
    File? profileImage,
  }) async {
    final uri = AppConfig.current.apiUri('/api/signup/');
    final cleanedPronouns = pronouns
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty)
        .toList();
    final pronounString = cleanedPronouns.join(', ');
    // The API takes a plain YYYY-MM-DD date, and requires both attestations.
    String two(int v) => v.toString().padLeft(2, '0');
    final dateOfBirthValue =
        '${dateOfBirth.year}-${two(dateOfBirth.month)}-${two(dateOfBirth.day)}';

    Future<http.Response> sendMultipart(File imageFile) async {
      final request = http.MultipartRequest('POST', uri)
        ..fields['email'] = email
        ..fields['password'] = password
        ..fields['password2'] = password2
        ..fields['username'] = username
        ..fields['city'] = city
        ..fields['flair'] = pronounString
        ..fields['pronouns'] = pronounString
        ..fields['status_message'] = statusMessage
        ..fields['date_of_birth'] = dateOfBirthValue
        ..fields['adult_attestation'] = adultAttestation.toString()
        ..fields['conduct_policy_accepted'] = conductPolicyAccepted.toString();

      request.files.add(
        await http.MultipartFile.fromPath('profile_pic', imageFile.path),
      );

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
        'pronouns': pronounString,
        'status_message': statusMessage,
        'date_of_birth': dateOfBirthValue,
        'adult_attestation': adultAttestation,
        'conduct_policy_accepted': conductPolicyAccepted,
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

  /// ApiClient reports failures as
  /// "Failed to create resource: Exception: <server message>". Peel the
  /// wrappers off so the sign-in screen shows the server's own wording.
  static String _unwrapError(Object error) {
    var message = error.toString();
    const marker = 'Exception:';
    while (message.contains(marker)) {
      message = message.substring(message.indexOf(marker) + marker.length);
    }
    message = message.trim();
    return message.isEmpty ? 'Sign in failed. Please try again.' : message;
  }

  Future<void> signIn({
    required String username,
    required String password,
  }) async {
    // No headers required for a public endpoint (Content-Type is handled in the post method).
    final jsonHeaders = {'Content-Type': 'application/json'};

    final jsonPayload = {'username': username, 'password': password};

    // The post method now processes the response for us and returns the decoded body on 200 OK.
    final Map<String, dynamic> data;
    try {
      data =
          await post(
                urlPath: '/api/login/',
                jsonHeaders: jsonHeaders,
                jsonPayload: jsonPayload,
              )
              as Map<String, dynamic>;
    } catch (e) {
      throw SignInException(_unwrapError(e));
    }

    if (data.containsKey('user') && data.containsKey('token')) {
      final Map<String, dynamic> userData = data['user'];
      final String token = data['token'];
      final user = User.fromJson(userData);

      // Only the token is persisted; the password is never written to disk.
      await _saveUser(user, token, setTourPending: true);
    } else {
      // Throw an exception if the format is unexpected, which will be caught by the calling function.
      throw Exception(
        'Invalid response format from login API. Missing user or token.',
      );
    }
  }

  Future<User> getProfile() async {
    final userData =
        await read(urlPath: '/api/profile/', jsonHeaders: authHeaders)
            as Map<String, dynamic>;

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
    final data =
        await update(
              urlPath: '/api/profile/',
              jsonHeaders: authHeaders,
              jsonPayload: updates,
            )
            as Map<String, dynamic>;

    final user = User.fromJson(data);
    await _saveUser(user, authToken);
    return user;
  }

  Future<User> updateProfileOptimistically({
    required Map<String, dynamic> updates,
    required User optimisticUser,
  }) async {
    final previous = _currentUser;
    _currentUser = optimisticUser;
    notifyListeners();

    try {
      return await updateProfile(updates);
    } catch (e) {
      _currentUser = previous;
      notifyListeners();
      rethrow;
    }
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

class SignInException implements Exception {
  final String message;

  SignInException(this.message);

  @override
  String toString() => message;
}

class SignUpException implements Exception {
  final String? message;
  final Map<String, List<String>> errors;

  SignUpException({this.message, Map<String, List<String>>? errors})
    : errors = errors ?? {};

  @override
  String toString() => message ?? 'Sign up failed.';
}
