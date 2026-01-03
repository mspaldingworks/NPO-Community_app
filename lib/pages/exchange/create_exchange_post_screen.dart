import 'dart:io';

import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:transconnect/core/services/community_service.dart';
import 'package:transconnect/core/services/exchange_service.dart';
import 'package:transconnect/models/group.dart';

class CreateExchangePostScreen extends StatefulWidget {
  const CreateExchangePostScreen({super.key});

  @override
  State<CreateExchangePostScreen> createState() => _CreateExchangePostScreenState();
}

class _CreateExchangePostScreenState extends State<CreateExchangePostScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();
  final _priceController = TextEditingController();

  late final CommunityService _communityService;
  late final ExchangeService _exchangeService;
  bool _initialized = false;

  bool _isLoading = false;

  ExchangeKind _kind = ExchangeKind.offer;
  ExchangeCompensation _compensation = ExchangeCompensation.paid;

  List<Group> _groups = const [];
  int _groupId = 1;
  bool _groupsLoading = false;

  final List<String> _tags = [];
  bool _emojiPickerShowing = false;
  String? _emojiError;

  bool _isAnonymous = false;

  final ImagePicker _imagePicker = ImagePicker();
  final List<File> _images = [];
  static const int _maxImages = 4;
  static const int _maxBytes = 10 * 1024 * 1024;

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;

    _communityService = context.read<CommunityService>();
    _exchangeService = ExchangeService(communityService: _communityService);
    _loadGroups();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  Future<void> _loadGroups() async {
    setState(() {
      _groupsLoading = true;
    });

    try {
      final groups = await _communityService.fetchGroups();
      if (!mounted) return;

      setState(() {
        _groups = groups;
        if (_groups.isNotEmpty && !_groups.any((g) => g.id == _groupId)) {
          _groupId = _groups.first.id;
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _groups = const [];
        _groupId = 1;
      });
    } finally {
      if (mounted) {
        setState(() {
          _groupsLoading = false;
        });
      }
    }
  }

  void _toggleEmojiPicker() {
    setState(() {
      _emojiPickerShowing = !_emojiPickerShowing;
    });
  }

  void _onEmojiSelected(Category? category, Emoji emoji) {
    if (_tags.length >= 6) return;
    setState(() {
      if (!_tags.contains(emoji.emoji)) {
        _tags.add(emoji.emoji);
        _emojiError = null;
      }
    });
  }

  void _onBackspacePressed() {
    if (_tags.isEmpty) return;
    setState(() {
      _tags.removeLast();
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

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_tags.isEmpty) {
      setState(() {
        _emojiError = 'Please add at least one emoji tag.';
        _emojiPickerShowing = true;
      });
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final price = _compensation == ExchangeCompensation.paid
          ? _priceController.text.trim()
          : null;

      await _exchangeService.createExchangePost(
        groupId: _groupId,
        title: _titleController.text.trim(),
        body: _bodyController.text.trim(),
        kind: _kind,
        compensation: _compensation,
        price: price,
        tags: _tags,
        anonymous: _isAnonymous,
        imageFilePaths: _images.map((f) => f.path).toList(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Listing created!')),
        );
        context.pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create listing: $e')),
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
    final showPrice = _compensation == ExchangeCompensation.paid;

    final safeGroupId = _groups.any((g) => g.id == _groupId) ? _groupId : (_groups.isNotEmpty ? _groups.first.id : 1);

    return Scaffold(
      appBar: AppBar(
        title: const Text('New Listing'),
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _submit,
            child: Text(
              'Post',
              style: TextStyle(
                color: _isLoading ? Colors.grey : Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    DropdownButtonFormField<int>(
                      key: ValueKey<int>(safeGroupId),
                      initialValue: safeGroupId,
                      decoration: const InputDecoration(labelText: 'Category / Region'),
                      items: _groupsLoading
                          ? const [
                              DropdownMenuItem<int>(
                                value: 1,
                                child: Text('Loading…'),
                              ),
                            ]
                          : (_groups.isEmpty
                              ? const [
                                  DropdownMenuItem<int>(
                                    value: 1,
                                    child: Text('General'),
                                  ),
                                ]
                              : _groups
                                  .map((g) => DropdownMenuItem<int>(
                                        value: g.id,
                                        child: Text(g.name),
                                      ))
                                  .toList()),
                      onChanged: _groupsLoading
                          ? null
                          : (value) {
                              if (value == null) return;
                              setState(() {
                                _groupId = value;
                              });
                            },
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<ExchangeKind>(
                      initialValue: _kind,
                      decoration: const InputDecoration(labelText: 'Type'),
                      items: const [
                        DropdownMenuItem(value: ExchangeKind.offer, child: Text('Offer')),
                        DropdownMenuItem(value: ExchangeKind.request, child: Text('Request')),
                      ],
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() {
                          _kind = value;
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<ExchangeCompensation>(
                      initialValue: _compensation,
                      decoration: const InputDecoration(labelText: 'Compensation'),
                      items: const [
                        DropdownMenuItem(value: ExchangeCompensation.paid, child: Text('Paid (off-app)')),
                        DropdownMenuItem(value: ExchangeCompensation.trade, child: Text('Trade')),
                        DropdownMenuItem(value: ExchangeCompensation.free, child: Text('Free / Mutual Aid')),
                      ],
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() {
                          _compensation = value;
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _titleController,
                      decoration: const InputDecoration(labelText: 'Title'),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter a title';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _bodyController,
                      decoration: const InputDecoration(labelText: 'Details'),
                      maxLines: 8,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter details';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    if (showPrice) ...[
                      TextFormField(
                        controller: _priceController,
                        decoration: const InputDecoration(labelText: 'Price (optional)'),
                      ),
                      const SizedBox(height: 16),
                    ],
                    SwitchListTile.adaptive(
                      value: _isAnonymous,
                      onChanged: (value) {
                        setState(() {
                          _isAnonymous = value;
                        });
                      },
                      title: const Text('Post anonymously'),
                      subtitle: const Text('When enabled, your username will not be shown to others.'),
                    ),
                    const SizedBox(height: 16),
                    GestureDetector(
                      onTap: _toggleEmojiPicker,
                      child: InputDecorator(
                        decoration: InputDecoration(
                          labelText: 'Emoji skill tags (required)',
                          border: const OutlineInputBorder(),
                          helperText: 'Tap to add up to 6 emoji tags.',
                          errorText: _emojiError,
                        ),
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _tags.isEmpty
                              ? const [
                                  Padding(
                                    padding: EdgeInsets.symmetric(vertical: 4),
                                    child: Text('Tap to choose emoji tags'),
                                  ),
                                ]
                              : _tags
                                  .map(
                                    (t) => Chip(
                                      label: Text(t, style: const TextStyle(fontSize: 20)),
                                      onDeleted: () {
                                        setState(() {
                                          _tags.remove(t);
                                          if (_tags.isEmpty) {
                                            _emojiError = 'Please add at least one emoji tag.';
                                          }
                                        });
                                      },
                                    ),
                                  )
                                  .toList(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        OutlinedButton.icon(
                          onPressed: _images.length >= _maxImages || _isLoading ? null : _addImage,
                          icon: const Icon(Icons.photo_library_outlined),
                          label: Text('Add photos (${_images.length}/$_maxImages)'),
                        ),
                      ],
                    ),
                    if (_images.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _images.asMap().entries.map((entry) {
                          final index = entry.key;
                          final file = entry.value;
                          return Stack(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.file(file, width: 90, height: 90, fit: BoxFit.cover),
                              ),
                              Positioned(
                                right: 0,
                                top: 0,
                                child: IconButton(
                                  icon: const Icon(Icons.close, size: 18),
                                  onPressed: () => _removeImage(index),
                                ),
                              ),
                            ],
                          );
                        }).toList(),
                      ),
                    ],
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
              ),
            ),
          ),
        ],
      ),
    );
  }
}
