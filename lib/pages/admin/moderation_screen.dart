import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:transconnect/core/services/auth_service.dart';
import 'package:transconnect/core/services/chat_service.dart';
import 'package:transconnect/models/chat_message.dart';

class ModerationScreen extends StatefulWidget {
  const ModerationScreen({super.key});

  @override
  State<ModerationScreen> createState() => _ModerationScreenState();
}

class _ReportItem {
  final int otherUserId;
  final String otherUsername;
  final ChatMessage message;

  const _ReportItem({
    required this.otherUserId,
    required this.otherUsername,
    required this.message,
  });
}

class _ModerationScreenState extends State<ModerationScreen> {
  final AuthService _authService = AuthService();
  final ChatService _chatService = ChatService();

  bool _loading = true;
  String? _error;
  List<_ReportItem> _reports = const [];

  static const List<String> _adminUsernames = <String>[
    'Mad.E',
    'Mad.E.Made',
    'pmaxwell',
  ];

  bool get _isAdmin {
    final me = _authService.currentUser;
    return me != null && _adminUsernames.contains(me.username);
  }

  @override
  void initState() {
    super.initState();
    _loadReports();
  }

  String? _extractField(String content, String prefix) {
    for (final raw in content.split('\n')) {
      final line = raw.trim();
      if (line.startsWith(prefix)) {
        return line.substring(prefix.length).trim();
      }
    }
    return null;
  }

  Future<void> _loadReports() async {
    if (!_isAdmin) {
      setState(() {
        _loading = false;
        _error = null;
        _reports = const [];
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final conversations = await _chatService.getAllConversations();
      final items = <_ReportItem>[];

      for (final c in conversations) {
        final msgs = await _chatService.getConversation(c.id);
        for (final m in msgs) {
          if (m.content.startsWith('[REPORT]')) {
            items.add(
              _ReportItem(
                otherUserId: c.id,
                otherUsername: c.username,
                message: m,
              ),
            );
          }
        }
      }

      items.sort((a, b) => b.message.timestamp.compareTo(a.message.timestamp));

      if (!mounted) return;
      setState(() {
        _reports = items;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isAdmin) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Moderation'),
        ),
        body: const Padding(
          padding: EdgeInsets.all(16),
          child: Text('Not authorized.'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Moderation'),
        actions: [
          IconButton(
            onPressed: _loading ? null : _loadReports,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadReports,
        child: _loading
            ? ListView(
                children: const [
                  SizedBox(height: 220),
                  Center(child: CircularProgressIndicator()),
                ],
              )
            : _error != null
                ? ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Text('Failed to load reports: $_error'),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: _loadReports,
                        child: const Text('Retry'),
                      ),
                    ],
                  )
                : _reports.isEmpty
                    ? ListView(
                        padding: const EdgeInsets.all(16),
                        children: const [
                          Text('No reports found.'),
                        ],
                      )
                    : ListView.separated(
                        itemCount: _reports.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final item = _reports[index];
                          final content = item.message.content;
                          final reporter = _extractField(content, 'Reporter: ') ?? item.otherUsername;
                          final type = _extractField(content, 'Type: ') ?? 'unknown';
                          final reason = _extractField(content, 'Reason: ') ?? '';
                          final details = _extractField(content, 'Details: ') ?? '';
                          final when = item.message.timestamp.toLocal();

                          return ListTile(
                            title: Text('$type • $reporter'),
                            subtitle: Text(
                              [reason, details].where((s) => s.trim().isNotEmpty).join(' — '),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: Text(
                              '${when.month}/${when.day} ${when.hour.toString().padLeft(2, '0')}:${when.minute.toString().padLeft(2, '0')}',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            onTap: () {
                              context.push('/chat/${item.otherUserId}');
                            },
                          );
                        },
                      ),
      ),
    );
  }
}
