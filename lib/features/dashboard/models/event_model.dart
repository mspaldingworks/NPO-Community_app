class Event {
  final String summary;
  final String? description;
  final DateTime start;
  final DateTime end;
  final String? location;

  Event({
    required this.summary,
    this.description,
    required this.start,
    required this.end,
    this.location,
  });
}
