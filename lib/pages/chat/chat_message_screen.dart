import 'package:flutter/material.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:npo_community/core/constants/api_endpoints.dart';
import 'package:provider/provider.dart';
import 'package:npo_community/core/services/auth_service.dart';
import 'package:npo_community/core/services/chat_favorites_service.dart';
import 'package:npo_community/core/services/chat_service.dart';
import 'package:npo_community/models/chat_message.dart';
import 'package:npo_community/models/user.dart';
import 'package:npo_community/theme/app_theme.dart';
import 'package:npo_community/widgets/loading_indicator.dart';
import 'package:npo_community/core/services/report_service.dart';
import 'package:npo_community/widgets/report_dialog.dart';
import 'package:npo_community/widgets/smart_link_body.dart';

class ChatMessageScreen extends StatefulWidget {
  final String conversationId;
  // final Conversation? conversation;

  const ChatMessageScreen({
    super.key,
    required this.conversationId,
    // this.conversation,
  });

  @override
  State<ChatMessageScreen> createState() => _ChatMessageScreenState();
}

class _ChatMessageScreenState extends State<ChatMessageScreen> {
  final ChatService _chatService = ChatService();
  final ChatFavoritesService _chatFavoritesService = ChatFavoritesService();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _messageFocusNode = FocusNode();
  final List<ChatMessage> _messages = [];
  final ImagePicker _picker = ImagePicker();
  File? _attachedImage;
  static const int _maxImageBytes = 10 * 1024 * 1024;

  bool _isLoading = true;
  bool _isSending = false;
  bool _showEmojiPicker = false;

  String _otherUsername = 'Chat';
  late User _currentUser;
  bool _isFavoriteChat = false;

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  String _fullUrl(String? url) {
    if (url == null || url.isEmpty) return '';
    if (url.startsWith('http')) return url;
    if (url.startsWith('/')) return '${ApiEndpoints.host}$url';
    return '${ApiEndpoints.host}/$url';
  }

  Future<void> _pickImageAttachment() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return;
    final file = File(picked.path);
    final size = await file.length();
    if (size > _maxImageBytes) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Image too large. Max 10MB.')),
        );
      }
      return;
    }
    setState(() {
      _attachedImage = file;
    });
  }

  void _removeAttachment() {
    setState(() {
      _attachedImage = null;
    });
  }

  // --- NEW HELPER METHOD ---
  // Extracted logic to fetch messages and update state
  Future<void> _fetchMessages({bool updateUsername = false}) async {
    try {
      final otherUserId = int.parse(widget.conversationId);
      final messages = await _chatService.getConversation(otherUserId);

      if (!mounted) return;

      // Only attempt to find and set username if explicitly requested
      // or if messages were previously empty
      if (updateUsername || _messages.isEmpty) {
        if (messages.isNotEmpty) {
          final otherParticipantMessage = messages.firstWhere(
            (m) => m.sender.id != _currentUser.id,
            orElse: () =>
                messages.firstWhere((m) => m.recipient.id != _currentUser.id),
          );

          final otherUser = otherParticipantMessage.sender.id != _currentUser.id
              ? otherParticipantMessage.sender
              : otherParticipantMessage.recipient;
          _otherUsername = otherUser.username;
        } else if (_otherUsername == 'Chat') {
          _otherUsername = 'User $otherUserId';
        }
      }

      setState(() {
        _messages
          ..clear()
          ..addAll(
            messages.reversed.toList(),
          ); // API returns oldest first, reverse
        _isLoading = false;
      });

      // Mark as read after fetching new list
      await _markMessagesAsRead();
      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      // Only show a fatal error during initial load, not post-send
      if (_isLoading) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load conversation: $e')),
        );
      }
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadFavoriteStatus() async {
    final otherUserId = int.tryParse(widget.conversationId);
    if (otherUserId == null) return;

    final favorites = await _chatFavoritesService.getFavoriteChatIds();
    if (!mounted) return;
    setState(() {
      _isFavoriteChat = favorites.contains(otherUserId);
    });
  }

  Future<void> _toggleFavorite() async {
    final otherUserId = int.tryParse(widget.conversationId);
    if (otherUserId == null) return;

    await _chatFavoritesService.setChatFavorite(
      chatId: otherUserId,
      isFavorite: !_isFavoriteChat,
    );
    if (!mounted) return;
    setState(() {
      _isFavoriteChat = !_isFavoriteChat;
    });
  }

  Future<void> _initializeData() async {
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      _currentUser = await authService.getCurrentUser();

      // Pass the username finding responsibility to _fetchMessages
      await _fetchMessages(updateUsername: true);

      await _loadFavoriteStatus();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to initialize chat data: $e')),
      );
      setState(() => _isLoading = false);
    }
  }

  Future<void> _markMessagesAsRead() async {
    if (_messages.isEmpty) return;
    final unreadMessages = _messages
        .where((m) => !m.isRead && m.sender.id != _currentUser.id)
        .map((m) => m.id)
        .where((id) => id > 0)
        .toList();

    if (unreadMessages.isEmpty) return;

    try {
      // NOTE: We must assume ChatService.markAsRead is updated to accept the otherUserId
      // since there is no Conversation ID.
      // await _chatService.markAsRead(
      //   otherUserId: widget.otherUserId, // Pass the other user's ID
      //   messageIds: unreadMessages,
      // );

      // Temporarily update UI optimistically
      setState(() {
        for (var message in _messages.where(
          (m) => unreadMessages.contains(m.id),
        )) {
          // Create a new message object with isRead set to true for UI update
          final updatedMessage = ChatMessage(
            id: message.id,
            sender: message.sender,
            recipient: message.recipient,
            content: message.content,
            timestamp: message.timestamp,
            isRead: true, // Mark as read locally
            imageUrl: message.imageUrl,
          );
          _messages[_messages.indexOf(message)] = updatedMessage;
        }
      });
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

  // REMOVED: _getOtherParticipant is no longer necessary as we use _otherUsername
  // User? _getOtherParticipant() { ... }

  // REMOVED: All group-related message formatting logic is removed

  // Removed methods related to group chat features
  bool _shouldShowAvatar(ChatMessage message, int index) {
    // In a 1-on-1 chat, we only show the other person's avatar if they sent the message
    // and the *previous* message was sent by the current user.
    if (message.sender.id == _currentUser.id) return false;

    // Always show the avatar on the first message from the sender
    if (index == _messages.length - 1) return true;

    // Show if the sender of this message is different from the sender of the previous message
    final previousMessage = _messages[index + 1];
    return previousMessage.sender.id != message.sender.id;
  }

  Widget _buildMessageList() {
    // ... existing code ...
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(vertical: 8),
      reverse: true, // Display newest messages at the bottom
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final message = _messages[index];
        final isCurrentUser = message.sender.id == _currentUser.id;
        // Reversed the index for logic checks as list is built in reverse
        final listIndex = _messages.length - 1 - index;
        return _buildMessage(message, isCurrentUser, listIndex);
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey[400]),
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
            style: TextStyle(color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  Widget _buildMessage(ChatMessage message, bool isCurrentUser, int listIndex) {
    // listIndex is now the true index (0=oldest, _messages.length-1=newest)
    final showAvatar = !isCurrentUser && _shouldShowAvatar(message, listIndex);
    // showUsername is now always false for 1-on-1 chat
    // final showUsername = !isCurrentUser && _shouldShowUsername(message, listIndex);

    // ... (rest of _buildMessage remains the same, except for the removed showUsername logic in the Column)

    return GestureDetector(
      onLongPress: () async {
        final otherUserId = int.tryParse(widget.conversationId);
        final targetUserId = isCurrentUser ? otherUserId : message.sender.id;
        final targetUsername = isCurrentUser
            ? _otherUsername
            : message.sender.username;

        await showReportDialog(
          context: context,
          baseRequest: ReportRequest(
            type: (message.imageUrl != null && message.imageUrl!.isNotEmpty)
                ? ReportTargetType.photo
                : ReportTargetType.comment,
            reason: '',
            targetId: message.id,
            targetUserId: targetUserId,
            targetUsername: targetUsername,
            targetUrl: message.imageUrl != null && message.imageUrl!.isNotEmpty
                ? _fullUrl(message.imageUrl)
                : null,
            details: message.content,
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          mainAxisAlignment: isCurrentUser
              ? MainAxisAlignment.end
              : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // Avatar logic remains, but simplified
            if (showAvatar)
              Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: CircleAvatar(
                  radius: 16,
                  backgroundImage:
                      null, // profilePic logic removed as it's not in MessageUser model
                  child: Text(
                    message.sender.username[0].toUpperCase(),
                  ), // Use first letter
                ),
              ),
            Flexible(
              child: Column(
                crossAxisAlignment: isCurrentUser
                    ? CrossAxisAlignment.end
                    : CrossAxisAlignment.start,
                children: [
                  // REMOVED: if (showUsername) block is removed
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
                        if (message.imageUrl != null &&
                            message.imageUrl!.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8.0),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(
                                _fullUrl(message.imageUrl),
                                width: 220,
                                height: 220,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                        if (message.content.isNotEmpty)
                          Text(
                            message.content,
                            style: TextStyle(
                              color: isCurrentUser
                                  ? Colors.white
                                  : Colors.black,
                            ),
                          ),
                        Padding(
                          padding: const EdgeInsets.only(top: 4.0),
                          child: Text(
                            _formatMessageTime(message.timestamp),
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
                  SmartLinkBody(
                    text: message.content,
                    showText: false,
                    previewMaxWidth: 320,
                    previewAlignment: isCurrentUser
                        ? Alignment.centerRight
                        : Alignment.centerLeft,
                  ),
                ],
              ),
            ),
            // Read status for current user's messages
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

  Future<void> _sendMessage() async {
    final content = _messageController.text.trim();
    if (content.isEmpty && _attachedImage == null) return;

    // 1. Clear input and start loading
    final originalContent = _messageController.text;
    _messageController.clear();
    setState(() => _isSending = true);

    try {
      if (_attachedImage != null) {
        await _chatService.sendMessageMultipart(
          recipientId: int.parse(widget.conversationId),
          content: content,
          imageFilePath: _attachedImage!.path,
        );
      } else {
        await _chatService.sendMessage(
          recipientId: int.parse(widget.conversationId),
          content: content,
        );
      }
      // 2. SUCCESS: Reload messages from the API to display the new message
      await _fetchMessages();

      if (!mounted) return;
    } catch (e) {
      if (!mounted) return;
      // 3. FAILURE: Restore input content
      _messageController.text = originalContent;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to send message. Please try again: $e')),
      );
    } finally {
      if (mounted) {
        // 4. Stop loading indicator
        setState(() {
          _isSending = false;
          _attachedImage = null;
        });
        _scrollToBottom(); // Scroll one last time just in case
      }
    }
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

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.photo_library_outlined),
                  onPressed: _isSending ? null : () => _pickImageAttachment(),
                ),
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
                      fillColor:
                          Theme.of(context).brightness == Brightness.light
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
            if (_attachedImage != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 6, 8, 0),
                child: Row(
                  children: [
                    Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.file(
                            _attachedImage!,
                            width: 72,
                            height: 72,
                            fit: BoxFit.cover,
                          ),
                        ),
                        Positioned(
                          right: 0,
                          top: 0,
                          child: IconButton(
                            visualDensity: VisualDensity.compact,
                            iconSize: 18,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onPressed: _isSending
                                ? null
                                : () => _removeAttachment(),
                            icon: const CircleAvatar(
                              radius: 10,
                              child: Icon(Icons.close, size: 14),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
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
      return const Scaffold(body: Center(child: LoadingIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_otherUsername), // Use the determined other username
        // You might want to add a profile pic here if User model has it
        actions: [
          IconButton(
            tooltip: _isFavoriteChat ? 'Unfavorite chat' : 'Favorite chat',
            icon: Icon(
              _isFavoriteChat ? Icons.star : Icons.star_border,
              color: _isFavoriteChat ? Colors.amber : null,
            ),
            onPressed: _toggleFavorite,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _messages.isEmpty ? _buildEmptyState() : _buildMessageList(),
          ),
          if (_showEmojiPicker) _buildEmojiPicker(),
          _buildMessageInput(),
        ],
      ),
    );
  }
}

// NOTE: You will need to add a helper method to your User model (or AuthService)
// to convert it to a MessageUser for the optimistic send:
// extension UserExtension on User {
//   MessageUser toMessageUser() {
//     return MessageUser(id: this.id, username: this.username);
//   }
// }
