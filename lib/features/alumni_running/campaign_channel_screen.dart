import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:npo_community/core/services/api_client.dart';
import 'package:npo_community/features/alumni_running/campaign_hub_controller.dart';
import 'package:npo_community/models/chat_message.dart';
import 'package:npo_community/widgets/smart_link_body.dart';

/// A candidate's opt-in alumni supporter channel.
///
/// Joining is an explicit action and leaving is always offered. The server
/// enforces membership; a `403` here drops the local membership.
class CampaignChannelScreen extends StatefulWidget {
  const CampaignChannelScreen({super.key, required this.candidateId});

  final String candidateId;

  @override
  State<CampaignChannelScreen> createState() => _CampaignChannelScreenState();
}

class _CampaignChannelScreenState extends State<CampaignChannelScreen> {
  late final CampaignHubController _hub;
  final TextEditingController _composer = TextEditingController();
  List<ChatMessage> _messages = const [];
  String? _messagesError;
  bool _loadingMessages = false;
  bool _sending = false;
  String? _activeChannelId;
  StreamSubscription<void>? _liveUpdates;

  @override
  void initState() {
    super.initState();
    _hub = context.read<CampaignHubController>();
    _hub.addListener(_syncChannel);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _hub.ensureLoaded();
      _syncChannel();
    });
  }

  @override
  void dispose() {
    _hub.removeListener(_syncChannel);
    _stopLive();
    _composer.dispose();
    super.dispose();
  }

  /// Starts or stops message loading whenever membership changes.
  void _syncChannel() {
    if (!mounted) return;
    final channelId = _hub.channelIdFor(widget.candidateId);
    if (channelId == _activeChannelId) return;
    _stopLive();
    _activeChannelId = channelId;
    if (channelId == null) {
      setState(() {
        _messages = const [];
        _messagesError = null;
      });
      return;
    }
    _liveUpdates = _hub.repository
        .watchChannel(channelId)
        .listen((_) => _loadMessages(), onError: (_) {});
    _loadMessages();
  }

  void _stopLive() {
    _liveUpdates?.cancel();
    _liveUpdates = null;
    final channelId = _activeChannelId;
    if (channelId != null) _hub.repository.unwatchChannel(channelId);
  }

  Future<void> _loadMessages() async {
    final channelId = _activeChannelId;
    if (channelId == null) return;
    setState(() => _loadingMessages = true);
    try {
      final messages = await _hub.repository.fetchChannelMessages(channelId);
      if (!mounted || channelId != _activeChannelId) return;
      setState(() {
        _messages = messages;
        _messagesError = null;
      });
    } catch (e) {
      if (!mounted) return;
      if (_handleForbidden(e)) return;
      setState(() => _messagesError = 'Unable to load messages.');
    } finally {
      if (mounted) setState(() => _loadingMessages = false);
    }
  }

  Future<void> _send() async {
    final channelId = _activeChannelId;
    final text = _composer.text.trim();
    if (channelId == null || text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      final sent = await _hub.repository.sendChannelMessage(channelId, text);
      if (!mounted) return;
      _composer.clear();
      setState(() => _messages = [..._messages, sent]);
    } catch (e) {
      if (!mounted) return;
      if (!_handleForbidden(e)) _snack('Message not sent. Please try again.');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  bool _handleForbidden(Object e) {
    if (e is ApiClientException && e.isForbidden) {
      _hub.markNotMember(widget.candidateId);
      _snack("You're no longer a member of this channel.");
      return true;
    }
    return false;
  }

  Future<void> _join() async =>
      _snackIfError(await _hub.join(widget.candidateId));

  Future<void> _leave() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Leave supporter channel?'),
        content: const Text(
          "You'll stop seeing messages here. You can rejoin anytime.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Stay'),
          ),
          TextButton(
            key: const Key('confirm-leave-channel'),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Leave'),
          ),
        ],
      ),
    );
    if (confirmed == true) _snackIfError(await _hub.leave(widget.candidateId));
  }

  void _snackIfError(String? error) {
    if (error != null) _snack(error);
  }

  void _snack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.maybeOf(
      context,
    )?.showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    final hub = context.watch<CampaignHubController>();
    final candidate = hub.candidateById(widget.candidateId);
    final joined = hub.isJoined(widget.candidateId);
    final caps = hub.capabilities;
    final busy = hub.isBusy('channel:${widget.candidateId}');
    final canPost = caps.canPostIn(joined: joined) && !_sending;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          candidate == null ? 'Supporter channel' : '${candidate.name} team',
        ),
        actions: [
          if (joined)
            TextButton(
              key: const Key('leave-channel'),
              onPressed: busy ? null : _leave,
              child: const Text('Leave'),
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: joined
                ? _buildMessages()
                : _JoinPrompt(
                    candidateName: candidate?.name,
                    enabled: caps.canJoinChannels && !busy,
                    disabledReason: caps.reason,
                    onJoin: _join,
                  ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      key: const Key('channel-composer'),
                      controller: _composer,
                      enabled: canPost,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                      decoration: InputDecoration(
                        hintText: joined
                            ? 'Message supporters…'
                            : 'Join the channel to post',
                        border: const OutlineInputBorder(),
                      ),
                    ),
                  ),
                  IconButton(
                    key: const Key('channel-send'),
                    icon: const Icon(Icons.send),
                    onPressed: canPost ? _send : null,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessages() {
    if (_loadingMessages && _messages.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_messagesError != null && _messages.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_messagesError!),
            const SizedBox(height: 8),
            FilledButton(onPressed: _loadMessages, child: const Text('Retry')),
          ],
        ),
      );
    }
    if (_messages.isEmpty) {
      return const Center(child: Text('No messages yet. Say hello!'));
    }
    return RefreshIndicator(
      onRefresh: _loadMessages,
      child: ListView.builder(
        itemCount: _messages.length,
        itemBuilder: (context, index) {
          final message = _messages[index];
          return ListTile(
            title: Text(
              message.sender.username,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: SmartLinkBody(text: message.content),
          );
        },
      ),
    );
  }
}

class _JoinPrompt extends StatelessWidget {
  const _JoinPrompt({
    required this.candidateName,
    required this.enabled,
    required this.disabledReason,
    required this.onJoin,
  });

  final String? candidateName;
  final bool enabled;
  final String? disabledReason;
  final VoidCallback onJoin;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const Icon(Icons.lock_outline, size: 40),
        const SizedBox(height: 12),
        Text(
          'Alumni supporter channel',
          textAlign: TextAlign.center,
          style: textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Text(
          'Coordinate with the campaign team and other alumni supporting '
          '${candidateName ?? 'this candidate'}. Joining is optional. Other '
          'members only see the messages you post here. Membership is never '
          'shown on your profile or in notifications.',
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        Center(
          child: FilledButton.icon(
            key: const Key('join-channel'),
            onPressed: enabled ? onJoin : null,
            icon: const Icon(Icons.group_add_outlined),
            label: const Text('Join channel'),
          ),
        ),
        if (!enabled && disabledReason != null) ...[
          const SizedBox(height: 8),
          Text(
            disabledReason!,
            textAlign: TextAlign.center,
            style: textTheme.bodySmall,
          ),
        ],
      ],
    );
  }
}
