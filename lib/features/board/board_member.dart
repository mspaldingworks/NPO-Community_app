/// A governance record for someone serving on the board.
class BoardMember {
  final int id;
  final String username;
  final String displayName;
  final String position;
  final List<String> committees;
  final String? term;
  final DateTime? termStartDate;
  final String? bio;

  const BoardMember({
    required this.id,
    required this.username,
    required this.displayName,
    required this.position,
    this.committees = const [],
    this.term,
    this.termStartDate,
    this.bio,
  });

  /// Human labels for the API's position keys.
  static const Map<String, String> positionLabels = {
    'president': 'President',
    'vice_president': 'Vice President',
    'treasurer': 'Treasurer',
    'secretary': 'Secretary',
    'board_member': 'Board Member',
  };

  static const Map<String, String> committeeLabels = {
    'executive': 'Executive',
    'nominating': 'Nominating',
    'development': 'Development',
    'human_resources': 'Human Resources',
    'program': 'Program',
    'dei': 'Diversity, Equity, and Inclusion',
    'finance': 'Finance',
  };

  /// Officers first, then plain members — the order a board roster is read in.
  static const List<String> positionOrder = [
    'president',
    'vice_president',
    'treasurer',
    'secretary',
    'board_member',
  ];

  String get positionLabel => positionLabels[position] ?? position;

  String get name =>
      displayName.trim().isNotEmpty ? displayName.trim() : username;

  List<String> get committeeLabelList =>
      committees.map((c) => committeeLabels[c] ?? c).toList();

  int get positionRank {
    final index = positionOrder.indexOf(position);
    return index == -1 ? positionOrder.length : index;
  }

  factory BoardMember.fromJson(Map<String, dynamic> json) {
    final rawCommittees = json['committees'];
    return BoardMember(
      id: json['id'] as int,
      username: json['username'] as String? ?? '',
      displayName: json['display_name'] as String? ?? '',
      position: json['board_position'] as String? ?? 'board_member',
      committees: rawCommittees is List
          ? rawCommittees.map((c) => '$c').toList()
          : const [],
      term: json['term'] as String?,
      termStartDate: json['term_start_date'] is String
          ? DateTime.tryParse(json['term_start_date'] as String)
          : null,
      bio: json['bio'] as String?,
    );
  }
}
