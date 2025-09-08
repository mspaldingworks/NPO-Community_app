import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:transconnect/models/user.dart';

class AuthService {

  // Use a StreamController to broadcast user state changes.
  final _authStateController = StreamController<User?>.broadcast();
  
  // A private variable to hold the current user.
  User? _currentUser;
  
  // Expose the stream to outside classes.
  Stream<User?> get authStateChanges => _authStateController.stream;
  
  // Expose the current user.
  User? get currentUser => _currentUser;
  
  // Base URL for your API.
  final String _baseUrl = 'http://api.luxashome.com';

  // Private method to save user data.
  void _saveUser(User user) {
    _currentUser = user;
    _authStateController.add(user);
    // You can also add logic here to save the token securely, e.g., using flutter_secure_storage.
  }
  
  // Private method to clear user data on logout.
  void _clearUser() {
    _currentUser = null;
    _authStateController.add(null);
    // Add logic to delete the token here.
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
        final response = await http.post(
            Uri.parse('$_baseUrl/api/signup/'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
                'username': username,
                'password': password,
                'password2': password2,
                'email': email,
                'city': city,
                'flair': identity,
                'status_message': statusMessage,
            }),
        );

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
        final response = await http.get(
            // This is a placeholder; you'll need to use your actual endpoint.
            Uri.parse('$_baseUrl/api/profile/'),
            headers: {'Authorization': 'Token $token'},
        );

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
      final response = await http.post(
        Uri.parse('$_baseUrl/api/login/'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'username': username, 'password': password}),
      );
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
