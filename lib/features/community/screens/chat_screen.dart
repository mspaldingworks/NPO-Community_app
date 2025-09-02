import 'dart:async';

import 'package:flutter/material.dart';
import 'package:transconnect/core/services/auth_service.dart';
import 'package:transconnect/core/services/chat_service.dart';
import 'package:transconnect/features/community/models/message_model.dart';

class ChatScreen extends StatefulWidget {
  final String channelId;

  const ChatScreen({super.key, required this.channelId});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final ChatService _chatService = ChatService();
  final TextEditingController _messageController = TextEditingController();
  final List<Message> _messages = [];
  late StreamSubscription<Message> _messageSubscription;
  final _authService = AuthService();
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
    _loadMessages();
    _subscribeToMessages();
  }

  @override
  void dispose() {
    _messageSubscription.cancel();
    _messageController.dispose();
    super.dispose();
  }

  void _loadCurrentUser() {
    _currentUserId = _authService.currentUser?.uid;
    setState(() {});
  }

  Future<void> _loadMessages() async {
    final messages = await _chatService.fetchMessages(widget.channelId);
    if (mounted) {
      setState(() {
        _messages.addAll(messages);
      });
    }
  }

  void _subscribeToMessages() {
    _messageSubscription = _chatService.subscribeToNewMessages(widget.channelId).listen((newMessage) {
      if (mounted) {
        setState(() {
          _messages.add(newMessage);
        });
      }
    });
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty) {
      return;
    }
    await _chatService.sendMessage(
      channelId: widget.channelId,
      content: _messageController.text.trim(),
    );
    _messageController.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('# ${widget.channelId}'),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final message = _messages[index];
                final isMe = message.userId == _currentUserId;
                final username = message.profile?.username ?? '...';

                return ListTile(
                  title: Text(
                    username,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isMe ? Theme.of(context).colorScheme.primary : null,
                    ),
                  ),
                  subtitle: Text(message.content),
                );
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
                      hintText: 'Type a message...',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
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
}
