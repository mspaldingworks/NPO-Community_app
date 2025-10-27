import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:transconnect/core/services/auth_service.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _usernameController = TextEditingController();
  final _zipCodeController = TextEditingController();
  final _statusMessageController = TextEditingController();
  final _authService = AuthService();
  String? _selectedFlair;
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  final List<String> _flairs = ['She/Her', 'He/Him', 'They/Them', 'Other'];

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _usernameController.dispose();
    _zipCodeController.dispose();
    _statusMessageController.dispose();
    super.dispose();
  }

  Future<void> _signUp() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_passwordController.text != _confirmPasswordController.text) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Passwords do not match')),
        );
      }
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      await _authService.signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
        password2: _confirmPasswordController.text.trim(),
        username: _usernameController.text.trim(),
        city: _zipCodeController.text.trim(),
        flair: _selectedFlair ?? '',
        statusMessage: _statusMessageController.text.trim(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Registration successful!')),
        );
        // The router's refreshListenable will handle navigation on auth state change.
      }
    } on Exception catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Registration failed: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final inputBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Colors.white70, width: 1.3),
    );

    InputDecoration themedInput({
      required String label,
      IconData? icon,
      Widget? suffix,
    }) {
      return InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white, fontSize: 16),
        prefixIcon: icon != null ? Icon(icon, color: Colors.white) : null,
        suffixIcon: suffix,
        filled: true,
        fillColor: Colors.white.withOpacity(0.08),
        enabledBorder: inputBorder,
        focusedBorder: inputBorder.copyWith(
          borderSide: const BorderSide(color: Colors.white, width: 1.6),
        ),
        border: inputBorder,
      );
    }

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
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/media/twc_primary_logo.png'),
            fit: BoxFit.cover,
            colorFilter: ColorFilter.mode(Colors.black45, BlendMode.darken),
          ),
        ),
        child: Container(
          color: Colors.black.withOpacity(0.55),
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Create Account',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),

                    // Username Field
                    TextFormField(
                      controller: _usernameController,
                      style: const TextStyle(color: Colors.white, fontSize: 18),
                      decoration: themedInput(label: 'Username', icon: Icons.person),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter a username';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Email Field
                    TextFormField(
                      controller: _emailController,
                      style: const TextStyle(color: Colors.white, fontSize: 18),
                      decoration: themedInput(label: 'Email', icon: Icons.email),
                      keyboardType: TextInputType.emailAddress,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your email';
                        }
                        if (!value.contains('@')) {
                          return 'Please enter a valid email';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Password Field
                    TextFormField(
                      controller: _passwordController,
                      style: const TextStyle(color: Colors.white, fontSize: 18),
                      decoration: themedInput(
                        label: 'Password',
                        icon: Icons.lock,
                        suffix: IconButton(
                          icon: Icon(
                            _obscurePassword ? Icons.visibility : Icons.visibility_off,
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
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter a password';
                        }
                        if (value.length < 6) {
                          return 'Password must be at least 6 characters';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Confirm Password Field
                    TextFormField(
                      controller: _confirmPasswordController,
                      style: const TextStyle(color: Colors.white, fontSize: 18),
                      decoration: themedInput(
                        label: 'Confirm Password',
                        icon: Icons.lock_outline,
                        suffix: IconButton(
                          icon: Icon(
                            _obscureConfirmPassword ? Icons.visibility : Icons.visibility_off,
                            color: Colors.white,
                          ),
                          onPressed: () {
                            setState(() {
                              _obscureConfirmPassword = !_obscureConfirmPassword;
                            });
                          },
                        ),
                      ),
                      obscureText: _obscureConfirmPassword,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please confirm your password';
                        }
                        if (value != _passwordController.text) {
                          return 'Passwords do not match';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Zip Code Field
                    TextFormField(
                      controller: _zipCodeController,
                      style: const TextStyle(color: Colors.white, fontSize: 18),
                      decoration: themedInput(label: 'ZIP Code', icon: Icons.location_on),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your ZIP code';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Flair Dropdown
                    DropdownButtonFormField<String>(
                      value: _selectedFlair,
                      dropdownColor: Colors.black.withOpacity(0.85),
                      iconEnabledColor: Colors.white,
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                      decoration: themedInput(label: 'Pronouns', icon: Icons.face),
                      items: _flairs.map((String flair) {
                        return DropdownMenuItem<String>(
                          value: flair,
                          child: Text(flair, style: const TextStyle(color: Colors.white)),
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                        setState(() {
                          _selectedFlair = newValue;
                        });
                      },
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please select your pronouns';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Status Message
                    TextFormField(
                      controller: _statusMessageController,
                      style: const TextStyle(color: Colors.white, fontSize: 18),
                      decoration: themedInput(
                        label: 'Status Message (Optional)',
                        icon: Icons.message,
                      ),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 32),

                    // Sign Up Button
                    ElevatedButton(
                      onPressed: _isLoading ? null : _signUp,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white.withOpacity(0.18),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Text(
                              'Sign Up',
                              style: TextStyle(fontSize: 16),
                            ),
                    ),
                    const SizedBox(height: 16),

                    // Sign In Link
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          'Already have an account? ',
                          style: TextStyle(color: Colors.white, fontSize: 16),
                        ),
                        TextButton(
                          onPressed: _isLoading
                              ? null
                              : () => context.go('/signin'),
                          child: const Text(
                            'Sign In',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
