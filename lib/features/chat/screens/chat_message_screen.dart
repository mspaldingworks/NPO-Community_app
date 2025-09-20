import 'package:flutter/material.dart';
import 'package:transconnect/features/chat/services/chat_service.dart';
import 'package:transconnect/models/chat_message.dart';

class ChatMessageScreen extends StatefulWidget {
  final String conversationId;

  const ChatMessageScreen({super.key, required this.conversationId});

  @override
  State<ChatMessageScreen> createState() => _ChatMessageScreenState();
}

class _ChatMessageScreenState extends State<ChatMessageScreen> {
  final ChatService _chatService = ChatService();
  final TextEditingController _messageController = TextEditingController();
  final List<ChatMessage> _messages = [];

  @override
  void initState() {
    super.initState();
    _chatService.connect(widget.conversationId);
    _chatService.messages.listen((message) {
      if (mounted) {
        setState(() {
          _messages.add(message);
        });
      }
    });
  }

  @override
  void dispose() {
    _chatService.dispose();
    _messageController.dispose();
    super.dispose();
  }

  void _sendMessage() {
    if (_messageController.text.isNotEmpty) {
      _chatService.sendMessage(_messageController.text);
      _messageController.clear();
    }
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
            child: ListView.builder(
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final message = _messages[index];
                // This is a simple representation. We can improve this later.
                return ListTile(
                  title: Text(message.senderId),
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
                      hintText: 'Enter a message...',
                    ),
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
