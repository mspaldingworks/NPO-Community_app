/// Where a candidate's race stands.
enum CandidateRaceStatus {
  running,
  wonPrimary,
  won,
  didNotWin,

  /// A status this app version does not recognize. Treated like [running]
  /// for display, never as a win.
  unknown;

  static CandidateRaceStatus parse(Object? value) {
    final normalized = value
        ?.toString()
        .trim()
        .toLowerCase()
        .replaceAll('-', '_')
        .replaceAll(' ', '_');
    return switch (normalized) {
      'running' => CandidateRaceStatus.running,
      'won_primary' => CandidateRaceStatus.wonPrimary,
      'won' => CandidateRaceStatus.won,
      'did_not_win' || 'lost' => CandidateRaceStatus.didNotWin,
      _ => CandidateRaceStatus.unknown,
    };
  }

  /// The API value for this status. [unknown] is never sent.
  String get wireValue => switch (this) {
    CandidateRaceStatus.running || CandidateRaceStatus.unknown => 'running',
    CandidateRaceStatus.wonPrimary => 'won_primary',
    CandidateRaceStatus.won => 'won',
    CandidateRaceStatus.didNotWin => 'did_not_win',
  };

  bool get isWin =>
      this == CandidateRaceStatus.wonPrimary || this == CandidateRaceStatus.won;

  String get label => switch (this) {
    CandidateRaceStatus.running || CandidateRaceStatus.unknown => 'Running',
    CandidateRaceStatus.wonPrimary => 'Won primary',
    CandidateRaceStatus.won => 'Won',
    CandidateRaceStatus.didNotWin => 'Did not win',
  };
}

/// A community post where alumni can congratulate a winning candidate,
/// using the existing group post/comment flow.
class CandidateWinPost {
  const CandidateWinPost({required this.groupId, required this.postId});

  final int groupId;
  final int postId;

  String get route => '/community/group/$groupId/post/$postId';
}

/// An Emerge Kentucky alum who is on the ballot.
///
/// Only public campaign information belongs here: name, office sought,
/// election, race status, public bio, and public campaign links. No
/// demographic or identity fields, and nothing about who supports them.
class AlumniCandidate {
  const AlumniCandidate({
    required this.id,
    required this.name,
    required this.office,
    this.electionName,
    this.electionDate,
    this.status = CandidateRaceStatus.running,
    this.bio,
    this.vanId,
    this.campaignUrl,
    this.donateUrl,
    this.volunteerUrl,
    this.infoUrl,
    this.headshotUrl,
    this.winPost,
  });

  /// Stable server identifier, used in routes.
  final String id;
  final String name;

  /// Office sought, e.g. "Kentucky State Senate, District 6".
  final String office;
  final String? electionName;
  final DateTime? electionDate;
  final CandidateRaceStatus status;

  /// Short public bio.
  final String? bio;

  /// Alumni Directory (VAN) identifier, when the candidate is linked.
  final int? vanId;

  final Uri? campaignUrl;
  final Uri? donateUrl;
  final Uri? volunteerUrl;

  /// Public candidate profile (e.g. Ballotpedia).
  final Uri? infoUrl;

  /// Headshot, only ever on the configured media origin.
  final Uri? headshotUrl;

  final CandidateWinPost? winPost;

  /// Parses a candidate from the API.
  ///
  /// [mediaOrigin] is the only origin headshots may load from; relative
  /// paths resolve against it and any other origin is dropped. Without a
  /// media origin (demo builds) headshots are ignored.
  factory AlumniCandidate.fromJson(
    Map<String, dynamic> json, {
    Uri? mediaOrigin,
  }) {
    final rawId = json['id'];
    final id = rawId?.toString().trim() ?? '';
    if (id.isEmpty) {
      throw const FormatException('Candidate is missing an id');
    }
    final name = _string(json['name']);
    if (name == null) {
      throw const FormatException('Candidate is missing a name');
    }

    final winPostJson = json['win_post'];
    CandidateWinPost? winPost;
    if (winPostJson is Map) {
      final groupId = _int(winPostJson['group_id']);
      final postId = _int(winPostJson['post_id']);
      if (groupId != null && postId != null) {
        winPost = CandidateWinPost(groupId: groupId, postId: postId);
      }
    }

    return AlumniCandidate(
      id: id,
      name: name,
      office: _string(json['office']) ?? '',
      electionName: _string(json['election_name']),
      electionDate: _date(json['election_date']),
      status: CandidateRaceStatus.parse(json['status']),
      bio: _string(json['bio']),
      vanId: _int(json['van_id']),
      campaignUrl: _webUrl(json['campaign_url']),
      donateUrl: _webUrl(json['donate_url']),
      volunteerUrl: _webUrl(json['volunteer_url']),
      infoUrl: _webUrl(json['info_url']),
      headshotUrl: _mediaUrl(json['headshot_url'], mediaOrigin),
      winPost: winPost,
    );
  }

  /// The link a card's primary action opens: campaign page, then profile.
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

  /// Whole days from [now] until election day, or `null` without a date.
  /// Negative once the election has passed.
  int? daysUntilElection(DateTime now) {
    final date = electionDate;
    if (date == null) return null;
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(date.year, date.month, date.day);
    return day.difference(today).inDays;
  }

  static String? _string(Object? value) {
    if (value is! String) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  static int? _int(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value.trim());
    return null;
  }

  static DateTime? _date(Object? value) {
    final text = _string(value);
    return text == null ? null : DateTime.tryParse(text);
  }

  /// Only absolute HTTPS links are opened from candidate cards.
  static Uri? _webUrl(Object? value) {
    final text = _string(value);
    if (text == null) return null;
    final uri = Uri.tryParse(text);
    if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) return null;
    return uri;
  }

  static Uri? _mediaUrl(Object? value, Uri? mediaOrigin) {
    final text = _string(value);
    if (text == null || mediaOrigin == null) return null;
    final parsed = Uri.tryParse(text);
    if (parsed == null) return null;
    final resolved = mediaOrigin.resolveUri(parsed);
    final sameOrigin =
        resolved.scheme == mediaOrigin.scheme &&
        resolved.host == mediaOrigin.host &&
        resolved.port == mediaOrigin.port;
    return sameOrigin ? resolved : null;
  }
}
