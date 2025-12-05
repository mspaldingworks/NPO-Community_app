import 'package:http/http.dart' as http;
import 'package:icalendar_parser/icalendar_parser.dart';
import 'package:transconnect/models/event.dart';

class CalendarService {
  final String _calenderUrl = 'https://calendar.google.com/calendar/ical/louisvilleyouthgroup.org_dsuqb6s982mabolcjioivdu5pk%40group.calendar.google.com/public/basic.ics';

  Future<List<Event>> fetchEvents() async {
    try {
      final response = await http.get(Uri.parse(_calenderUrl));
      if (response.statusCode == 200) {
        final iCalendar = ICalendar.fromString(response.body);

        return iCalendar.data
            .where((eventData) =>
                eventData['dtstart'] != null && eventData['dtend'] != null)
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
