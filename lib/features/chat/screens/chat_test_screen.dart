import 'package:flutter/material.dart';
import 'package:transconnect/core/services/chat_service.dart';
import 'package:transconnect/models/ws_message.dart';

class ChatTestScreen extends StatefulWidget {
  const ChatTestScreen({super.key});

  @override
  State<ChatTestScreen> createState() => _ChatTestScreenState();
}

class _ChatTestScreenState extends State<ChatTestScreen> {
  final ChatService _chatService = ChatService();
  final TextEditingController _messageController = TextEditingController();
  final TextEditingController _channelController = TextEditingController(
    text: 'test-channel-123', // Default test channel
  );
  final List<String> _logs = [];
  bool _isConnected = false;
  bool _isTyping = false;
  String? _currentChannelId;

  @override
  void initState() {
    super.initState();
    _addLog('Chat Test Screen Initialized');
  }

  @override
  void dispose() {
    _chatService.dispose();
    _messageController.dispose();
    _channelController.dispose();
    super.dispose();
  }

  void _addLog(String message) {
    setState(() {
      _logs.add('${DateTime.now().toIso8601String()}: $message');
    });
  }

  Future<void> _connectToChannel() async {
    final channelId = _channelController.text.trim();
    if (channelId.isEmpty) return;

    try {
      _addLog('Connecting to channel: $channelId...');
      
      // Connect to the channel
      final messageStream = _chatService.connectToChatChannel(channelId);
      
      // Listen for messages
      messageStream.listen(
        (message) {
          if (message.isTyping) {
            final userId = message.data['user_id'];
            final isTyping = message.data['is_typing'] as bool? ?? false;
            _addLog('User $userId is ${isTyping ? 'typing...' : 'not typing'}');
          } else if (message.isMessage) {
            _addLog('New message: ${message.data}');
          } else if (message.isReadReceipt) {
            _addLog('Message read: ${message.data}');
          } else {
            _addLog('Unknown message type: ${message.type}');
          }
        },
        onError: (error, stackTrace) {
          _addLog('Error: $error');
        },
        onDone: () {
          _addLog('Connection closed');
          setState(() {
            _isConnected = false;
            _currentChannelId = null;
          });
        },
      );

      setState(() {
        _isConnected = true;
        _currentChannelId = channelId;
      });
      _addLog('Connected to channel: $channelId');
    } catch (e) {
      _addLog('Failed to connect: $e');
    }
  }

  Future<void> _sendMessage() async {
    final message = _messageController.text.trim();
    if (message.isEmpty || _currentChannelId == null) return;

    try {
      _addLog('Sending message: $message');
      await _chatService.sendChannelMessage(
        channelId: _currentChannelId!,
        content: message,
      );
      _messageController.clear();
    } catch (e) {
      _addLog('Failed to send message: $e');
    }
  }

  Future<void> _toggleTyping() async {
    if (_currentChannelId == null) return;
    
    setState(() {
      _isTyping = !_isTyping;
    });
    
    try {
      await _chatService.sendTypingIndicator(_currentChannelId!, _isTyping);
      _addLog('Typing indicator: ${_isTyping ? 'typing...' : 'not typing'}');
    } catch (e) {
      _addLog('Failed to send typing indicator: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chat Service Test'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Connection Controls
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _channelController,
                    decoration: const InputDecoration(
                      labelText: 'Channel ID',
                      border: OutlineInputBorder(),
                    ),
                    enabled: !_isConnected,
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _isConnected ? null : _connectToChannel,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Connect'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _isConnected
                      ? () {
                          _chatService.disconnectFromChatChannel(_currentChannelId!);
                          setState(() {
                            _isConnected = false;
                            _currentChannelId = null;
                          });
                          _addLog('Disconnected from channel');
                        }
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Disconnect'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Message Input
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: const InputDecoration(
                      labelText: 'Message',
                      border: OutlineInputBorder(),
                    ),
                    enabled: _isConnected,
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _isConnected ? _toggleTyping : null,
                  icon: Icon(
                    Icons.keyboard,
                    color: _isTyping ? Colors.blue : null,
                  ),
                  tooltip: 'Toggle typing indicator',
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _isConnected ? _sendMessage : null,
                  icon: const Icon(Icons.send),
                  tooltip: 'Send message',
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Logs
            const Text('Logs:', style: TextStyle(fontWeight: FontWeight.bold)),
            const Divider(),
            Expanded(
              child: ListView.builder(
                itemCount: _logs.length,
                itemBuilder: (context, index) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2.0),
                    child: Text(
                      _logs.reversed.toList()[index],
                      style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
