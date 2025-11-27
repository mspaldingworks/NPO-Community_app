import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:transconnect/core/services/auth_service.dart';
import 'package:transconnect/core/services/calendar_service.dart';
import 'package:transconnect/features/events/services/favorites_service.dart';
import 'package:transconnect/features/profile/services/profile_service.dart';
import 'package:transconnect/models/event.dart';
import 'package:transconnect/models/user.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:transconnect/widgets/display_profile_pic.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _statusController = TextEditingController();
  final _fullNameController = TextEditingController();
  final _cityController = TextEditingController();
  final _pronounsController = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  final ProfileService _profileService = ProfileService();
  final FavoritesService _favoritesService = FavoritesService();
  final CalendarService _calendarService = CalendarService();
  File? _profileImage;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
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
        _pronounsController.text = user.flair ?? '';
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

  void _saveProfile() async {
    if (_saving) return;
    setState(() => _saving = true);
    await _profileService.saveProfile(
      _statusController.text,
      _profileImage?.path,
      fullName: _fullNameController.text,
      city: _cityController.text,
      flair: _pronounsController.text,
    );
    if (mounted) {
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile saved!')),
      );
    }
  }

  @override
  void dispose() {
    _statusController.dispose();
    _fullNameController.dispose();
    _cityController.dispose();
    _pronounsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context, listen: false);
    final currentUser = authService.currentUser;
    final imageUrl = currentUser?.fullProfilePicUrl;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Profile'),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
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
              const SizedBox(height: 16),
              TextFormField(
                controller: _pronounsController,
                decoration: const InputDecoration(
                  labelText: 'Pronouns',
                  hintText: 'e.g., She/Her, They/Them',
                  border: OutlineInputBorder(),
                ),
                textInputAction: TextInputAction.next,
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
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: () {
                  _saveProfile();
                  if (imageUrl != null){
                    CachedNetworkImage.evictFromCache(imageUrl);
                  }
                },
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _saving ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Save'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
