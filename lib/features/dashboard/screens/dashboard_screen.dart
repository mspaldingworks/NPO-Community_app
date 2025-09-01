import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:transconnect/core/services/calendar_service.dart';
import 'package:transconnect/core/services/saved_events_service.dart';
import 'package:transconnect/features/dashboard/models/event_model.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final CalendarService _calendarService = CalendarService();
  late Future<List<Event>> _eventsFuture;

  @override
  void initState() {
    super.initState();
    _eventsFuture = _calendarService.fetchEvents();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: Column(
          children: [
            const SizedBox(height: 20),
            _buildInfoCards(),
            const SizedBox(height: 30),
            _buildQuoteCard(),
            const Spacer(),
            _buildLogo(),
            const SizedBox(height: 30),
            _buildEditProfileButton(context),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCards() {
    return FutureBuilder<List<Event>>(
      future: _eventsFuture,
      builder: (context, snapshot) {
        int eventCount = 0;
        if (snapshot.connectionState == ConnectionState.done && snapshot.hasData) {
          eventCount = snapshot.data!.length;
        }

        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildInfoCard(Icons.email_outlined, 'No unread messages'),
            _buildInfoCard(Icons.notifications_none_outlined, 'No new replies'),
            _buildInfoCard(Icons.calendar_today_outlined, '$eventCount upcoming events'),
          ],
        );
      },
    );
  }

  Widget _buildInfoCard(IconData icon, String text) {
    return Container(
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
    );
  }

  Widget _buildQuoteCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFE9E6FF),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Text(
        '"Equality means more than passing laws. The struggle is really won in the hearts and minds of the community, where it really counts." – Barbara Gittings',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 16, fontStyle: FontStyle.italic, color: Color(0xFF333333)),
      ),
    );
  }

  Widget _buildLogo() {
    // In a real app, this would be an Image.asset widget.
    // Using an icon as a placeholder for now.
    return const Icon(Icons.flutter_dash, size: 80, color: Colors.deepPurple);
  }

  Widget _buildEditProfileButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: () {
          context.go('/home/profile');
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF6A5AE0),
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
        ),
        child: const Text(
          'Edit Profile',
          style: TextStyle(fontSize: 18, color: Colors.white),
        ),
      ),
    );
  }
}
