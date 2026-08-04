import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:npo_community/core/services/auth_service.dart';
import 'package:npo_community/core/services/profile_service.dart';
import 'package:npo_community/models/user.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:npo_community/widgets/display_profile_pic.dart';
import 'package:npo_community/core/utils/flair_utils.dart';
import 'package:npo_community/widgets/pronoun_butterfly.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _MutualAidOption {
  final String emoji;
  final String label;

  const _MutualAidOption({required this.emoji, required this.label});
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _statusController = TextEditingController();
  final _fullNameController = TextEditingController();
  final _cityController = TextEditingController();
  final _pronounsController = TextEditingController();
  final TextEditingController _customPronounController =
      TextEditingController();
  final ImagePicker _picker = ImagePicker();
  final ProfileService _profileService = ProfileService();
  File? _profileImage;
  bool _saving = false;
  bool _isProfilePrivate = false;
  bool _updatingPronounsText = false;
  bool _pronounLimitSnackShown = false;
  final List<File> _statusImages = [];
  static const int _maxStatusImages = 4;
  static const int _maxStatusImageBytes = 10 * 1024 * 1024;
  static const int _maxPronounSelections = 5;
  static const String _defaultPronoun = 'No Pronouns';
  static const Set<String> _blockedPronouns = {'woman'};

  static const List<String> _availablePronouns = [
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

  static const List<_MutualAidOption> _mutualAidOptions = <_MutualAidOption>[
    _MutualAidOption(emoji: '🛻', label: 'Moving / transport help'),
    _MutualAidOption(emoji: '🚗', label: 'Rides / appointments'),
    _MutualAidOption(emoji: '🍲', label: 'Meals / groceries'),
    _MutualAidOption(emoji: '🏠', label: 'Housing navigation'),
    _MutualAidOption(emoji: '💸', label: 'Emergency funds / microgrants'),
    _MutualAidOption(emoji: '🧾', label: 'Paperwork / forms'),
    _MutualAidOption(emoji: '💻', label: 'Tech help'),
    _MutualAidOption(emoji: '👕', label: 'Clothes / supplies'),
    _MutualAidOption(emoji: '🤝', label: 'Peer support'),
    _MutualAidOption(emoji: '📣', label: 'Amplify / share requests'),
  ];

  final Set<String> _selectedMutualAidEmojis = <String>{};
  final Set<String> _selectedPronouns = <String>{};
  final List<String> _customPronouns = <String>[];

  bool _isBlockedPronoun(String pronoun) {
    return _blockedPronouns.contains(pronoun.trim().toLowerCase());
  }

  bool _isDefaultPronoun(String pronoun) {
    return pronoun.trim().toLowerCase() == _defaultPronoun.toLowerCase();
  }

  bool _startsOrContainsToken(String value, String token) {
    final v = value.toLowerCase();
    final t = token.toLowerCase();
    return v.startsWith(t) || v.contains('/$t') || v.contains('$t/');
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
      if (t == 'ze' || t == 'zir' || t == 'hir' || t == 'zem' || t == 'zie')
        return zePurple;
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

    final hasShe =
        _startsOrContainsToken(pronoun, 'she') ||
        _startsOrContainsToken(pronoun, 'her');
    final hasHe =
        _startsOrContainsToken(pronoun, 'he') ||
        _startsOrContainsToken(pronoun, 'him');
    final hasThey =
        _startsOrContainsToken(pronoun, 'they') ||
        _startsOrContainsToken(pronoun, 'them');
    if (hasShe && hasHe && hasThey) {
      return const [femPink, mascBlue, nbYellow];
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

    return colors.isNotEmpty ? colors : const [nbYellow];
  }

  void _syncPronounsController() {
    _updatingPronounsText = true;
    final next = _selectedPronouns.join(', ');
    _pronounsController.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: next.length),
    );
    _updatingPronounsText = false;
  }

  List<String> _parsePronounsText(String text) {
    return text
        .split(RegExp(r'[\n,;]'))
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty)
        .toList();
  }

  String _canonicalPronoun(String pronoun) {
    final trimmed = pronoun.trim();
    if (trimmed.isEmpty) return trimmed;
    for (final p in _availablePronouns) {
      if (p.toLowerCase() == trimmed.toLowerCase()) {
        return p;
      }
    }
    return trimmed;
  }

  void _applyPronounsFromText(String text) {
    final tokens = _parsePronounsText(text);
    final canonical = tokens
        .where((p) => !_isBlockedPronoun(p))
        .map(_canonicalPronoun)
        .toList();

    var normalized = canonical;
    if (normalized.length > 1) {
      normalized = normalized.where((p) => !_isDefaultPronoun(p)).toList();
    }
    if (normalized.isEmpty) {
      normalized = [_defaultPronoun];
    }

    final overflow = normalized.length > _maxPronounSelections;
    final parsed = overflow
        ? normalized.take(_maxPronounSelections).toList()
        : normalized;
    final hasDuplicates = parsed.toSet().length != parsed.length;
    final shouldResync =
        overflow ||
        canonical.length != tokens.length ||
        normalized.length != canonical.length ||
        hasDuplicates;

    if (mounted) {
      if (overflow && !_pronounLimitSnackShown) {
        _pronounLimitSnackShown = true;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('You can select up to 5 pronoun options.'),
          ),
        );
      } else if (!overflow && _pronounLimitSnackShown) {
        _pronounLimitSnackShown = false;
      }
    }

    setState(() {
      _selectedPronouns
        ..clear()
        ..addAll(parsed);

      final custom = parsed
          .where((p) => !_availablePronouns.contains(p))
          .toList();
      _customPronouns
        ..clear()
        ..addAll(custom);
    });

    if (shouldResync) {
      _syncPronounsController();
    }
  }

  void _onPronounsTextChanged() {
    if (_updatingPronounsText) return;
    if (_saving) return;
    _applyPronounsFromText(_pronounsController.text);
  }

  void _togglePronounSelection(String pronoun) {
    if (_saving) return;

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
        _syncPronounsController();
      });
      return;
    }

    setState(() {
      if (_selectedPronouns.contains(pronoun)) {
        _selectedPronouns.remove(pronoun);
      } else {
        if (_selectedPronouns.length >= _maxPronounSelections) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('You can select up to 5 pronoun options.'),
            ),
          );
          return;
        }

        _selectedPronouns.remove(_defaultPronoun);
        _selectedPronouns.add(pronoun);
      }

      if (_selectedPronouns.isEmpty) {
        _selectedPronouns.add(_defaultPronoun);
      }
      _syncPronounsController();
    });
  }

  void _addCustomPronoun() {
    if (_saving) return;
    final custom = _customPronounController.text.trim();
    if (custom.isEmpty) return;

    if (_isDefaultPronoun(custom)) {
      setState(() {
        _selectedPronouns
          ..clear()
          ..add(_defaultPronoun);
        _customPronouns.clear();
        _customPronounController.clear();
        _syncPronounsController();
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

    if (!_selectedPronouns.contains(custom) &&
        _selectedPronouns.length >= _maxPronounSelections) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You can select up to 5 pronoun options.'),
        ),
      );
      return;
    }

    setState(() {
      _selectedPronouns.remove(_defaultPronoun);
      if (!_customPronouns.contains(custom)) {
        _customPronouns.add(custom);
      }
      _selectedPronouns.add(custom);
      _customPronounController.clear();
      _syncPronounsController();
    });
  }

  void _removeCustomPronoun(String pronoun) {
    if (_saving) return;
    setState(() {
      _customPronouns.remove(pronoun);
      _selectedPronouns.remove(pronoun);

      if (_selectedPronouns.isEmpty) {
        _selectedPronouns.add(_defaultPronoun);
      }
      _syncPronounsController();
    });
  }

  Widget _buildPronounChip(String pronoun) {
    final isSelected = _selectedPronouns.contains(pronoun);
    final baseColors = _pronounColors(pronoun);
    final opacity = isSelected ? 0.95 : 0.35;
    final colors = baseColors.map((c) => c.withOpacity(opacity)).toList();
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

  String get _mutualAidEmojiString {
    return _mutualAidOptions
        .where((o) => _selectedMutualAidEmojis.contains(o.emoji))
        .map((o) => o.emoji)
        .join(' ')
        .trim();
  }

  @override
  void initState() {
    super.initState();
    _selectedPronouns.add(_defaultPronoun);
    _updatingPronounsText = true;
    _pronounsController.text = _defaultPronoun;
    _updatingPronounsText = false;
    _pronounsController.addListener(_onPronounsTextChanged);
    _loadProfileData();
  }

  Future<void> _loadProfileData() async {
    final status = await _profileService.getStatus();
    final imagePath = await _profileService.getImagePath();
    User? user;
    try {
      final auth = Provider.of<AuthService>(context, listen: false);
      user = auth.currentUser ?? await auth.getCurrentUser();
    } catch (_) {}

    final flair = user?.flair;
    final pronouns = FlairUtils.extractPronouns(flair) ?? '';
    final mutualAidLine = FlairUtils.extractMutualAidEmojis(flair) ?? '';
    final isPrivateProfile = FlairUtils.isProfilePrivate(flair);
    final selectedMutualAidEmojis = _mutualAidOptions
        .where((o) => mutualAidLine.contains(o.emoji))
        .map((o) => o.emoji)
        .toSet();

    setState(() {
      if (status != null) {
        _statusController.text = status;
      }
      if (imagePath != null) {
        _profileImage = File(imagePath);
      }
      if (user != null) {
        _fullNameController.text = user.fullName ?? '';
        _cityController.text = user.city ?? '';
        final pronounTokens = _parsePronounsText(pronouns);
        var parsedPronouns = pronounTokens
            .where((p) => !_isBlockedPronoun(p))
            .map(_canonicalPronoun)
            .take(_maxPronounSelections)
            .toList();

        if (parsedPronouns.length > 1) {
          parsedPronouns = parsedPronouns
              .where((p) => !_isDefaultPronoun(p))
              .toList();
        }

        if (parsedPronouns.isEmpty) {
          parsedPronouns = [_defaultPronoun];
        }

        _selectedPronouns
          ..clear()
          ..addAll(parsedPronouns);
        _customPronouns
          ..clear()
          ..addAll(
            _selectedPronouns.where((p) => !_availablePronouns.contains(p)),
          );

        _updatingPronounsText = true;
        _pronounsController.text = _selectedPronouns.join(', ');
        _updatingPronounsText = false;
        _isProfilePrivate = isPrivateProfile;

        _selectedMutualAidEmojis
          ..clear()
          ..addAll(selectedMutualAidEmojis);
      }
    });
  }

  Future<void> _pickImage() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _profileImage = File(pickedFile.path);
      });
    }
  }

  Future<void> _addStatusImage() async {
    if (_statusImages.length >= _maxStatusImages) return;
    final picked = await _picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return;
    final file = File(picked.path);
    final bytes = await file.length();
    if (bytes > _maxStatusImageBytes) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Image too large. Max 10MB.')),
        );
      }
      return;
    }
    setState(() {
      _statusImages.add(file);
    });
  }

  void _removeStatusImage(int index) {
    setState(() {
      _statusImages.removeAt(index);
    });
  }

  void _saveProfile() async {
    if (_saving) return;
    setState(() => _saving = true);

    final pronounsToSave = _selectedPronouns.join(', ');

    final flair = FlairUtils.buildFlair(
      pronouns: pronounsToSave,
      mutualAidEmojis: _mutualAidEmojiString,
      isPrivateProfile: _isProfilePrivate,
    );

    await _profileService.saveProfile(
      _statusController.text,
      _profileImage?.path,
      fullName: _fullNameController.text,
      city: _cityController.text,
      flair: flair,
      statusImagePaths: _statusImages.map((f) => f.path).toList(),
    );
    if (mounted) {
      setState(() => _saving = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Profile saved!')));
    }
  }

  @override
  void dispose() {
    _statusController.dispose();
    _fullNameController.dispose();
    _cityController.dispose();
    _pronounsController.removeListener(_onPronounsTextChanged);
    _pronounsController.dispose();
    _customPronounController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context, listen: false);
    final currentUser = authService.currentUser;
    final imageUrl = currentUser?.fullProfilePicUrl;

    return Scaffold(
      appBar: AppBar(title: const Text('Edit Profile')),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Private profile'),
                subtitle: const Text(
                  'Hide your profile details from other users.',
                ),
                value: _isProfilePrivate,
                onChanged: _saving
                    ? null
                    : (v) {
                        setState(() {
                          _isProfilePrivate = v;
                        });
                      },
              ),
              const SizedBox(height: 32),
              Center(
                child: Stack(
                  children: [
                    _profileImage != null
                        ? CircleAvatar(
                            radius: 40,
                            backgroundImage: FileImage(_profileImage!),
                          )
                        : DisplayProfilePic(radius: 40, imageUrl: imageUrl),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: IconButton(
                        icon: const Icon(Icons.camera_alt),
                        onPressed: _pickImage,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _statusController,
                decoration: const InputDecoration(
                  labelText: 'Status',
                  border: OutlineInputBorder(),
                ),
                maxLength: 140,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed:
                        _saving || _statusImages.length >= _maxStatusImages
                        ? null
                        : _addStatusImage,
                    icon: const Icon(Icons.photo_library_outlined),
                    label: Text(
                      'Add status photos (${_statusImages.length}/$_maxStatusImages)',
                    ),
                  ),
                ],
              ),
              if (_statusImages.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: List.generate(_statusImages.length, (i) {
                    return Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.file(
                            _statusImages[i],
                            width: 92,
                            height: 92,
                            fit: BoxFit.cover,
                          ),
                        ),
                        Positioned(
                          right: 0,
                          top: 0,
                          child: IconButton(
                            visualDensity: VisualDensity.compact,
                            iconSize: 18,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onPressed: _saving
                                ? null
                                : () => _removeStatusImage(i),
                            icon: const CircleAvatar(
                              radius: 10,
                              child: Icon(Icons.close, size: 14),
                            ),
                          ),
                        ),
                      ],
                    );
                  }),
                ),
              ],
              const SizedBox(height: 24),
              if (currentUser != null)
                Text(
                  currentUser.username,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              if (_mutualAidEmojiString.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  _mutualAidEmojiString,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ],
              const SizedBox(height: 16),
              TextFormField(
                controller: _fullNameController,
                decoration: const InputDecoration(
                  labelText: 'Full name',
                  border: OutlineInputBorder(),
                ),
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _cityController,
                decoration: const InputDecoration(
                  labelText: 'City',
                  border: OutlineInputBorder(),
                ),
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _pronounsController,
                decoration: const InputDecoration(
                  labelText: 'Pronouns',
                  hintText: 'Comma-separated (up to 5) — or tap chips below',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              Center(
                child: ButterflyViewerWindow(
                  child: PronounButterfly(
                    pronouns: _selectedPronouns.toList(),
                    size: 260,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Pronouns (select up to 5)',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: _availablePronouns.map(_buildPronounChip).toList(),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _customPronounController,
                      decoration: const InputDecoration(
                        labelText: 'Add custom pronouns',
                        border: OutlineInputBorder(),
                      ),
                      onSubmitted: (_) => _addCustomPronoun(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _saving ? null : _addCustomPronoun,
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
                        .map((c) => c.withOpacity(0.95))
                        .toList();
                    final textColor = _contrastTextColor(baseColors);
                    return InputChip(
                      label: Text(
                        pronoun,
                        style: TextStyle(
                          color: textColor,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      backgroundColor: colors.first,
                      deleteIconColor: textColor.withOpacity(0.8),
                      onDeleted: () => _removeCustomPronoun(pronoun),
                    );
                  }).toList(),
                ),
              ],
              const SizedBox(height: 16),
              Text(
                'Mutual aid I can help with',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Card(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Column(
                    children: _mutualAidOptions.map((o) {
                      final selected = _selectedMutualAidEmojis.contains(
                        o.emoji,
                      );
                      return CheckboxListTile(
                        value: selected,
                        dense: true,
                        controlAffinity: ListTileControlAffinity.leading,
                        title: Text('${o.emoji}  ${o.label}'),
                        onChanged: _saving
                            ? null
                            : (v) {
                                setState(() {
                                  if (v == true) {
                                    _selectedMutualAidEmojis.add(o.emoji);
                                  } else {
                                    _selectedMutualAidEmojis.remove(o.emoji);
                                  }
                                });
                              },
                      );
                    }).toList(),
                  ),
                ),
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: () {
                  _saveProfile();
                  if (imageUrl != null) {
                    CachedNetworkImage.evictFromCache(imageUrl);
                  }
                },
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _saving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Save'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
