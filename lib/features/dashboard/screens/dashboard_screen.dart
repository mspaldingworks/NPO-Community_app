import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:transconnect/core/services/calendar_service.dart';
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
        title: const Text('Home'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => context.go('/home/settings'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          _buildSectionHeader(context, 'Upcoming Events'),
          const SizedBox(height: 8.0),
          _buildEventsCarousel(),
          const SizedBox(height: 24.0),
          _buildSectionHeader(context, 'Recent Activity'),
          const SizedBox(height: 8.0),
          _buildRecentActivityList(),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
    );
  }

  Widget _buildEventsCarousel() {
    return FutureBuilder<List<Event>>(
      future: _eventsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(
            height: 150,
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError) {
          return SizedBox(
            height: 150,
            child: Center(child: Text('Error: ${snapshot.error}')),
          );
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const SizedBox(
            height: 150,
            child: Center(child: Text('No upcoming events.')),
          );
        }

        final events = snapshot.data!;
        return SizedBox(
          height: 150,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: events.length,
            itemBuilder: (context, index) {
              final event = events[index];
              return Card(
                margin: const EdgeInsets.only(right: 16.0),
                child: SizedBox(
                  width: 250,
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          event.summary,
                          style: Theme.of(context).textTheme.titleMedium,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const Spacer(),
                        Text(
                          DateFormat.yMMMd().add_jm().format(event.start),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        if (event.location != null)
                          Text(
                            event.location!,
                            style: Theme.of(context).textTheme.bodySmall,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildRecentActivityList() {
    // Placeholder for a vertical list of recent messages or resources
    return Column(
      children: List.generate(3, (index) {
        return const ListTile(
          leading: Icon(Icons.message),
          title: Text('New message in #general'),
          subtitle: Text('User: Hey everyone!'),
        );
      }),
    );
  }
}
