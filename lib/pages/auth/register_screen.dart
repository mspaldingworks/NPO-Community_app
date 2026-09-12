import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:npo_community/core/services/auth_service.dart';
import 'package:npo_community/features/onboarding_tour/widgets/tour_anchor.dart';

typedef SignUpHandler =
    Future<void> Function({
      required String email,
      required String password,
      required String password2,
      required String username,
      required String city,
      required DateTime dateOfBirth,
      required bool adultAttestation,
      required bool conductPolicyAccepted,
      File? profileImage,
    });

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key, this.onSignUp});

  final SignUpHandler? onSignUp;

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _ProfileImagePicker extends StatelessWidget {
  const _ProfileImagePicker({
    required this.profileImage,
    required this.onPickImage,
  });

  final File? profileImage;
  final VoidCallback onPickImage;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TourAnchor(
          name: 'Add Profile Picture',
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onPickImage,
            child: Stack(
              alignment: Alignment.bottomRight,
              children: [
                CircleAvatar(
                  radius: 50,
                  backgroundColor: Colors.white.withValues(alpha: 0.18),
                  backgroundImage: profileImage != null
                      ? FileImage(profileImage!)
                      : null,
                  child: profileImage == null
                      ? const Icon(
                          Icons.person,
                          size: 50,
                          color: Colors.white70,
                        )
                      : null,
                ),
                Positioned(
                  bottom: 4,
                  right: 4,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.55),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white70, width: 1.2),
                    ),
                    padding: const EdgeInsets.all(8),
                    child: const Icon(
                      Icons.camera_alt,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Add Profile Picture',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.85),
            fontSize: 16,
          ),
        ),
      ],
    );
  }
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _usernameController = TextEditingController();
  final _zipCodeController = TextEditingController();
  final _authService = AuthService();
  final ImagePicker _picker = ImagePicker();
  File? _profileImage;
  DateTime? _dateOfBirth;
  bool _adultAttestation = false;
  bool _conductPolicyAccepted = false;
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  String? _usernameError;
  String? _emailError;
  String? _passwordError;
  String? _confirmPasswordError;
  String? _cityError;
  String? _dateOfBirthError;
  final GlobalKey<FormFieldState<bool>> _adultAttestationKey =
      GlobalKey<FormFieldState<bool>>();
  final GlobalKey<FormFieldState<bool>> _conductPolicyKey =
      GlobalKey<FormFieldState<bool>>();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _usernameController.dispose();
    _zipCodeController.dispose();
    super.dispose();
  }

  Future<void> _pickProfileImage() async {
    try {
      final XFile? picked = await _picker.pickImage(
        source: ImageSource.gallery,
      );
      if (picked != null) {
        setState(() {
          _profileImage = File(picked.path);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Unable to pick image: $e')));
      }
    }
  }

  Widget _buildAttestationField({
    required GlobalKey<FormFieldState<bool>> fieldKey,
    required bool value,
    required String label,
    required String errorText,
    required ValueChanged<bool> onChanged,
  }) {
    return FormField<bool>(
      key: fieldKey,
      initialValue: value,
      validator: (fieldValue) => fieldValue == true ? null : errorText,
      builder: (field) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              onTap: _isLoading
                  ? null
                  : () {
                      final next = !value;
                      onChanged(next);
                      field.didChange(next);
                    },
              borderRadius: BorderRadius.circular(8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Checkbox(
                    value: value,
                    onChanged: _isLoading
                        ? null
                        : (next) {
                            final selected = next ?? false;
                            onChanged(selected);
                            field.didChange(selected);
                          },
                    side: BorderSide(
                      color: Colors.white.withValues(alpha: 0.7),
                      width: 1.6,
                    ),
                    checkColor: Colors.white,
                    fillColor: WidgetStateProperty.resolveWith(
                      (states) => states.contains(WidgetState.selected)
                          ? Colors.white.withValues(alpha: 0.35)
                          : Colors.transparent,
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(
                        label,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (field.hasError) ...[
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.only(left: 12),
                child: Text(
                  field.errorText ?? '',
                  style: const TextStyle(color: Colors.redAccent, fontSize: 13),
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  static int _ageOn(DateTime birthDate, DateTime today) {
    var age = today.year - birthDate.year;
    if (today.month < birthDate.month ||
        (today.month == birthDate.month && today.day < birthDate.day)) {
      age -= 1;
    }
    return age;
  }

  Future<void> _pickDateOfBirth() async {
    final today = DateTime.now();
    final eighteenthBirthday = DateTime(
      today.year - 18,
      today.month,
      today.day,
    );
    final picked = await showDatePicker(
      context: context,
      initialDate: _dateOfBirth ?? eighteenthBirthday,
      firstDate: DateTime(today.year - 120),
      lastDate: eighteenthBirthday,
      helpText: 'Select your date of birth',
    );

    if (picked == null) {
      return;
    }

    setState(() {
      _dateOfBirth = picked;
      _dateOfBirthError = null;
    });
  }

  Future<void> _signUp() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_passwordController.text != _confirmPasswordController.text) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Passwords do not match')));
      }
      return;
    }

    // The API requires a date of birth and both attestations, and rejects
    // anyone under 18. Check here so the trip to the server isn't wasted.
    final dateOfBirth = _dateOfBirth;
    if (dateOfBirth == null) {
      setState(() {
        _dateOfBirthError = 'Please enter your date of birth';
      });
      return;
    }
    if (_ageOn(dateOfBirth, DateTime.now()) < 18) {
      setState(() {
        _dateOfBirthError = 'Accounts are limited to adults age 18 or older';
      });
      return;
    }
    if (!_adultAttestation || !_conductPolicyAccepted) {
      _adultAttestationKey.currentState?.validate();
      _conductPolicyKey.currentState?.validate();
      return;
    }

    setState(() {
      _isLoading = true;
      _usernameError = null;
      _emailError = null;
      _passwordError = null;
      _confirmPasswordError = null;
      _cityError = null;
      _dateOfBirthError = null;
    });

    try {
      final signUp = widget.onSignUp ?? _authService.signUp;
      await signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        password2: _confirmPasswordController.text,
        username: _usernameController.text.trim(),
        city: _zipCodeController.text.trim(),
        dateOfBirth: dateOfBirth,
        adultAttestation: _adultAttestation,
        conductPolicyAccepted: _conductPolicyAccepted,
        profileImage: _profileImage,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Registration successful!')),
        );
        // The router's refreshListenable will handle navigation on auth state change.
      }
    } on SignUpException catch (e) {
      if (mounted) {
        setState(() {
          _usernameError = e.errors['username']?.join(' ');
          _emailError = e.errors['email']?.join(' ');
          _passwordError = e.errors['password']?.join(' ');
          _confirmPasswordError = e.errors['password2']?.join(' ');
          _cityError = e.errors['city']?.join(' ');
          _dateOfBirthError = e.errors['date_of_birth']?.join(' ');
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e.userMessage(
                fieldLabels: const {
                  'username': 'Username',
                  'email': 'Email',
                  'password': 'Password',
                  'password2': 'Confirm Password',
                  'city': 'City',
                  'date_of_birth': 'Date of Birth',
                  'adult_attestation': 'Age Attestation',
                  'conduct_policy_accepted': 'Conduct Policy',
                  'profile_pic': 'Profile Picture',
                },
              ),
            ),
          ),
        );
      }
    } on Exception catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(_errorMessage(e))));
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
        fillColor: Colors.white.withValues(alpha: 0.08),
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
        decoration: const BoxDecoration(color: Color(0xFF17324D)),
        child: Container(
          color: Colors.black.withValues(alpha: 0.55),
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

                    _ProfileImagePicker(
                      profileImage: _profileImage,
                      onPickImage: _pickProfileImage,
                    ),
                    const SizedBox(height: 24),

                    // Username Field
                    TextFormField(
                      controller: _usernameController,
                      style: const TextStyle(color: Colors.white, fontSize: 18),
                      decoration: themedInput(
                        label: 'Username',
                        icon: Icons.person,
                      ).copyWith(errorText: _usernameError),
                      onChanged: (_) {
                        if (_usernameError != null) {
                          setState(() {
                            _usernameError = null;
                          });
                        }
                      },
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
                      decoration: themedInput(
                        label: 'Email',
                        icon: Icons.email,
                      ).copyWith(errorText: _emailError),
                      keyboardType: TextInputType.emailAddress,
                      onChanged: (_) {
                        if (_emailError != null) {
                          setState(() {
                            _emailError = null;
                          });
                        }
                      },
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
                      ).copyWith(errorText: _passwordError),
                      obscureText: _obscurePassword,
                      onChanged: (_) {
                        if (_passwordError != null) {
                          setState(() {
                            _passwordError = null;
                          });
                        }
                      },
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
                            _obscureConfirmPassword
                                ? Icons.visibility
                                : Icons.visibility_off,
                            color: Colors.white,
                          ),
                          onPressed: () {
                            setState(() {
                              _obscureConfirmPassword =
                                  !_obscureConfirmPassword;
                            });
                          },
                        ),
                      ).copyWith(errorText: _confirmPasswordError),
                      obscureText: _obscureConfirmPassword,
                      onChanged: (_) {
                        if (_confirmPasswordError != null) {
                          setState(() {
                            _confirmPasswordError = null;
                          });
                        }
                      },
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

                    // City Field
                    TextFormField(
                      controller: _zipCodeController,
                      style: const TextStyle(color: Colors.white, fontSize: 18),
                      decoration: themedInput(
                        label: 'City',
                        icon: Icons.location_on,
                      ).copyWith(errorText: _cityError),
                      onChanged: (_) {
                        if (_cityError != null) {
                          setState(() {
                            _cityError = null;
                          });
                        }
                      },
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your city';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Date of Birth
                    TourAnchor(
                      name: 'Date of Birth',
                      child: InkWell(
                        onTap: _isLoading ? null : _pickDateOfBirth,
                        borderRadius: BorderRadius.circular(8),
                        child: InputDecorator(
                          decoration: themedInput(
                            label: 'Date of Birth',
                            icon: Icons.cake,
                          ).copyWith(errorText: _dateOfBirthError),
                          child: Text(
                            _dateOfBirth == null
                                ? 'Tap to select'
                                : '${_dateOfBirth!.month}/${_dateOfBirth!.day}/${_dateOfBirth!.year}',
                            style: TextStyle(
                              color: _dateOfBirth == null
                                  ? Colors.white.withValues(alpha: 0.6)
                                  : Colors.white,
                              fontSize: 18,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Adult attestation — required by the API.
                    _buildAttestationField(
                      fieldKey: _adultAttestationKey,
                      value: _adultAttestation,
                      label: 'I confirm that I am at least 18 years old.',
                      errorText: 'You must confirm that you are at least 18',
                      onChanged: (value) {
                        setState(() => _adultAttestation = value);
                      },
                    ),
                    const SizedBox(height: 8),

                    // Conduct policy — required by the API.
                    _buildAttestationField(
                      fieldKey: _conductPolicyKey,
                      value: _conductPolicyAccepted,
                      label:
                          'I have read and accept the community conduct policy.',
                      errorText: 'You must accept the conduct policy',
                      onChanged: (value) {
                        setState(() => _conductPolicyAccepted = value);
                      },
                    ),
                    const SizedBox(height: 32),

                    // Sign Up Button
                    TourAnchor(
                      name: 'Sign Up',
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _signUp,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white.withValues(alpha: 0.18),
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
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                ),
                              )
                            : const Text(
                                'Sign Up',
                                style: TextStyle(fontSize: 16),
                              ),
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
                              : () => context.go('/login'),
                          child: const Text(
                            'Sign In',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
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

  String _errorMessage(Object error) {
    final message = error.toString();
    return message.startsWith('Exception: ')
        ? 'Registration failed: ${message.substring('Exception: '.length)}'
        : 'Registration failed: $message';
  }
}
