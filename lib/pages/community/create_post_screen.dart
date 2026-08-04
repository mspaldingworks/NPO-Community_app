import 'package:flutter/material.dart';
import 'dart:io';
import 'package:go_router/go_router.dart';
import 'package:npo_community/core/services/community_service.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:npo_community/features/onboarding_tour/widgets/tour_anchor.dart';

class CreatePostScreen extends StatefulWidget {
  final int groupId;

  const CreatePostScreen({super.key, required this.groupId});

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();
  final _communityService = CommunityService();
  bool _isLoading = false;
  final List<String> _selectedEmojis = [];
  bool _emojiPickerShowing = false;
  bool _isAnonymous = false;
  String? _emojiError;
  final ImagePicker _imagePicker = ImagePicker();
  final List<File> _images = [];
  static const int _maxImages = 4;
  static const int _maxBytes = 10 * 1024 * 1024;

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  void _onEmojiSelected(Category? category, Emoji emoji) {
    if (_selectedEmojis.isEmpty) {
      setState(() {
        _selectedEmojis.add(emoji.emoji);
        _emojiError = null;
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'You can select only one emoji to describe your feeling.',
          ),
        ),
      );
    }
  }

  void _onBackspacePressed() {
    if (_selectedEmojis.isNotEmpty) {
      setState(() {
        _selectedEmojis.removeLast();
        if (_selectedEmojis.isEmpty) {
          _emojiError =
              'Please select an emoji to describe how you are feeling.';
        }
      });
    }
  }

  void _toggleEmojiPicker() {
    setState(() {
      _emojiPickerShowing = !_emojiPickerShowing;
    });
  }

  Future<void> _addImage() async {
    if (_images.length >= _maxImages) return;
    final picked = await _imagePicker.pickImage(source: ImageSource.gallery);
    if (picked == null) return;
    final file = File(picked.path);
    final bytes = await file.length();
    if (bytes > _maxBytes) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Image too large. Max 10MB.')),
        );
      }
      return;
    }
    setState(() {
      _images.add(file);
    });
  }

  void _removeImage(int index) {
    setState(() {
      _images.removeAt(index);
    });
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedEmojis.isEmpty) {
      setState(() {
        _emojiError = 'Please select an emoji to describe how you are feeling.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final derivedEmoji = _selectedEmojis.isNotEmpty
          ? _selectedEmojis.first
          : '';
      await _communityService.createPostMultipart(
        groupId: widget.groupId,
        title: _titleController.text.trim(),
        body: _bodyController.text.trim(),
        emoji: derivedEmoji,
        feeling: 'community',
        public: true,
        anonymous: _isAnonymous,
        imageFilePaths: _images.map((f) => f.path).toList(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Post created successfully!')),
        );
        context.pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to create post: $e')));
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
    return Scaffold(
      appBar: AppBar(
        title: const TourAnchor(
          name: 'Create New Post',
          child: Text('Create New Post'),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TourAnchor(
                      name: 'Title',
                      child: TextFormField(
                        controller: _titleController,
                        decoration: const InputDecoration(labelText: 'Title'),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter a title';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(height: 16.0),
                    TourAnchor(
                      name: "What's on your mind?",
                      child: TextFormField(
                        controller: _bodyController,
                        decoration: const InputDecoration(
                          labelText: 'What\'s on your mind?',
                        ),
                        maxLines: 8,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter some content for your post';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(height: 16.0),
                    TourAnchor(
                      name: 'Post anonymously',
                      child: SwitchListTile.adaptive(
                        value: _isAnonymous,
                        onChanged: (value) {
                          setState(() {
                            _isAnonymous = value;
                          });
                        },
                        title: const Text('Post anonymously'),
                        subtitle: const Text(
                          'When enabled, your username will not be shown to others.',
                        ),
                      ),
                    ),
                    const SizedBox(height: 16.0),
                    TourAnchor(
                      name: 'How are you feeling?',
                      child: GestureDetector(
                        onTap: _toggleEmojiPicker,
                        child: InputDecorator(
                          decoration: InputDecoration(
                            labelText: 'How are you feeling?',
                            border: const OutlineInputBorder(),
                            helperText:
                                'Tap to select exactly one emoji that matches your feeling.',
                            errorText: _emojiError,
                          ),
                          child: Wrap(
                            spacing: 8.0,
                            children: _selectedEmojis.isEmpty
                                ? [
                                    const Padding(
                                      padding: EdgeInsets.symmetric(
                                        vertical: 4.0,
                                      ),
                                      child: Text('Tap to choose an emoji'),
                                    ),
                                  ]
                                : _selectedEmojis
                                      .map(
                                        (emoji) => Chip(
                                          label: Text(
                                            emoji,
                                            style: const TextStyle(
                                              fontSize: 24,
                                            ),
                                          ),
                                          onDeleted: () {
                                            setState(() {
                                              _selectedEmojis.remove(emoji);
                                              if (_selectedEmojis.isEmpty) {
                                                _emojiError =
                                                    'Please select an emoji to describe how you are feeling.';
                                              }
                                            });
                                          },
                                        ),
                                      )
                                      .toList(),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16.0),
                    Row(
                      children: [
                        TourAnchor(
                          name: 'Add photos (${_images.length}/$_maxImages)',
                          child: OutlinedButton.icon(
                            onPressed:
                                _images.length >= _maxImages || _isLoading
                                ? null
                                : _addImage,
                            icon: const Icon(Icons.photo_library_outlined),
                            label: Text(
                              'Add photos (${_images.length}/$_maxImages)',
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (_images.isNotEmpty) ...[
                      const SizedBox(height: 8.0),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: List.generate(_images.length, (i) {
                          return Stack(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.file(
                                  _images[i],
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
                                  onPressed: _isLoading
                                      ? null
                                      : () => _removeImage(i),
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
                    const SizedBox(height: 24.0),
                    TourAnchor(
                      name: 'Create Post',
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _submitForm,
                        child: _isLoading
                            ? const CircularProgressIndicator(
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              )
                            : const Text('Create Post'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Offstage(
            offstage: !_emojiPickerShowing,
            child: SizedBox(
              height: 250,
              child: EmojiPicker(
                onEmojiSelected: _onEmojiSelected,
                onBackspacePressed: _onBackspacePressed,
                // Removed the incompatible Config object to use defaults
              ),
            ),
          ),
        ],
      ),
    );
  }
}
