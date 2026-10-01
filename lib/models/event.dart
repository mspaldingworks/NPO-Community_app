class Event {
  final String uid;
  final String summary;
  final String? description;
  final DateTime start;
  final DateTime end;
  final String? location;

  /// The user's own campaign volunteer shift (session-only, never favorited
  /// or persisted).
  final bool isCampaignShift;

  Event({
    required this.uid,
    required this.summary,
    this.description,
    required this.start,
    required this.end,
    this.location,
    this.isCampaignShift = false,
  });
}
