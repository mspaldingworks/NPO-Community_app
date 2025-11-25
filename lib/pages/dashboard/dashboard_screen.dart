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


class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final CalendarService _calendarService = CalendarService();
  final FavoritesService _favoritesService = FavoritesService();
  final ProfileService _profileService = ProfileService();
  List<Event> _upcomingFavoritedEvents = [];
  File? _profileImage;
  bool _isLoading = true;
  AffirmationQuote? _quote;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    final allEvents = await _calendarService.fetchEvents();
    final favoriteIds = await _favoritesService.getFavorites();
    final imagePath = await _profileService.getImagePath();
    final now = DateTime.now();

    final quote = pickRandomQuote();

    final upcomingFavoritedEvents = allEvents.where((event) {
      final isFavorited = favoriteIds.contains(event.uid);
      final isUpcoming = event.start.isAfter(now);
      return isFavorited && isUpcoming;
    }).toList();

    if (mounted) {
      setState(() {
        _upcomingFavoritedEvents = upcomingFavoritedEvents;
        if (imagePath != null) {
          _profileImage = File(imagePath);
        }
        _isLoading = false;
        _quote = quote;
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
        child: Text('No upcoming favorited events.'),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Your Upcoming Events',
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
      child: CircleAvatar(
        radius: 40,
        backgroundColor: Colors.grey[200],
        // 1. If URL is null, backgroundImage is null
        // 2. If URL exists, CachedNetworkImageProvider handles 
        //    cache check -> download -> save -> display logic.
        backgroundImage: imageUrl != null 
            ? CachedNetworkImageProvider(imageUrl) 
            : null,
        child: imageUrl == null
            ? const Icon(Icons.person, size: 40)
            : null, 
      ),
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

}
