import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:transconnect/core/services/calendar_service.dart';
import 'package:transconnect/features/events/services/favorites_service.dart';
import 'package:transconnect/models/event.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  final CalendarService _calendarService = CalendarService();
  final FavoritesService _favoritesService = FavoritesService();
  List<Event> _allEvents = [];
  List<Event> _selectedEvents = [];
  List<String> _favoriteEventIds = [];
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _loadData();
  }

  Future<void> _loadData() async {
    final allEvents = await _calendarService.fetchEvents();
    final favoriteIds = await _favoritesService.getFavorites();
    if (mounted) {
      setState(() {
        _allEvents = allEvents;
        _favoriteEventIds = favoriteIds;
        _selectedEvents = _getEventsForDay(_selectedDay!);
        _isLoading = false;
      });
    }
  }

  List<Event> _getEventsForDay(DateTime day) {
    return _allEvents.where((event) {
      return isSameDay(event.start, day);
    }).toList();
  }

  void _onDaySelected(DateTime selectedDay, DateTime focusedDay) {
    if (!isSameDay(_selectedDay, selectedDay)) {
      setState(() {
        _selectedDay = selectedDay;
        _focusedDay = focusedDay;
        _selectedEvents = _getEventsForDay(selectedDay);
      });
    }
  }

  void _toggleFavorite(String eventId) async {
    if (_favoriteEventIds.contains(eventId)) {
      await _favoritesService.removeFavorite(eventId);
    } else {
      await _favoritesService.addFavorite(eventId);
    }
    _favoriteEventIds = await _favoritesService.getFavorites();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Events Calendar'),
      ),
      body: Column(
        children: [
          TableCalendar<Event>(
            firstDay: DateTime.utc(2020, 1, 1),
            lastDay: DateTime.utc(2030, 12, 31),
            focusedDay: _focusedDay,
            selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
            onDaySelected: _onDaySelected,
            eventLoader: _getEventsForDay,
            calendarStyle: const CalendarStyle(
              todayDecoration: BoxDecoration(
                color: Colors.deepPurpleAccent,
                shape: BoxShape.circle,
              ),
              selectedDecoration: BoxDecoration(
                color: Colors.blue,
                shape: BoxShape.circle,
              ),
            ),
          ),
          const SizedBox(height: 8.0),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _selectedEvents.isEmpty
                    ? const Center(child: Text('No events for this day.'))
                    : ListView.builder(
                        itemCount: _selectedEvents.length,
                        itemBuilder: (context, index) {
                          final event = _selectedEvents[index];
                          final isFavorite = _favoriteEventIds.contains(event.uid);
                          return Card(
                            margin: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
                            child: ListTile(
                              title: Text(event.summary),
                              subtitle: Text('${event.start.toLocal()}'),
                              trailing: IconButton(
                                icon: Icon(
                                  isFavorite ? Icons.favorite : Icons.favorite_border,
                                  color: isFavorite ? Colors.red : null,
                                ),
                                onPressed: () => _toggleFavorite(event.uid),
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
