import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:transconnect/core/services/community_service.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:flutter/foundation.dart' as foundation;

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

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  void _onEmojiSelected(Category? category, Emoji emoji) {
    if (_selectedEmojis.length < 4) {
      setState(() {
        _selectedEmojis.add(emoji.emoji);
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You can select up to 4 emojis.')),
      );
    }
  }

  void _onBackspacePressed() {
    if (_selectedEmojis.isNotEmpty) {
      setState(() {
        _selectedEmojis.removeLast();
      });
    }
  }

  void _toggleEmojiPicker() {
    setState(() {
      _emojiPickerShowing = !_emojiPickerShowing;
    });
  }

  Future<void> _submitForm() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      try {
        await _communityService.createPost(
          groupId: widget.groupId,
          title: _titleController.text,
          body: _bodyController.text,
          emojis: _selectedEmojis, // Pass the list of emojis
          public: true, // Assuming posts in groups are public
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Post created successfully!')),
          );
          context.pop(true); // Go back to the post list with a result
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to create post: $e')),
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
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create New Post'),
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
                    TextFormField(
                      controller: _titleController,
                      decoration: const InputDecoration(labelText: 'Title'),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter a title';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16.0),
                    TextFormField(
                      controller: _bodyController,
                      decoration: const InputDecoration(labelText: 'What\'s on your mind?'),
                      maxLines: 8,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter some content for your post';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16.0),
                    GestureDetector(
                      onTap: _toggleEmojiPicker,
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'How are you feeling?',
                          border: OutlineInputBorder(),
                        ),
                        child: Wrap(
                          spacing: 8.0,
                          children: _selectedEmojis.map((emoji) => Chip(label: Text(emoji))).toList(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24.0),
                    ElevatedButton(
                      onPressed: _isLoading ? null : _submitForm,
                      child: _isLoading
                          ? const CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Colors.white))
                          : const Text('Create Post'),
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
