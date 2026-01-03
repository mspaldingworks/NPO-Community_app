import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:transconnect/core/services/auth_service.dart';
import 'package:transconnect/core/services/community_service.dart';
import 'package:transconnect/core/services/exchange_service.dart';
import 'package:transconnect/models/post.dart';

class HelpListingsScreen extends StatefulWidget {
  const HelpListingsScreen({super.key});

  @override
  State<HelpListingsScreen> createState() => _HelpListingsScreenState();
}

class _HelpListingsScreenState extends State<HelpListingsScreen> {
  final AuthService _authService = AuthService();

  late final CommunityService _communityService;
  late final ExchangeService _exchangeService;
  bool _initialized = false;

  late Future<List<Post>> _postsFuture;
  Map<String, int> _userIdByUsername = {};

  ExchangeKind? _kindFilter;

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;

    _communityService = context.read<CommunityService>();
    _exchangeService = ExchangeService(communityService: _communityService);
    _postsFuture = _exchangeService.fetchHelpPosts();
    _loadUserLookup();
  }

  Future<void> _loadUserLookup() async {
    final users = await _authService.getAllUsers();
    if (!mounted) return;

    setState(() {
      _userIdByUsername = {for (final u in users) u.username: u.id};
    });
  }

  Future<void> _refresh() async {
    setState(() {
      _postsFuture = _exchangeService.fetchHelpPosts();
    });
    await _loadUserLookup();
  }

  int? _resolveAuthorId(Post post) {
    if (post.isAnonymous) return null;
    if (post.author != null) return post.author;
    final username = post.authorUsername;
    if (username == null || username.isEmpty) return null;
    return _userIdByUsername[username];
  }

  List<Post> _applyFilters(List<Post> posts) {
    if (_kindFilter == null) return posts;

    final filtered = <Post>[];
    for (final p in posts) {
      final meta = ExchangeMetadata.tryParse(p.feeling);
      if (meta == null) continue;
      if (meta.kind != _kindFilter) continue;
      filtered.add(p);
    }
    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Help Listings'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                DropdownButton<ExchangeKind?>(
                  value: _kindFilter,
                  onChanged: (value) {
                    setState(() {
                      _kindFilter = value;
                    });
                  },
                  items: const [
                    DropdownMenuItem(value: null, child: Text('All')),
                    DropdownMenuItem(value: ExchangeKind.offer, child: Text('Offers')),
                    DropdownMenuItem(value: ExchangeKind.request, child: Text('Requests')),
                  ],
                ),
                if (_kindFilter != null)
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _kindFilter = null;
                      });
                    },
                    child: const Text('Clear'),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: FutureBuilder<List<Post>>(
              future: _postsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Failed to load listings: ${snapshot.error}'));
                }

                final posts = _applyFilters(snapshot.data ?? const []);

                if (posts.isEmpty) {
                  return RefreshIndicator(
                    onRefresh: _refresh,
                    child: ListView(
                      children: const [
                        SizedBox(height: 120),
                        Center(
                          child: Padding(
                            padding: EdgeInsets.all(24),
                            child: Text(
                              'No help listings yet.\nTap + to post one.',
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: _refresh,
                  child: ListView.separated(
                    padding: const EdgeInsets.only(bottom: 96),
                    itemCount: posts.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final post = posts[index];
                      final meta = ExchangeMetadata.tryParse(post.feeling);
                      final title = (post.title ?? '').trim();
                      final body = (post.body ?? '').trim();

                      final subtitleParts = <String>[];
                      if (meta != null) {
                        subtitleParts.add(meta.kind == ExchangeKind.offer ? 'Offer' : 'Request');
                        subtitleParts.add('Free');
                      }

                      final subtitle = subtitleParts.join(' · ');

                      final authorLabel = post.isAnonymous
                          ? 'Anonymous'
                          : (post.authorUsername ?? (post.author != null ? 'User ${post.author}' : 'Unknown user'));

                      return ListTile(
                        leading: Text(post.emojis.isNotEmpty ? post.emojis.first : (post.emoji ?? '🆘'), style: const TextStyle(fontSize: 28)),
                        title: Text(title.isEmpty ? '(Untitled)' : title),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (subtitle.isNotEmpty) Text(subtitle),
                            const SizedBox(height: 4),
                            Text(
                              body,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'By $authorLabel',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                        onTap: () {
                          context.push('/exchange/post/${post.id}', extra: post);
                        },
                        trailing: IconButton(
                          tooltip: 'Contact',
                          icon: const Icon(Icons.chat_bubble_outline),
                          onPressed: () {
                            final userId = _resolveAuthorId(post);
                            if (userId == null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Cannot message anonymous/unknown user.')),
                              );
                              return;
                            }
                            context.push('/chat/$userId');
                          },
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await context.push<bool>('/exchange/create');
          if (result == true && mounted) {
            _refresh();
          }
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
