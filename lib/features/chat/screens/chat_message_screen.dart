import 'dart:ffi';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:transconnect/core/services/auth_service.dart';
import 'package:transconnect/core/services/chat_service.dart';
import 'package:transconnect/models/chat_message.dart';
import 'package:transconnect/theme/app_theme.dart';

class ChatMessageScreen extends StatefulWidget {
  final int conversationId;

  const ChatMessageScreen({super.key, required this.conversationId});

  @override
  State<ChatMessageScreen> createState() => _ChatMessageScreenState();
}

class _ChatMessageScreenState extends State<ChatMessageScreen> {
  final ChatService _chatService = ChatService();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  late Future<List<ChatMessage>> _messagesFuture;
  final List<ChatMessage> _messages = [];
  int? _currentUserId;

  @override
  void initState() {
    super.initState();
    final authService = Provider.of<AuthService>(context, listen: false);
    _currentUserId = authService.currentUser?.id;

    // Fetch initial messages
    _messagesFuture = _chatService.getConversation(widget.conversationId);
    _messagesFuture.then((initialMessages) {
      if (mounted) {
        setState(() {
          _messages.addAll(initialMessages);
        });
      }
    });

    // // Connect to WebSocket for real-time messages
    // _chatService.connect(widget.conversationId);
    // _chatService.messages.listen((message) {
    //   if (mounted) {
    //     setState(() {
    //       // Avoid adding duplicates if the message is already in the list
    //       if (!_messages.any((m) => m.id == message.id)) {
    //         _messages.add(message);
    //       }
    //     });
    //     _scrollToBottom();
    //   }
    // });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _sendMessage() async {
    if (_messageController.text.isNotEmpty) {
      final content = _messageController.text;
      _messageController.clear();

      try {
        final newMessage = await _chatService.sendMessage(
          recipientId: widget.conversationId,
          content: content,
        );
        setState(() {
          _messages.add(newMessage);
        });
        _scrollToBottom();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to send message: $e')),
          );
          // Restore the text if sending failed
          _messageController.text = content;
        }
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.minScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Chat'), // Title can be dynamic later
      ),
      body: Column(
        children: [
          Expanded(
            child: FutureBuilder<List<ChatMessage>>(
              future: _messagesFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                } else if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                } else {
                  return ListView.builder(
                    controller: _scrollController,
                    reverse: true, // To show latest messages at the bottom
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      // The list is reversed, so we access from the end.
                      final message = _messages[_messages.length - 1 - index];
                      final isCurrentUser = message.sender.id == _currentUserId;
                      return _buildMessage(message, isCurrentUser);
                    },
                  );
                }
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: const InputDecoration(
                      hintText: 'Enter a message...',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: _sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessage(ChatMessage message, bool isCurrentUser) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
      child: Row(
        mainAxisAlignment:
            isCurrentUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 14.0),
              decoration: BoxDecoration(
                color: isCurrentUser
                    ? AppColors.primary
                    : Colors.grey[300],
                borderRadius: BorderRadius.circular(16.0),
              ),
              child: Text(
                message.content,
                style: TextStyle(
                  color: isCurrentUser ? AppColors.textWhite : AppColors.textBlack,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
