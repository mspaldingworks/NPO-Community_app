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
import 'package:npo_community/core/utils/profile_links.dart';
import 'package:npo_community/features/events/volunteer_roles.dart';

/// Edit Profile: photo, status, name, city, how she can help, and the
/// social media and other links shown on her public profile.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _statusController = TextEditingController();
  final _fullNameController = TextEditingController();
  final _cityController = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  final ProfileService _profileService = ProfileService();
  File? _profileImage;
  bool _saving = false;
  bool _isProfilePrivate = false;
  final List<File> _statusImages = [];
  final Set<String> _volunteerRoles = {};
  final List<_LinkRow> _links = [];
  static const int _maxLinks = 10;
  static const int _maxStatusImages = 4;
  static const int _maxStatusImageBytes = 10 * 1024 * 1024;

  @override
  void initState() {
    super.initState();
    _loadProfileData();
  }

  Future<void> _loadProfileData() async {
    final status = await _profileService.getStatus();
    final imagePath = await _profileService.getImagePath();
    if (!mounted) return;
    User? user;
    try {
      final auth = Provider.of<AuthService>(context, listen: false);
      user = auth.currentUser ?? await auth.getCurrentUser();
    } catch (_) {}
    if (!mounted) return;

    final isPrivateProfile = FlairUtils.isProfilePrivate(user?.flair);

    setState(() {
      // The server's status wins: the quick-edit sheet on Home saves there
      // without touching the local hint, which is only a fallback.
      final serverStatus = (user?.statusMessage ?? '').trim();
      if (serverStatus.isNotEmpty) {
        _statusController.text = serverStatus;
      } else if (status != null) {
        _statusController.text = status;
      }
      if (imagePath != null) {
        _profileImage = File(imagePath);
      }
      if (user != null) {
        _fullNameController.text = user.fullName ?? '';
        _cityController.text = user.city ?? '';
        _volunteerRoles
          ..clear()
          ..addAll(user.volunteerRoles);
        for (final row in _links) {
          row.dispose();
        }
        _links
          ..clear()
          ..addAll(user.links.map(_LinkRow.fromLink));
        _isProfilePrivate = isPrivateProfile;
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

  /// Links with a URL, normalised to https. Rows left empty are dropped.
  List<ProfileLink> _linksToSave() => [
    for (final row in _links)
      if (normalizeProfileLinkUrl(row.url.text).isNotEmpty)
        ProfileLink(
          label: row.label.text.trim(),
          url: normalizeProfileLinkUrl(row.url.text),
        ),
  ];

  void _addLink(ProfileLinkPreset preset) {
    if (_saving || _links.length >= _maxLinks) return;
    setState(() {
      _links.add(
        _LinkRow(
          label: preset.label == 'Other' ? '' : preset.label,
          url: preset.urlPrefix,
        ),
      );
    });
  }

  void _removeLink(_LinkRow row) {
    if (_saving) return;
    setState(() {
      _links.remove(row);
    });
    row.dispose();
  }

  void _saveProfile() async {
    if (_saving) return;
    setState(() => _saving = true);

    final flair = FlairUtils.buildFlair(isPrivateProfile: _isProfilePrivate);

    try {
      await _profileService.saveProfile(
        _statusController.text,
        _profileImage?.path,
        fullName: _fullNameController.text,
        city: _cityController.text,
        flair: flair,
        volunteerRoles: _volunteerRoles.toList()..sort(),
        links: _linksToSave(),
        statusImagePaths: _statusImages.map((f) => f.path).toList(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Profile saved!')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not save: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _statusController.dispose();
    _fullNameController.dispose();
    _cityController.dispose();
    for (final row in _links) {
      row.dispose();
    }
    super.dispose();
  }

  Widget _buildLinksSection(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Links', style: theme.textTheme.titleMedium),
        const SizedBox(height: 4),
        Text(
          'Social media, your campaign site, anything you want other alumnae '
          'to find. Shown on your profile unless it is private.',
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: 8),
        for (final row in _links)
          Padding(
            key: ValueKey(row),
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 2,
                  child: TextField(
                    key: Key('link-label-${_links.indexOf(row)}'),
                    controller: row.label,
                    enabled: !_saving,
                    maxLength: 40,
                    decoration: const InputDecoration(
                      labelText: 'Label',
                      hintText: 'Instagram',
                      border: OutlineInputBorder(),
                      counterText: '',
                    ),
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.next,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 3,
                  child: TextField(
                    key: Key('link-url-${_links.indexOf(row)}'),
                    controller: row.url,
                    enabled: !_saving,
                    decoration: const InputDecoration(
                      labelText: 'Link',
                      hintText: 'https://',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.url,
                    autocorrect: false,
                    textInputAction: TextInputAction.done,
                  ),
                ),
                IconButton(
                  key: Key('link-remove-${_links.indexOf(row)}'),
                  tooltip: 'Remove link',
                  onPressed: _saving ? null : () => _removeLink(row),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
        if (_links.length < _maxLinks)
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final preset in profileLinkPresets)
                ActionChip(
                  key: Key('add-link-${preset.label}'),
                  avatar: Icon(preset.icon, size: 18),
                  label: Text(preset.label),
                  onPressed: _saving ? null : () => _addLink(preset),
                ),
            ],
          )
        else
          Text(
            'You can list up to $_maxLinks links.',
            style: theme.textTheme.bodySmall,
          ),
      ],
    );
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
                child: Column(
                  children: [
                    GestureDetector(
                      onTap: _saving ? null : _pickImage,
                      child: _profileImage != null
                          ? CircleAvatar(
                              radius: 48,
                              backgroundImage: FileImage(_profileImage!),
                            )
                          : DisplayProfilePic(radius: 48, imageUrl: imageUrl),
                    ),
                    const SizedBox(height: 8),
                    FilledButton.tonalIcon(
                      key: const Key('change-photo'),
                      onPressed: _saving ? null : _pickImage,
                      icon: const Icon(Icons.camera_alt_outlined),
                      label: Text(
                        _profileImage != null
                            ? 'Photo chosen · tap Save'
                            : 'Change photo',
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
              const SizedBox(height: 24),
              Text(
                'How I can help',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 4),
              Text(
                'Emerge staff and group leads use this to find volunteers.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  for (final entry in volunteerRoles.entries)
                    FilterChip(
                      key: Key('role-${entry.key}'),
                      label: Text(entry.value),
                      selected: _volunteerRoles.contains(entry.key),
                      onSelected: (on) => setState(() {
                        if (on) {
                          _volunteerRoles.add(entry.key);
                        } else {
                          _volunteerRoles.remove(entry.key);
                        }
                      }),
                    ),
                ],
              ),
              const SizedBox(height: 24),
              _buildLinksSection(context),
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

/// One editable link: its label and URL fields.
class _LinkRow {
  _LinkRow({String label = '', String url = ''})
    : label = TextEditingController(text: label),
      url = TextEditingController(text: url);

  factory _LinkRow.fromLink(ProfileLink link) =>
      _LinkRow(label: link.label, url: link.url);

  final TextEditingController label;
  final TextEditingController url;

  void dispose() {
    label.dispose();
    url.dispose();
  }
}
