import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:npo_community/core/services/auth_service.dart';
import 'package:npo_community/features/onboarding_tour/widgets/tour_anchor.dart';
import 'package:npo_community/theme/app_theme.dart';
import 'package:npo_community/widgets/emerge/emerge_components.dart';

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
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/onboarding'),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Center(child: EmergeLogo(width: 240)),
              const SizedBox(height: 32),
              TourAnchor(
                name: 'Sign In',
                child: Text(
                  'Sign In',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _usernameController,
                decoration: const InputDecoration(
                  labelText: 'Username',
                  prefixIcon: Icon(Icons.person),
                ),
                keyboardType: TextInputType.text,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _passwordController,
                decoration: InputDecoration(
                  labelText: 'Password',
                  prefixIcon: const Icon(Icons.lock),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility
                          : Icons.visibility_off,
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
                        child: const Text('SIGN IN'),
                      ),
                    ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => context.go('/signup'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.periwinkle,
                ),
                child: const Text("Don't have an account? Register"),
              ),
              TextButton(
                key: const Key('claim-profile-link'),
                onPressed: () => context.go('/claim'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.periwinkle,
                ),
                child: const Text(
                  'Emerge KY alum with a claim code? Claim your profile',
                ),
              ),
            ],
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
