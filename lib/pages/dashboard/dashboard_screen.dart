import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:transconnect/core/services/calendar_service.dart';
import 'package:transconnect/data/affirmation_quotes.dart';
import 'package:transconnect/features/events/services/favorites_service.dart';
import 'package:transconnect/features/profile/services/profile_service.dart';
import 'package:transconnect/models/event.dart';
import 'package:transconnect/theme/app_theme.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:transconnect/models/user.dart';
import 'package:transconnect/core/services/auth_service.dart';
import 'package:transconnect/widgets/display_profile_pic.dart';
import 'package:transconnect/core/services/friend_service.dart';
import 'package:transconnect/core/utils/time_ago.dart';
import 'package:transconnect/core/services/chat_service.dart';


class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final CalendarService _calendarService = CalendarService();
  final FavoritesService _favoritesService = FavoritesService();
  final ProfileService _profileService = ProfileService();
  final FriendService _friendService = FriendService();
  final ChatService _chatService = ChatService();
  List<Event> _upcomingFavoritedEvents = [];
  File? _profileImage;
  bool _isLoading = true;
  AffirmationQuote? _quote;
  List<Friend> _friendStatusFeed = [];
  bool _isLoadingFriendFeed = true;
  final Map<int, TextEditingController> _statusCommentCtrls = {};

  TextEditingController _ctrlFor(int friendId)
      => _statusCommentCtrls.putIfAbsent(friendId, () => TextEditingController());

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  @override
  void dispose() {
    for (final c in _statusCommentCtrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _loadDashboardData() async {
    final allEvents = await _calendarService.fetchEvents();
    final favoriteIds = await _favoritesService.getFavorites();
    final imagePath = await _profileService.getImagePath();
    final now = DateTime.now();

    final quote = pickRandomQuote();

    // Load friends and prepare status feed (descending by updated time)
    var apiFriends = await _friendService.listFriends();
    // Ensure auth/session is loaded, then retry once
    if (apiFriends.isEmpty) {
      try { await AuthService().getCurrentUser(); } catch (_) {}
      apiFriends = await _friendService.listFriends();
    }

    // Merge with friends embedded in current user payload; prefer entries with non-empty status
    List<Friend> meFriends = const [];
    try { meFriends = (await AuthService().getCurrentUser()).friends; } catch (_) {}

    final Map<int, Friend> friendsById = {};
    void addOrPrefer(Friend f) {
      final existing = friendsById[f.id];
      if (existing == null) {
        friendsById[f.id] = f;
      } else {
        final hasStatus = (f.statusMessage?.trim().isNotEmpty ?? false);
        final existingHasStatus = (existing.statusMessage?.trim().isNotEmpty ?? false);
        if (hasStatus && !existingHasStatus) {
          friendsById[f.id] = f;
        } else if (hasStatus == existingHasStatus) {
          // If both or neither have status, prefer the newer update time
          final fa = f.statusUpdatedAt;
          final fb = existing.statusUpdatedAt;
          if (fa != null && (fb == null || fa.isAfter(fb))) {
            friendsById[f.id] = f;
          }
        }
      }
    }

    for (final f in apiFriends) addOrPrefer(f);
    for (final f in meFriends) addOrPrefer(f);

    final mergedFriends = friendsById.values.toList();
    final statuses = mergedFriends
        .where((f) => (f.statusMessage?.trim().isNotEmpty ?? false))
        .toList();
    statuses.sort((a, b) {
      final A = a.statusUpdatedAt;
      final B = b.statusUpdatedAt;
      if (A == null && B == null) return 0;
      if (A == null) return 1; // nulls last
      if (B == null) return -1;
      return B.compareTo(A); // newest first
    });

    // Today-only events in chronological order
    final todaysEvents = allEvents.where((event) {
      final d = event.start.toLocal();
      return d.year == now.year && d.month == now.month && d.day == now.day;
    }).toList()
      ..sort((a, b) => a.start.compareTo(b.start));

    // Show only favorited events on the dashboard
    final todaysFavoritedEvents = todaysEvents
        .where((e) => favoriteIds.contains(e.uid))
        .toList();

    if (mounted) {
      setState(() {
        _upcomingFavoritedEvents = todaysFavoritedEvents;
        if (imagePath != null) {
          _profileImage = File(imagePath);
        }
        _isLoading = false;
        _quote = quote;
        _friendStatusFeed = statuses;
        _isLoadingFriendFeed = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Home'),
        actions: [
          IconButton(
            icon: Icon(Icons.settings_outlined),
            onPressed: () {
              context.push('/profile/settings');
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadDashboardData,
        child: ListView(
          padding: EdgeInsets.all(16.0),
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                GestureDetector(
                  onTap: () {
                    context.push('/chat');
                  },
                  child: Container(
                    width: 110,
                    height: 90,
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.chat, size: 30, color: Colors.grey[600]),
                        SizedBox(height: 8),
                        Text(
                          'Friends',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                        ),
                      ],
                    ),
                  ),
                ),
                _buildInfoCard(Icons.notifications_none_outlined, 'No new replies'),
                _buildInfoCard(
                  Icons.calendar_today_outlined,
                  _isLoading ? '...' : '${_upcomingFavoritedEvents.length} upcoming events',
                  onTap: () {
                    context.push('/events/calendar');
                  },
                  isHighlighted: _upcomingFavoritedEvents.isNotEmpty,
                ),
              ],
            ),
            SizedBox(height: 24),
            _buildQuoteCard(),
            SizedBox(height: 24),
            _buildUpcomingFavoritedEvents(),
            SizedBox(height: 24),
            _buildProfileAvatar(),
            SizedBox(height: 16),
            _buildEditProfileButton(),
            SizedBox(height: 24),
            _buildFriendsStatusUpdates(),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard(IconData icon, String text, {VoidCallback? onTap, bool isHighlighted = false}) {
    final Color backgroundColor = isHighlighted ? AppColors.tertiary : Colors.grey[200]!;
    final Color contentColor = isHighlighted ? AppColors.textWhite : Colors.grey[700]!;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 110,
        height: 90,
        padding: const EdgeInsets.all(8.0),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 30, color: contentColor),
            const SizedBox(height: 8),
            Text(
              text,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: contentColor, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuoteCard() {
    final quote = _quote ?? pickRandomQuote();

    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.deepPurple.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '"${quote.text}"',
            style: TextStyle(fontSize: 16, fontStyle: FontStyle.italic),
          ),
          SizedBox(height: 8),
          Align(
            alignment: Alignment.bottomRight,
            child: Text(
              '- ${quote.author}',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUpcomingFavoritedEvents() {
    if (_isLoading) {
      return Center(child: CircularProgressIndicator());
    }

    if (_upcomingFavoritedEvents.isEmpty) {
      return Center(
        child: Text('No events today.'),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Today's Events",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        SizedBox(height: 12),
        ListView.builder(
          shrinkWrap: true,
          physics: NeverScrollableScrollPhysics(),
          itemCount: _upcomingFavoritedEvents.length,
          itemBuilder: (context, index) {
            final event = _upcomingFavoritedEvents[index];
            return Card(
              margin: EdgeInsets.only(bottom: 8.0),
              child: ListTile(
                title: Text(event.summary),
                subtitle: Text('${event.start.toLocal()}'),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildProfileAvatar() {
    final authService = Provider.of<AuthService>(context, listen: false);
    final currentUser = authService.currentUser;
    final imageUrl = currentUser?.fullProfilePicUrl;

    return Center(
      child: DisplayProfilePic(radius: 40, imageUrl: imageUrl),
    );
  }

  Widget _buildEditProfileButton() {
    return Center(
      child: ElevatedButton(
        onPressed: () {
          context.push('/profile');
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.secondary,
          foregroundColor: AppColors.textBlack,
          padding: EdgeInsets.symmetric(horizontal: 40, vertical: 15),
        ),
        child: Text('Edit Profile'),
      ),
    );
  }

  Widget _buildFriendsStatusUpdates() {
    if (_isLoadingFriendFeed) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Friends Status Updates',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        SizedBox(height: 12),
        if (_friendStatusFeed.isEmpty)
          Center(child: Text('No recent status updates.'))
        else
          ListView.builder(
            shrinkWrap: true,
            physics: NeverScrollableScrollPhysics(),
            itemCount: _friendStatusFeed.length,
            itemBuilder: (context, index) {
              final friend = _friendStatusFeed[index];
              final when = friend.statusUpdatedAt;
              final msg = friend.statusMessage?.trim() ?? '';
              return Card(
                margin: EdgeInsets.only(bottom: 8.0),
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: DisplayProfilePic(radius: 20, imageUrl: friend.fullProfilePicUrl),
                        title: Text(friend.username),
                        subtitle: Text(
                          when == null ? msg : '$msg • ${timeAgo(when)}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          DisplayProfilePic(
                            radius: 16,
                            imageUrl: Provider.of<AuthService>(context, listen: false).currentUser?.fullProfilePicUrl,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: _ctrlFor(friend.id),
                              decoration: InputDecoration(
                                hintText: "Comment on ${friend.username}'s status...",
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(20)),
                                suffixIcon: IconButton(
                                  icon: const Icon(Icons.send),
                                  color: Colors.pink,
                                  onPressed: () async {
                                    final text = _ctrlFor(friend.id).text.trim();
                                    if (text.isEmpty) return;
                                    try {
                                      await _chatService.sendMessage(recipientId: friend.id, content: text);
                                      if (!mounted) return;
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text('Comment sent to ${friend.username}')),
                                      );
                                      _ctrlFor(friend.id).clear();
                                    } catch (e) {
                                      if (!mounted) return;
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text('Failed to send: $e')),
                                      );
                                    }
                                  },
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
      ],
    );
  }

}
