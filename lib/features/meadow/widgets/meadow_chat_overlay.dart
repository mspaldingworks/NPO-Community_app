import 'package:flutter/material.dart';
import 'package:transconnect/features/meadow/controllers/meadow_controller.dart';
import 'package:transconnect/features/meadow/models/meadow_chat_flower.dart';

class MeadowChatOverlay extends StatefulWidget {
  const MeadowChatOverlay({
    super.key,
    required this.chatId,
    required this.controller,
    required this.onClose,
  });

  final String chatId;
  final MeadowController controller;
  final VoidCallback onClose;

  @override
  State<MeadowChatOverlay> createState() => _MeadowChatOverlayState();
}

class _MeadowChatOverlayState extends State<MeadowChatOverlay> {
  @override
  void initState() {
    super.initState();
    widget.controller.joinChat(widget.chatId);
  }

  @override
  void dispose() {
    widget.controller.leaveChat(widget.chatId);
    super.dispose();
  }

   @override
   Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        MeadowChatFlower? chat;
        for (final flower in widget.controller.flowers) {
          if (flower.id == widget.chatId) {
            chat = flower;
            break;
          }
        }
        if (chat == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) widget.onClose();
          });
          return const SizedBox.shrink();
        }

        return SafeArea(
          child: Container(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              bottom: MediaQuery.of(context).viewInsets.bottom + 16,
              top: 12,
            ),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.max,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            chat!.topic,
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${chat.participantCount} participants',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    PopupMenuButton<String>(
                      key: const ValueKey('meadow-chat-menu'),
                      onSelected: (value) {
                        if (value == 'report') {
                          _showReportSheet(context);
                        }
                      },
                      itemBuilder: (context) => const [
                        PopupMenuItem<String>(
                          value: 'report',
                          child: Text('Report Chat'),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: widget.onClose,
                    ),
                  ],
                ),
                const Divider(height: 24),
                Expanded(
                  child: ListView.builder(
                    itemCount: 6,
                    itemBuilder: (context, index) {
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.green.shade200,
                          child: Text('${index + 1}'),
                        ),
                        title: Text('Meadow message ${index + 1}'),
                        subtitle: const Text('Let\'s chat about this topic!'),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        decoration: InputDecoration(
                          hintText: 'Send a message...',
                          filled: true,
                          fillColor: Colors.grey.shade100,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.send),
                      onPressed: () {},
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
   }

  Future<void> _showReportSheet(BuildContext context) async {
    final result = await showModalBottomSheet<_ReportResult>(
      context: context,
      isScrollControlled: true,
      builder: (context) => const _ReportChatSheet(),
    );
    if (result == null) return;

    await widget.controller.reportChat(
      chatId: widget.chatId,
      reason: result.reason,
      note: result.note,
    );

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Report sent. Thank you.')),
      );
    }
  }
}

class _ReportChatSheet extends StatefulWidget {
  const _ReportChatSheet();

  @override
  State<_ReportChatSheet> createState() => _ReportChatSheetState();
}

class _ReportChatSheetState extends State<_ReportChatSheet> {
  String _reason = 'Spam';
  final TextEditingController _noteController = TextEditingController();

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 16,
        right: 16,
        top: 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Report chat',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _reason,
            items: const [
              DropdownMenuItem(value: 'Spam', child: Text('Spam')),
              DropdownMenuItem(value: 'Harassment', child: Text('Harassment')),
              DropdownMenuItem(value: 'Hate', child: Text('Hate speech')),
              DropdownMenuItem(value: 'Other', child: Text('Other')),
            ],
            onChanged: (value) {
              if (value == null) return;
              setState(() {
                _reason = value;
              });
            },
            decoration: const InputDecoration(labelText: 'Reason'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _noteController,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Optional note',
              border: OutlineInputBorder(),
            ),
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
                    Navigator.of(context).pop(
                      _ReportResult(
                        reason: _reason,
                        note: _noteController.text.trim().isEmpty
                            ? null
                            : _noteController.text.trim(),
                      ),
                    );
                  },
                  child: const Text('Submit'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

class _ReportResult {
  const _ReportResult({required this.reason, this.note});

  final String reason;
  final String? note;
}
