import 'package:npo_community/core/services/api_client.dart';

/// One member of the newest class and what they have raised.
class ClassFundraiser {
  const ClassFundraiser({
    required this.id,
    required this.displayName,
    this.raisedCents = 0,
    this.donors = 0,
    this.url = '',
    this.joined = true,
    this.isMe = false,
  });

  final int id;
  final String displayName;
  final int raisedCents;
  final int donors;

  /// Their own Givebutter page; empty until Givebutter is connected.
  final String url;

  /// False for seeded alumnae who haven't claimed their profile yet.
  final bool joined;
  final bool isMe;

  factory ClassFundraiser.fromJson(Map<String, dynamic> json) =>
      ClassFundraiser(
        id: json['id'] as int,
        displayName: json['display_name'] as String? ?? '',
        raisedCents: json['raised_cents'] as int? ?? 0,
        donors: json['donors'] as int? ?? 0,
        url: json['url'] as String? ?? '',
        joined: json['joined'] as bool? ?? true,
        isMe: json['is_me'] as bool? ?? false,
      );
}

/// The newest class's fundraising: each member toward [goalCents].
class ClassFundraising {
  const ClassFundraising({
    required this.year,
    required this.goalCents,
    this.mode = 'preview',
    this.available = true,
    this.totalRaisedCents = 0,
    this.totalGoalCents = 0,
    this.members = const [],
  });

  final int year;

  /// Each member's goal (the end of their bar).
  final int goalCents;

  /// 'live' (from Givebutter) or 'preview' (sample amounts).
  final String mode;

  /// False when Givebutter could not be reached.
  final bool available;
  final int totalRaisedCents;
  final int totalGoalCents;

  /// The viewer first if they are in the class, then by name.
  final List<ClassFundraiser> members;

  bool get isPreview => mode != 'live';

  ClassFundraiser? get me {
    for (final member in members) {
      if (member.isMe) return member;
    }
    return null;
  }

  factory ClassFundraising.fromJson(Map<String, dynamic> json) =>
      ClassFundraising(
        year: json['year'] as int? ?? DateTime.now().year,
        goalCents: json['goal_cents'] as int? ?? 100000,
        mode: json['mode'] as String? ?? 'preview',
        available: json['available'] as bool? ?? true,
        totalRaisedCents: json['total_raised_cents'] as int? ?? 0,
        totalGoalCents: json['total_goal_cents'] as int? ?? 0,
        members: [
          for (final row in (json['members'] as List? ?? const []))
            ClassFundraiser.fromJson(row as Map<String, dynamic>),
        ],
      );
}

/// /api/class-fundraising/ (the API's class_fundraising.py).
class ClassFundraisingService extends ApiClient {
  ClassFundraisingService();

  Future<ClassFundraising> fetch() async => ClassFundraising.fromJson(
    await read(urlPath: '/api/class-fundraising/', jsonHeaders: authHeaders)
        as Map<String, dynamic>,
  );
}
