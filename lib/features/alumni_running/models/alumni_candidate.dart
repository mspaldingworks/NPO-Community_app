/// An Emerge Kentucky alum who is on the ballot this election cycle.
///
/// Only public campaign information belongs here: name, office sought,
/// election, and public campaign links. No demographic or identity fields.
class AlumniCandidate {
  const AlumniCandidate({
    required this.name,
    required this.office,
    required this.election,
    this.campaignUrl,
    this.infoUrl,
  });

  final String name;

  /// Office sought, e.g. "Kentucky State Senate, District 6".
  final String office;

  /// Election the candidate is on the ballot for.
  final String election;

  /// Official live campaign page, when the campaign has one.
  final Uri? campaignUrl;

  /// Public candidate profile used when no campaign page is known.
  final Uri? infoUrl;

  /// The link the card opens: the campaign page first, then the profile.
  Uri? get primaryUrl => campaignUrl ?? infoUrl;

  bool get hasCampaignPage => campaignUrl != null;

  String get initials {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return '?';
    final parts = trimmed.split(RegExp(r'\s+'));
    final first = parts.first[0];
    final last = parts.length > 1 ? parts.last[0] : '';
    return '$first$last'.toUpperCase();
  }
}
