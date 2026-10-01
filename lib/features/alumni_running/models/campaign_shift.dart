/// The kind of volunteer shift a campaign is asking for.
enum CampaignShiftKind {
  canvass,
  phoneBank,
  event,
  other;

  static CampaignShiftKind parse(Object? value) {
    final normalized = value?.toString().trim().toLowerCase().replaceAll(
      '-',
      '_',
    );
    return switch (normalized) {
      'canvass' => CampaignShiftKind.canvass,
      'phone_bank' || 'phonebank' => CampaignShiftKind.phoneBank,
      'event' => CampaignShiftKind.event,
      _ => CampaignShiftKind.other,
    };
  }

  String get label => switch (this) {
    CampaignShiftKind.canvass => 'Canvass',
    CampaignShiftKind.phoneBank => 'Phone bank',
    CampaignShiftKind.event => 'Event',
    CampaignShiftKind.other => 'Volunteer shift',
  };
}

/// A volunteer shift for an alumni candidate's campaign.
///
/// [signedUp] is the current user's own sign-up state. It is political
/// opinion data: kept only in the in-memory session cache, never persisted
/// or shown to anyone else.
class CampaignShift {
  const CampaignShift({
    required this.id,
    required this.candidateId,
    required this.kind,
    required this.startsAt,
    this.endsAt,
    this.title,
    this.location,
    this.capacity,
    this.remaining,
    this.signedUp = false,
  });

  final String id;
  final String candidateId;
  final CampaignShiftKind kind;
  final DateTime startsAt;
  final DateTime? endsAt;
  final String? title;

  /// Free-text location, e.g. "Highlands office, Louisville".
  final String? location;

  /// Total spots, `null` when unlimited.
  final int? capacity;

  /// Spots left, `null` when unlimited.
  final int? remaining;
  final bool signedUp;

  String get displayTitle => title ?? kind.label;

  bool get isFull => remaining != null && remaining! <= 0;

  factory CampaignShift.fromJson(
    Map<String, dynamic> json, {
    String? candidateId,
  }) {
    final id = json['id']?.toString().trim() ?? '';
    final startsAt = DateTime.tryParse(json['starts_at']?.toString() ?? '');
    final owner = json['candidate_id']?.toString().trim() ?? candidateId ?? '';
    if (id.isEmpty || startsAt == null || owner.isEmpty) {
      throw const FormatException('Shift is missing id, candidate, or start');
    }
    final title = json['title'];
    final location = json['location'];
    return CampaignShift(
      id: id,
      candidateId: owner,
      kind: CampaignShiftKind.parse(json['kind']),
      startsAt: startsAt,
      endsAt: DateTime.tryParse(json['ends_at']?.toString() ?? ''),
      title: title is String && title.trim().isNotEmpty ? title.trim() : null,
      location: location is String && location.trim().isNotEmpty
          ? location.trim()
          : null,
      capacity: _int(json['capacity']),
      remaining: _int(json['remaining']),
      signedUp: json['signed_up'] == true,
    );
  }

  CampaignShift copyWith({int? remaining, bool? signedUp}) => CampaignShift(
    id: id,
    candidateId: candidateId,
    kind: kind,
    startsAt: startsAt,
    endsAt: endsAt,
    title: title,
    location: location,
    capacity: capacity,
    remaining: remaining ?? this.remaining,
    signedUp: signedUp ?? this.signedUp,
  );

  static int? _int(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value.trim());
    return null;
  }
}
