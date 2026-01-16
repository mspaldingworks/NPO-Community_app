import 'package:flutter/material.dart';

class MeadowCreateChatSheet extends StatefulWidget {
  const MeadowCreateChatSheet({super.key});

  @override
  State<MeadowCreateChatSheet> createState() => _MeadowCreateChatSheetState();
}

class _MeadowCreateChatSheetState extends State<MeadowCreateChatSheet> {
  final _topicController = TextEditingController();
  final _descriptionController = TextEditingController();

  @override
  void dispose() {
    _topicController.dispose();
    _descriptionController.dispose();
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
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
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
            controller: _descriptionController,
            decoration: const InputDecoration(
              labelText: 'Description (optional)',
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
                    final topic = _topicController.text.trim();
                    if (topic.isEmpty) return;
                    Navigator.of(context).pop(
                      _CreateChatResult(
                        topic: topic,
                        description: _descriptionController.text.trim().isEmpty
                            ? null
                            : _descriptionController.text.trim(),
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

class _CreateChatResult {
  const _CreateChatResult({required this.topic, this.description});

  final String topic;
  final String? description;
}

_CreateChatResult? parseCreateChatResult(Object? result) {
  if (result is _CreateChatResult) {
    return result;
  }
  return null;
}
