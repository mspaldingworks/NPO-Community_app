import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:npo_community/core/services/auth_service.dart';
import 'package:npo_community/features/onboarding_tour/widgets/tour_anchor.dart';

typedef SignInHandler =
    Future<void> Function({required String username, required String password});

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key, this.onSignIn});

  final SignInHandler? onSignIn;

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final AuthService _authService = AuthService();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _signIn() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final signIn = widget.onSignIn ?? _authService.signIn;
      await signIn(
        username: _usernameController.text.trim(),
        password: _passwordController.text,
      );
      // The router's refreshListenable will handle navigation on auth state change.
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(_errorMessage(e))));
      }
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final inputBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Colors.white70, width: 1.4),
    );

    InputDecoration themedInput(String label, IconData icon) => InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white, fontSize: 16),
      prefixIcon: Icon(icon, color: Colors.white),
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.08),
      enabledBorder: inputBorder,
      focusedBorder: inputBorder.copyWith(
        borderSide: const BorderSide(color: Colors.white, width: 1.6),
      ),
      border: inputBorder,
    );

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/onboarding'),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(color: Color(0xFF17324D)),
        child: Container(
          color: Colors.black.withValues(alpha: 0.55),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const TourAnchor(
                  name: 'Sign In',
                  child: Text(
                    'Sign In',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _usernameController,
                  style: const TextStyle(color: Colors.white, fontSize: 18),
                  decoration: themedInput('Username', Icons.person),
                  keyboardType: TextInputType.text,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _passwordController,
                  style: const TextStyle(color: Colors.white, fontSize: 18),
                  decoration: themedInput('Password', Icons.lock).copyWith(
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility
                            : Icons.visibility_off,
                        color: Colors.white,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscurePassword = !_obscurePassword;
                        });
                      },
                    ),
                  ),
                  obscureText: _obscurePassword,
                ),
                const SizedBox(height: 24),
                _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : TourAnchor(
                        name: 'Sign In',
                        child: ElevatedButton(
                          onPressed: _signIn,
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: const Text(
                            'Sign In',
                            style: TextStyle(fontSize: 18),
                          ),
                        ),
                      ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () => context.go('/signup'),
                  child: const Text(
                    "Don't have an account? Register",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _errorMessage(Object error) {
    final message = error.toString();
    return message.startsWith('Exception: ')
        ? message.substring('Exception: '.length)
        : message;
  }
}
