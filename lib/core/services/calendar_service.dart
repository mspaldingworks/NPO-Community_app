import 'package:http/http.dart' as http;
import 'package:icalendar_parser/icalendar_parser.dart';
import 'package:transconnect/features/dashboard/models/event_model.dart';

class CalendarService {
  final String _calenderUrl = 'https://calendar.google.com/calendar/ical/c_5e1fb913d97c3279485d1cb25013c8947232eed0bbc5068ed003be9cebf4c58a%40group.calendar.google.com/public/basic.ics';

  Future<List<Event>> fetchEvents() async {
    try {
      final response = await http.get(Uri.parse(_calenderUrl));
      if (response.statusCode == 200) {
        final iCalendar = ICalendar.fromString(response.body);
        final now = DateTime.now();

        return iCalendar.data
            .where((event) => event['dtstart']?.toDateTime()?.isAfter(now) ?? false)
            .map((eventData) {
          return Event(
            uid: eventData['uid'] ?? '',
            summary: eventData['summary'] ?? 'No Title',
            description: eventData['description'],
            start: eventData['dtstart'].toDateTime()!,
            end: eventData['dtend'].toDateTime()!,
            location: eventData['location'],
          );
        }).toList()..sort((a, b) => a.start.compareTo(b.start));
      } else {
        throw Exception('Failed to load calendar');
      }
    } catch (e) {
      throw Exception('Error fetching events: $e');
    }
  }
}
