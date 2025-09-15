import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:transconnect/core/services/calendar_service.dart';
import 'package:transconnect/features/events/services/favorites_service.dart';
import 'package:transconnect/features/profile/services/profile_service.dart';
import 'package:transconnect/models/event.dart';

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
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Home'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () {
              context.push('/profile/settings');
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadDashboardData,
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            _buildInfoCards(),
            const SizedBox(height: 24),
            _buildQuoteCard(),
            const SizedBox(height: 24),
            _buildUpcomingFavoritedEvents(),
            const SizedBox(height: 24),
            _buildProfileAvatar(),
            const SizedBox(height: 16),
            _buildEditProfileButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCards() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _buildInfoCard(Icons.email_outlined, 'No unread messages'),
        _buildInfoCard(Icons.notifications_none_outlined, 'No new replies'),
        _buildInfoCard(
          Icons.calendar_today_outlined,
          _isLoading ? '...' : '${_upcomingFavoritedEvents.length} upcoming events',
          onTap: () {
            context.push('/calendar');
          },
        ),
      ],
    );
  }

  Widget _buildInfoCard(IconData icon, String text, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
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
            Icon(icon, size: 30, color: Colors.grey[600]),
            const SizedBox(height: 8),
            Text(
              text,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.grey[700]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuoteCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.deepPurple.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '"The time is always right to do what is right."',
            style: TextStyle(fontSize: 16, fontStyle: FontStyle.italic),
          ),
          SizedBox(height: 8),
          Align(
            alignment: Alignment.bottomRight,
            child: Text(
              '- Martin Luther King Jr.',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUpcomingFavoritedEvents() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_upcomingFavoritedEvents.isEmpty) {
      return const Center(
        child: Text('No upcoming favorited events.'),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Your Upcoming Events',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _upcomingFavoritedEvents.length,
          itemBuilder: (context, index) {
            final event = _upcomingFavoritedEvents[index];
            return Card(
              margin: const EdgeInsets.only(bottom: 8.0),
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
    return Center(
      child: CircleAvatar(
        radius: 40,
        backgroundImage: _profileImage != null ? FileImage(_profileImage!) : null,
        child: _profileImage == null
            ? const Icon(
                Icons.person,
                size: 40,
              )
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
          backgroundColor: const Color(0xFF5E4A59),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
        ),
        child: const Text('Edit Profile'),
      ),
    );
  }
}
