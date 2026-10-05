import 'dart:convert';
import 'dart:typed_data';

import 'package:npo_community/features/events/events_service.dart';
import 'package:share_plus/share_plus.dart';

String _stamp(DateTime when) {
  final u = when.toUtc();
  String two(int v) => v.toString().padLeft(2, '0');
  return '${u.year}${two(u.month)}${two(u.day)}T${two(u.hour)}${two(u.minute)}${two(u.second)}Z';
}

String _escape(String text) => text
    .replaceAll('\\', '\\\\')
    .replaceAll(';', '\\;')
    .replaceAll(',', '\\,')
    .replaceAll('\n', '\\n');

/// An iCalendar file for one event, for "Add to calendar".
String buildIcs(CommunityEvent event) {
  final end = event.endsAt ?? event.startsAt.add(const Duration(hours: 2));
  final location = event.isVirtual && event.virtualLink.isNotEmpty
      ? event.virtualLink
      : event.locationName;
  final lines = <String>[
    'BEGIN:VCALENDAR',
    'VERSION:2.0',
    'PRODID:-//Emerge Kentucky Alumni//EN',
    'BEGIN:VEVENT',
    'UID:event-${event.id}@emergeky.app',
    'DTSTAMP:${_stamp(DateTime.now())}',
    'DTSTART:${_stamp(event.startsAt)}',
    'DTEND:${_stamp(end)}',
    'SUMMARY:${_escape(event.title)}',
    if (event.description.isNotEmpty)
      'DESCRIPTION:${_escape(event.description)}',
    if (location.isNotEmpty) 'LOCATION:${_escape(location)}',
    if (event.virtualLink.isNotEmpty) 'URL:${event.virtualLink}',
    if (event.isCancelled) 'STATUS:CANCELLED',
    'END:VEVENT',
    'END:VCALENDAR',
  ];
  return '${lines.join('\r\n')}\r\n';
}

/// Hands the event to the system share sheet as an .ics file; Calendar is
/// one of the targets.
Future<void> shareIcs(CommunityEvent event) {
  final bytes = Uint8List.fromList(utf8.encode(buildIcs(event)));
  return Share.shareXFiles([
    XFile.fromData(
      bytes,
      mimeType: 'text/calendar',
      name: 'emerge-ky-event.ics',
    ),
  ], subject: event.title);
}
