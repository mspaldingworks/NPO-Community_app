/// An Emerge Kentucky alum who is on the ballot this election cycle.
///
/// Only public campaign information belongs here: name, race, election,
/// public photo and public campaign links. No demographic or identity fields.
class AlumniCandidate {
  const AlumniCandidate({
    required this.name,
    required this.office,
    required this.election,
    this.seedId,
    this.classYear,
    this.status,
    this.photoUrl,
    this.campaignUrl,
    this.ballotpediaUrl,
    this.volunteerUrl,
    this.donateUrl,
    this.volunteerOpportunities = const [],
  });

  final String name;

  /// The alumna's `seed_id` in emerge_ky_seed.json, the source of truth for
  /// who appears on the Ballot page.
  final String? seedId;

  /// Emerge Kentucky class year, e.g. 2022.
  final int? classYear;

  /// The race: office sought, e.g. "Kentucky State Senate, District 6".
  final String office;

  /// Election the candidate is on the ballot for.
  final String election;

  /// Where the race stands, e.g. "Incumbent; vs. Tray Hughes".
  final String? status;

  /// Public headshot. Cards fall back to initials when it is missing or
  /// fails to load, and never fetch it in demo mode.
  final Uri? photoUrl;

  /// Official campaign website, when the campaign has one.
  final Uri? campaignUrl;

  /// Ballotpedia profile for the race.
  final Uri? ballotpediaUrl;

  /// General volunteer sign-up page for the campaign.
  final Uri? volunteerUrl;

  /// The campaign's donation page.
  final Uri? donateUrl;

  /// Dated volunteer shifts (canvasses, phone banks, ...). Past ones are
  /// hidden, so the list can be left as-is after an event happens.
  final List<VolunteerOpportunity> volunteerOpportunities;

  /// Volunteer opportunities that haven't ended yet, soonest first.
  List<VolunteerOpportunity> upcomingOpportunities(DateTime now) {
    final upcoming = volunteerOpportunities
        .where((o) => !o.hasEndedBy(now))
        .toList();
    upcoming.sort((a, b) => a.startsAt.compareTo(b.startsAt));
    return upcoming;
  }

  String get initials {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return '?';
    final parts = trimmed.split(RegExp(r'\s+'));
    final first = parts.first[0];
    final last = parts.length > 1 ? parts.last[0] : '';
    return '$first$last'.toUpperCase();
  }
}

/// One dated volunteer event for a campaign.
class VolunteerOpportunity {
  const VolunteerOpportunity({
    required this.title,
    required this.startsAt,
    required this.signupUrl,
    this.endsAt,
    this.location,
  });

  final String title;
  final DateTime startsAt;
  final DateTime? endsAt;
  final String? location;
  final Uri signupUrl;

  /// Without an end time, an event counts as over the day after it starts.
  bool hasEndedBy(DateTime now) {
    final end =
        endsAt ??
        DateTime(
          startsAt.year,
          startsAt.month,
          startsAt.day,
        ).add(const Duration(days: 1));
    return !end.isAfter(now);
  }
}
