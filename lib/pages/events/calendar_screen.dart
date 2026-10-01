import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:npo_community/core/services/calendar_service.dart';
import 'package:npo_community/core/services/favorites_service.dart';
import 'package:npo_community/models/event.dart';
import 'package:npo_community/features/onboarding_tour/widgets/tour_anchor.dart';
import 'package:npo_community/features/alumni_running/campaign_hub_controller.dart';
import 'package:npo_community/features/alumni_running/models/campaign_shift.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  final CalendarService _calendarService = CalendarService();
  final FavoritesService _favoritesService = FavoritesService();
  List<Event> _allEvents = [];
  List<Event> _shiftEvents = [];
  CampaignHubController? _hub;
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

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    CampaignHubController? hub;
    try {
      hub = Provider.of<CampaignHubController>(context, listen: false);
    } on ProviderNotFoundException {
      hub = null;
    }
    if (identical(hub, _hub)) return;
    _hub?.removeListener(_syncShifts);
    _hub = hub;
    if (hub != null) {
      hub.addListener(_syncShifts);
      _syncShifts();
      WidgetsBinding.instance.addPostFrameCallback((_) => hub!.ensureLoaded());
    }
  }

  @override
  void dispose() {
    _hub?.removeListener(_syncShifts);
    super.dispose();
  }

  /// Mirrors the user's campaign shift sign-ups into the calendar.
  void _syncShifts() {
    final hub = _hub;
    if (hub == null || !mounted) return;
    setState(() {
      _shiftEvents = hub.myShifts.map((s) => _shiftEvent(hub, s)).toList();
      if (_selectedDay != null) {
        _selectedEvents = _getEventsForDay(_selectedDay!);
      }
    });
  }

  static Event _shiftEvent(CampaignHubController hub, CampaignShift shift) {
    final candidate = hub.candidateById(shift.candidateId);
    final title = candidate == null
        ? shift.displayTitle
        : '${shift.displayTitle} · ${candidate.name}';
    return Event(
      uid: 'campaign-shift-${shift.id}',
      summary: 'Campaign shift: $title',
      start: shift.startsAt,
      end: shift.endsAt ?? shift.startsAt.add(const Duration(hours: 2)),
      location: shift.location,
      isCampaignShift: true,
    );
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
    return [..._allEvents, ..._shiftEvents].where((event) {
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
        title: const TourAnchor(
          name: 'Events Calendar',
          child: Text('Events Calendar'),
        ),
      ),
      body: Column(
        children: [
          TableCalendar<Event>(
            firstDay: DateTime.utc(2020, 1, 1),
            lastDay: DateTime.utc(2030, 12, 31),
            focusedDay: _focusedDay,
            calendarFormat: CalendarFormat.month,
            availableCalendarFormats: const {CalendarFormat.month: 'Month'},
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
                        margin: const EdgeInsets.symmetric(
                          horizontal: 12.0,
                          vertical: 4.0,
                        ),
                        child: ListTile(
                          leading: event.isCampaignShift
                              ? const Icon(Icons.how_to_vote_outlined)
                              : null,
                          title: Text(event.summary),
                          subtitle: Text(
                            [
                              '${event.start.toLocal()}',
                              if (event.isCampaignShift &&
                                  event.location != null)
                                event.location!,
                            ].join('\n'),
                          ),
                          trailing: event.isCampaignShift
                              ? const Chip(
                                  label: Text('Campaign shift'),
                                  visualDensity: VisualDensity.compact,
                                )
                              : IconButton(
                                  icon: Icon(
                                    isFavorite
                                        ? Icons.favorite
                                        : Icons.favorite_border,
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
