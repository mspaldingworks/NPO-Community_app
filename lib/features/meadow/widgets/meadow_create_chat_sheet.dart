import 'package:flutter/material.dart';

class MeadowCreateChatSheet extends StatefulWidget {
  const MeadowCreateChatSheet({super.key});

  @override
  State<MeadowCreateChatSheet> createState() => _MeadowCreateChatSheetState();
}

class _MeadowCreateChatSheetState extends State<MeadowCreateChatSheet> {
  final _emojiController = TextEditingController();
  final _topicController = TextEditingController();
  final _commentController = TextEditingController();

  @override
  void dispose() {
    _emojiController.dispose();
    _topicController.dispose();
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Create temporary chat',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _emojiController,
            decoration: const InputDecoration(
              labelText: 'Emoji',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _topicController,
            decoration: const InputDecoration(
              labelText: 'Topic',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _commentController,
            decoration: const InputDecoration(
              labelText: 'First comment (optional)',
              border: OutlineInputBorder(),
            ),
            maxLines: 2,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    final emoji = _emojiController.text.trim();
                    if (emoji.isEmpty) return;
                    final topic = _topicController.text.trim();
                    if (topic.isEmpty) return;
                    Navigator.of(context).pop(
                      CreateChatResult(
                        emoji: emoji,
                        topic: topic,
                        initialComment: _commentController.text.trim().isEmpty
                            ? null
                            : _commentController.text.trim(),
                      ),
                    );
                  },
                  child: const Text('Create'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class CreateChatResult {
  const CreateChatResult({
    required this.emoji,
    required this.topic,
    this.initialComment,
  });

  final String emoji;
  final String topic;
  final String? initialComment;
}

CreateChatResult? parseCreateChatResult(Object? result) {
  if (result is CreateChatResult) {
    return result;
  }
  return null;
}
