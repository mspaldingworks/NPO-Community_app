import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:npo_community/core/services/auth_service.dart';
import 'package:npo_community/features/onboarding_tour/widgets/tour_anchor.dart';
import 'package:npo_community/widgets/pronoun_butterfly.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

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
  final _statusMessageController = TextEditingController();
  final _authService = AuthService();
  final ImagePicker _picker = ImagePicker();
  final TextEditingController _customPronounController =
      TextEditingController();
  static const String _defaultPronoun = 'No Pronouns';
  static const Set<String> _blockedPronouns = {'woman'};
  final Set<String> _selectedPronouns = <String>{_defaultPronoun};
  final List<String> _customPronouns = <String>[];
  File? _profileImage;
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  String? _usernameError;
  String? _emailError;
  final List<String> _availablePronouns = [
    'She/Her',
    'He/Him',
    'They/Them',
    'Any Pronouns',
    'No Pronouns',
    'Ask for Pronouns',
    'She/They',
    'He/They',
    'They/He',
    'They/She',
    'She/He',
    'She/Xe',
    'He/Xe',
    'They/Xe',
    'Xe/Xem',
    'Ze/Hir',
    'Ze/Zir',
    'Zie/Hir',
    'Ze/Zem',
    'Xe/Xyr',
    'Fae/Faer',
    'Fae/Them',
    'Ae/Aer',
    'Ey/Em',
    'Ne/Nem',
    'Per/Per',
    'Ve/Ver',
    'Ve/Vem',
    'It/Its',
    'Thon/Thons',
  ];

  bool _isBlockedPronoun(String pronoun) {
    return _blockedPronouns.contains(pronoun.trim().toLowerCase());
  }

  bool _isDefaultPronoun(String pronoun) {
    return pronoun.trim().toLowerCase() == _defaultPronoun.toLowerCase();
  }

  Color _contrastTextColor(List<Color> colors) {
    if (colors.isEmpty) return Colors.white;
    final avgLuminance =
        colors.map((c) => c.computeLuminance()).reduce((a, b) => a + b) /
        colors.length;
    return avgLuminance > 0.55 ? Colors.black : Colors.white;
  }

  List<Color> _pronounColors(String pronoun) {
    final p = pronoun.trim().toLowerCase();

    if (p.contains('genderfluid') || p.contains('gender fluid')) {
      return const [
        Color(0xFFFF69B4),
        Color(0xFFFFFFFF),
        Color(0xFF9C27B0),
        Color(0xFF000000),
        Color(0xFF2196F3),
      ];
    }

    if (p.contains('any pronouns')) {
      return const [
        Color(0xFFFF69B4),
        Color(0xFF2196F3),
        Color(0xFFFFEB3B),
        Color(0xFF4CAF50),
        Color(0xFF9C27B0),
      ];
    }

    if (p.contains('no pronouns') || p.contains('agender')) {
      return const [Colors.black];
    }

    if (p.contains('ask for pronouns')) {
      return const [Color(0xFF9E9E9E)];
    }

    const femPink = Color(0xFFFF69B4);
    const mascBlue = Color(0xFF2196F3);
    const nbYellow = Color(0xFFFFEB3B);
    const xeGreen = Color(0xFF4CAF50);
    const zePurple = Color(0xFF9C27B0);
    const faeLightGreen = Color(0xFF8BC34A);
    const aeSilver = Color(0xFFC0C0C0);
    const eyLightYellow = Color(0xFFFFF59D);
    const neBrown = Color(0xFF8D6E63);
    const perOrange = Color(0xFFFF9800);
    const itDarkRed = Color(0xFF8B0000);
    const veTeal = Color(0xFF26C6DA);
    const thonIndigo = Color(0xFF3F51B5);

    Color? colorForPart(String part) {
      final t = part.trim().toLowerCase();
      if (t.isEmpty) return null;

      if (t == 'she' || t == 'her') return femPink;
      if (t == 'he' || t == 'him') return mascBlue;
      if (t == 'they' || t == 'them') return nbYellow;

      if (t == 'xe' || t == 'xem' || t == 'xyr') return xeGreen;

      // Ze/Zir family (includes common variants used in the list)
      if (t == 'ze' || t == 'zir' || t == 'hir' || t == 'zem' || t == 'zie') {
        return zePurple;
      }

      if (t == 'fae' || t == 'faer') return faeLightGreen;
      if (t == 'ae' || t == 'aer') return aeSilver;
      if (t == 'ey' || t == 'em') return eyLightYellow;
      if (t == 'ne' || t == 'nem') return neBrown;
      if (t == 'per') return perOrange;
      if (t == 'it' || t == 'its') return itDarkRed;
      if (t == 've' || t == 'ver' || t == 'vem') return veTeal;
      if (t == 'thon' || t == 'thons') return thonIndigo;

      return null;
    }

    final parts = pronoun
        .split('/')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    final colors = <Color>[];
    for (final part in parts) {
      final c = colorForPart(part);
      if (c != null && !colors.contains(c)) {
        colors.add(c);
      }
    }

    // Fallback for unexpected strings: use the app's nonbinary yellow for visibility.
    return colors.isNotEmpty ? colors : const [nbYellow];
  }

  Widget _buildPronounChip(String pronoun) {
    final isSelected = _selectedPronouns.contains(pronoun);
    final baseColors = _pronounColors(pronoun);
    final opacity = isSelected ? 0.95 : 0.35;
    final colors = baseColors.map((c) => c.withValues(alpha: opacity)).toList();
    final textColor = _contrastTextColor(baseColors);
    final borderColor = isSelected ? Colors.white : Colors.white54;

    final BorderSide borderSide = BorderSide(color: borderColor, width: 1.2);
    final BorderRadius borderRadius = BorderRadius.circular(28);

    if (colors.length > 1) {
      return Semantics(
        button: true,
        selected: isSelected,
        label: pronoun,
        hint: isSelected ? 'Selected pronouns' : 'Tap to select pronouns',
        child: InkWell(
          borderRadius: borderRadius,
          onTap: () => _togglePronounSelection(pronoun),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: colors,
              ),
              borderRadius: borderRadius,
              border: Border.all(
                color: borderSide.color,
                width: borderSide.width,
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Text(
              pronoun,
              style: TextStyle(color: textColor, fontWeight: FontWeight.w700),
            ),
          ),
        ),
      );
    }

    return Semantics(
      button: true,
      selected: isSelected,
      label: pronoun,
      hint: isSelected ? 'Selected pronouns' : 'Tap to select pronouns',
      child: FilterChip(
        label: Text(
          pronoun,
          style: TextStyle(color: textColor, fontWeight: FontWeight.w700),
        ),
        selected: isSelected,
        onSelected: (_) => _togglePronounSelection(pronoun),
        backgroundColor: colors.first,
        selectedColor: colors.first,
        showCheckmark: false,
        side: borderSide,
        shape: RoundedRectangleBorder(borderRadius: borderRadius),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      ),
    );
  }

  final GlobalKey<FormFieldState<List<String>>> _pronounFieldKey =
      GlobalKey<FormFieldState<List<String>>>();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _usernameController.dispose();
    _zipCodeController.dispose();
    _statusMessageController.dispose();
    _customPronounController.dispose();
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

  void _togglePronounSelection(String pronoun) {
    if (_isBlockedPronoun(pronoun)) {
      return;
    }

    if (_isDefaultPronoun(pronoun)) {
      setState(() {
        if (_selectedPronouns.length == 1 &&
            _selectedPronouns.contains(_defaultPronoun)) {
          return;
        }
        _selectedPronouns
          ..clear()
          ..add(_defaultPronoun);
        _customPronouns.clear();
        _pronounFieldKey.currentState?.didChange(_selectedPronouns.toList());
      });
      return;
    }

    setState(() {
      if (_selectedPronouns.contains(pronoun)) {
        _selectedPronouns.remove(pronoun);
      } else {
        _selectedPronouns.remove(_defaultPronoun);
        _selectedPronouns.add(pronoun);
      }

      if (_selectedPronouns.isEmpty) {
        _selectedPronouns.add(_defaultPronoun);
      }
      _pronounFieldKey.currentState?.didChange(_selectedPronouns.toList());
    });
  }

  void _addCustomPronoun() {
    final custom = _customPronounController.text.trim();
    if (custom.isEmpty) {
      return;
    }

    if (_isDefaultPronoun(custom)) {
      setState(() {
        _selectedPronouns
          ..clear()
          ..add(_defaultPronoun);
        _customPronouns.clear();
        _pronounFieldKey.currentState?.didChange(_selectedPronouns.toList());
        _customPronounController.clear();
      });
      return;
    }

    if (_isBlockedPronoun(custom)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('That pronoun option is not available.')),
      );
      _customPronounController.clear();
      return;
    }

    setState(() {
      _selectedPronouns.remove(_defaultPronoun);
      if (!_selectedPronouns.contains(custom)) {
        _selectedPronouns.add(custom);
        _customPronouns.add(custom);
      }
      _pronounFieldKey.currentState?.didChange(_selectedPronouns.toList());
      _customPronounController.clear();
    });
  }

  void _removeCustomPronoun(String pronoun) {
    setState(() {
      _customPronouns.remove(pronoun);
      _selectedPronouns.remove(pronoun);

      if (_selectedPronouns.isEmpty) {
        _selectedPronouns.add(_defaultPronoun);
      }
      _pronounFieldKey.currentState?.didChange(_selectedPronouns.toList());
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

    final pronounFieldState = _pronounFieldKey.currentState;
    if (_selectedPronouns.isEmpty) {
      pronounFieldState?.validate();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please select at least one pronoun option'),
          ),
        );
      }
      return;
    }

    setState(() {
      _isLoading = true;
      _usernameError = null;
      _emailError = null;
    });

    try {
      final pronouns = _selectedPronouns
          .map((p) => p.trim())
          .where((p) => p.isNotEmpty)
          .where((p) => !_isBlockedPronoun(p))
          .toList();

      if (pronouns.isEmpty) {
        pronouns.add(_defaultPronoun);
      }

      await _authService.signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
        password2: _confirmPasswordController.text.trim(),
        username: _usernameController.text.trim(),
        city: _zipCodeController.text.trim(),
        pronouns: pronouns,
        statusMessage: _statusMessageController.text.trim(),
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
        });

        final messages = <String>[
          if (_usernameError != null && _usernameError!.isNotEmpty)
            'Username: $_usernameError',
          if (_emailError != null && _emailError!.isNotEmpty)
            'Email: $_emailError',
        ];

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              messages.isNotEmpty
                  ? messages.join('\n')
                  : (e.message ??
                        'Registration failed. Please review your details and try again.'),
            ),
          ),
        );
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
                      decoration: themedInput(
                        label: 'ZIP Code',
                        icon: Icons.location_on,
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your ZIP code';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    FormField<List<String>>(
                      key: _pronounFieldKey,
                      validator: (_) {
                        if (_selectedPronouns.isEmpty) {
                          return 'Select at least one pronoun set';
                        }
                        return null;
                      },
                      builder: (field) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            TourAnchor(
                              name: 'Pronouns',
                              child: Text(
                                'Pronouns',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.9),
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Center(
                              child: ButterflyViewerWindow(
                                child: PronounButterfly(
                                  pronouns: _selectedPronouns.toList(),
                                  size: 240,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              children: _availablePronouns.map((pronoun) {
                                return _buildPronounChip(pronoun);
                              }).toList(),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _customPronounController,
                                    style: const TextStyle(color: Colors.white),
                                    decoration:
                                        themedInput(
                                          label: 'Add custom pronouns',
                                        ).copyWith(
                                          prefixIcon: const Icon(
                                            Icons.add,
                                            color: Colors.white,
                                          ),
                                        ),
                                    onSubmitted: (_) => _addCustomPronoun(),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                ElevatedButton(
                                  onPressed: _addCustomPronoun,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.white.withValues(
                                      alpha: 0.18,
                                    ),
                                    foregroundColor: Colors.white,
                                  ),
                                  child: const Text('Add'),
                                ),
                              ],
                            ),
                            if (_customPronouns.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: _customPronouns.map((pronoun) {
                                  final baseColors = _pronounColors(pronoun);
                                  final colors = baseColors
                                      .map((c) => c.withValues(alpha: 0.95))
                                      .toList();
                                  final textColor = _contrastTextColor(
                                    baseColors,
                                  );
                                  return InputChip(
                                    label: Text(
                                      pronoun,
                                      style: TextStyle(
                                        color: textColor,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    backgroundColor: colors.first,
                                    deleteIconColor: textColor.withValues(
                                      alpha: 0.8,
                                    ),
                                    onDeleted: () =>
                                        _removeCustomPronoun(pronoun),
                                  );
                                }).toList(),
                              ),
                            ],
                            if (field.hasError) ...[
                              const SizedBox(height: 8),
                              Text(
                                field.errorText ?? '',
                                style: const TextStyle(
                                  color: Colors.redAccent,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 24),

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
}
