import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:transconnect/core/services/auth_service.dart';
import 'package:transconnect/core/services/chat_service.dart';
import 'package:transconnect/models/chat_message.dart';
import 'package:transconnect/models/conversation.dart';
import 'package:transconnect/models/user.dart';
import 'package:transconnect/theme/app_theme.dart';
import 'package:transconnect/widgets/loading_indicator.dart';

class ChatMessageScreen extends StatefulWidget {
  final String conversationId;
  final Conversation? conversation;

  const ChatMessageScreen({
    super.key,
    required this.conversationId,
    this.conversation,
  });

  @override
  State<ChatMessageScreen> createState() => _ChatMessageScreenState();
}

class _ChatMessageScreenState extends State<ChatMessageScreen> {
  final ChatService _chatService = ChatService();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _messageFocusNode = FocusNode();
  final List<ChatMessage> _messages = [];

  bool _isLoading = true;
  bool _isSending = false;
  bool _showEmojiPicker = false;

  late Conversation _conversation;
  late User _currentUser;

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  Future<void> _initializeData() async {
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      _currentUser = await authService.getCurrentUser();

      _conversation = widget.conversation ??
          await _chatService.getConversation(widget.conversationId);

      final messages = await _chatService.getMessages(widget.conversationId);

      if (!mounted) return;

      setState(() {
        _messages
          ..clear()
          ..addAll(messages);
        _isLoading = false;
      });

      await _markMessagesAsRead();
      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load conversation: $e')),
      );
      setState(() => _isLoading = false);
    }
  }

  Future<void> _markMessagesAsRead() async {
    if (_messages.isEmpty) return;
    final unreadMessages = _messages
        .where((m) => !m.isRead && m.sender.id != _currentUser.id)
        .map((m) => m.id)
        .where((id) => id.isNotEmpty)
        .toList();

    if (unreadMessages.isEmpty) return;

    try {
      await _chatService.markAsRead(
        conversationId: widget.conversationId,
        messageIds: unreadMessages,
      );
    } catch (_) {
      // Silently ignore mark-as-read failures.
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _messageFocusNode.dispose();
    super.dispose();
  }

  User? _getOtherParticipant() {
    if (_conversation.participants.isEmpty) {
      return null;
    }

    return _conversation.participants.firstWhere(
      (user) => user.id != _currentUser.id,
      orElse: () => _conversation.participants.first,
    );
  }

  void _toggleEmojiPicker() {
    setState(() {
      _showEmojiPicker = !_showEmojiPicker;
      if (_showEmojiPicker) {
        _messageFocusNode.unfocus();
      } else {
        _messageFocusNode.requestFocus();
      }
    });
  }

  Widget _buildMessageList() {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(vertical: 8),
      reverse: true,
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final message = _messages[index];
        final isCurrentUser = message.sender.id == _currentUser.id;
        return _buildMessage(message, isCurrentUser, index);
      },
    );
  }

  bool _shouldShowAvatar(ChatMessage message, int index) {
    if (index == _messages.length - 1) return true;
    final nextMessage = _messages[index + 1];
    return nextMessage.sender.id != message.sender.id;
  }

  bool _shouldShowUsername(ChatMessage message, int index) {
    if (!_conversation.isGroup) return false;
    if (index == _messages.length - 1) return true;
    final nextMessage = _messages[index + 1];
    return nextMessage.sender.id != message.sender.id;
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.chat_bubble_outline,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No messages yet',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Send a message to start the conversation',
            style: TextStyle(
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessage(ChatMessage message, bool isCurrentUser, int index) {
    final showAvatar = !isCurrentUser && _shouldShowAvatar(message, index);
    final showUsername = !isCurrentUser && _shouldShowUsername(message, index);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        mainAxisAlignment:
            isCurrentUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (showAvatar)
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: CircleAvatar(
                radius: 16,
                backgroundImage: message.sender.profilePic != null
                    ? NetworkImage(message.sender.profilePic!)
                    : null,
                child: message.sender.profilePic == null
                    ? Text(message.sender.username[0].toUpperCase())
                    : null,
              ),
            ),
          Flexible(
            child: Column(
              crossAxisAlignment: isCurrentUser
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                if (showUsername)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 2.0, left: 8.0),
                    child: Text(
                      message.sender.username,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                      ),
                    ),
                  ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 10,
                    horizontal: 14,
                  ),
                  decoration: BoxDecoration(
                    color: isCurrentUser
                        ? Theme.of(context).primaryColor
                        : Colors.grey[200],
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        message.content,
                        style: TextStyle(
                          color:
                              isCurrentUser ? Colors.white : Colors.black,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(top: 4.0),
                        child: Text(
                          _formatMessageTime(message.createdAt),
                          style: TextStyle(
                            fontSize: 10,
                            color: isCurrentUser
                                ? Colors.white70
                                : Colors.grey[600],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (isCurrentUser)
            Padding(
              padding: const EdgeInsets.only(left: 4.0),
              child: Icon(
                message.isRead ? Icons.done_all : Icons.done,
                size: 16,
                color: message.isRead ? AppColors.secondary : Colors.grey,
              ),
            ),
        ],
      ),
    );
  }

  String _formatMessageTime(DateTime? time) {
    if (time == null) return '';
    final now = DateTime.now();
    final difference = now.difference(time);

    if (difference.inDays > 0) {
      return '${time.month}/${time.day}/${time.year}';
    }

    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.emoji_emotions_outlined),
              onPressed: _toggleEmojiPicker,
            ),
            Expanded(
              child: TextField(
                controller: _messageController,
                focusNode: _messageFocusNode,
                decoration: InputDecoration(
                  hintText: 'Type a message...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: Theme.of(context).brightness == Brightness.light
                      ? Colors.grey[200]
                      : Colors.grey[800],
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
                minLines: 1,
                maxLines: 5,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
            IconButton(
              icon: _isSending
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send),
              onPressed: _isSending ? null : _sendMessage,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmojiPicker() {
    return Container(
      height: 250,
      color: Theme.of(context).cardColor,
      alignment: Alignment.center,
      child: const Text('Emoji picker coming soon'),
    );
  }

  Future<void> _sendMessage() async {
    final content = _messageController.text.trim();
    if (content.isEmpty) return;

    setState(() => _isSending = true);

    try {
      final savedMessage = await _chatService.sendMessage(
        conversationId: widget.conversationId,
        content: content,
      );

      if (!mounted) return;

      setState(() {
        _messages.insert(0, savedMessage);
        _messageController.clear();
      });

      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to send message: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  void _scrollToBottom() {
    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: LoadingIndicator(),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _conversation.isGroup
              ? _conversation.name ?? 'Group Chat'
              : _getOtherParticipant()?.username ?? 'Chat',
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: _messages.isEmpty
                ? _buildEmptyState()
                : _buildMessageList(),
          ),
          if (_showEmojiPicker) _buildEmojiPicker(),
          _buildMessageInput(),
        ],
      ),
    );
  }
}
