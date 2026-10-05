import 'package:npo_community/core/services/api_client.dart';
import 'package:npo_community/features/events/events_service.dart';

DateTime? _date(dynamic value) => value is String && value.isNotEmpty
    ? DateTime.tryParse(value)?.toLocal()
    : null;

String _name(dynamic ref) => ref is Map
    ? (ref['display_name'] as String? ?? ref['username'] as String? ?? '')
    : '';

class GroupAdmin {
  const GroupAdmin({required this.id, required this.name});

  final int id;
  final String name;
}

class GroupConsoleOverview {
  const GroupConsoleOverview({
    required this.groupName,
    required this.canManage,
    required this.canAppoint,
    required this.welcomeMessage,
    required this.rules,
    required this.isLocked,
    required this.admins,
  });

  final String groupName;

  /// Moderators and this group's admins.
  final bool canManage;

  /// Moderators only: appoint or remove group admins.
  final bool canAppoint;
  final String welcomeMessage;
  final String rules;
  final bool isLocked;
  final List<GroupAdmin> admins;

  factory GroupConsoleOverview.fromJson(Map<String, dynamic> json) {
    final settings = json['settings'] as Map? ?? const {};
    return GroupConsoleOverview(
      groupName: (json['group'] as Map?)?['name'] as String? ?? '',
      canManage: json['can_manage'] == true,
      canAppoint: json['can_appoint'] == true,
      welcomeMessage: settings['welcome_message'] as String? ?? '',
      rules: settings['rules'] as String? ?? '',
      isLocked: settings['is_locked'] == true,
      admins: [
        for (final row in (json['admins'] as List? ?? const []))
          GroupAdmin(id: (row as Map)['id'] as int, name: _name(row)),
      ],
    );
  }
}

class GroupAnnouncement {
  const GroupAnnouncement({
    required this.id,
    required this.title,
    required this.body,
    required this.isPinned,
    this.author = '',
    this.createdAt,
  });

  final int id;
  final String title;
  final String body;
  final bool isPinned;
  final String author;
  final DateTime? createdAt;

  factory GroupAnnouncement.fromJson(Map<String, dynamic> json) =>
      GroupAnnouncement(
        id: json['id'] as int,
        title: json['title'] as String? ?? '',
        body: json['body'] as String? ?? '',
        isPinned: json['is_pinned'] == true,
        author: _name(json['created_by']),
        createdAt: _date(json['created_at']),
      );
}

class PollOption {
  const PollOption({
    required this.id,
    required this.text,
    required this.votes,
    this.voters,
  });

  final int id;
  final String text;
  final int votes;

  /// Names, only for polls that aren't anonymous.
  final List<String>? voters;
}

class GroupPoll {
  const GroupPoll({
    required this.id,
    required this.question,
    required this.options,
    required this.allowMultiple,
    required this.isAnonymous,
    required this.isOpen,
    required this.totalVoters,
    required this.myVotes,
    this.closesAt,
  });

  final int id;
  final String question;
  final List<PollOption> options;
  final bool allowMultiple;
  final bool isAnonymous;
  final bool isOpen;
  final int totalVoters;
  final List<int> myVotes;
  final DateTime? closesAt;

  factory GroupPoll.fromJson(Map<String, dynamic> json) => GroupPoll(
    id: json['id'] as int,
    question: json['question'] as String? ?? '',
    allowMultiple: json['allow_multiple'] == true,
    isAnonymous: json['is_anonymous'] != false,
    isOpen: json['is_open'] == true,
    totalVoters: json['total_voters'] as int? ?? 0,
    myVotes: (json['my_votes'] as List? ?? const []).cast<int>(),
    closesAt: _date(json['closes_at']),
    options: [
      for (final row in (json['options'] as List? ?? const []))
        PollOption(
          id: (row as Map)['id'] as int,
          text: row['text'] as String? ?? '',
          votes: row['votes'] as int? ?? 0,
          voters: (row['voters'] as List?)?.cast<String>(),
        ),
    ],
  );
}

/// `/api/groups/<id>/` console endpoints.
class GroupConsoleService extends ApiClient {
  GroupConsoleService(this.groupId);

  final int groupId;

  String get _base => '/api/groups/$groupId';

  Future<List<Map<String, dynamic>>> _list(String path) async {
    final data = await read(urlPath: '$_base/$path', jsonHeaders: authHeaders);
    return (data as List).cast<Map<String, dynamic>>();
  }

  Future<GroupConsoleOverview> fetchOverview() async =>
      GroupConsoleOverview.fromJson(
        await read(urlPath: '$_base/console/', jsonHeaders: authHeaders)
            as Map<String, dynamic>,
      );

  Future<void> saveSettings({
    String? welcomeMessage,
    String? rules,
    bool? isLocked,
  }) async {
    await update(
      urlPath: '$_base/console/settings/',
      jsonHeaders: authHeaders,
      jsonPayload: {
        if (welcomeMessage != null) 'welcome_message': welcomeMessage,
        if (rules != null) 'rules': rules,
        if (isLocked != null) 'is_locked': isLocked,
      },
    );
  }

  Future<void> setAdmin(int accountId, {required bool appoint}) async {
    await post(
      urlPath: '$_base/admins/',
      jsonHeaders: authHeaders,
      jsonPayload: {'account_id': accountId, 'appoint': appoint},
    );
  }

  Future<List<GroupAnnouncement>> fetchAnnouncements() async => [
    for (final row in await _list('announcements/'))
      GroupAnnouncement.fromJson(row),
  ];

  Future<void> postAnnouncement({
    required String title,
    String body = '',
    bool isPinned = false,
  }) async {
    await post(
      urlPath: '$_base/announcements/',
      jsonHeaders: authHeaders,
      jsonPayload: {'title': title, 'body': body, 'is_pinned': isPinned},
      expectedStatusCode: 201,
    );
  }

  Future<void> deleteAnnouncement(int id) async {
    await delete(
      urlPath: '$_base/announcements/$id/',
      jsonHeaders: authHeaders,
    );
  }

  /// The group's upcoming events, in the same shape as `/api/events/`.
  Future<List<CommunityEvent>> fetchEvents() async => [
    for (final row in await _list('events/')) CommunityEvent.fromJson(row),
  ];

  Future<void> postEvent(EventDraft draft) async {
    await post(
      urlPath: '$_base/events/',
      jsonHeaders: authHeaders,
      jsonPayload: draft.toJson(),
      expectedStatusCode: 201,
    );
  }

  Future<void> cancelEvent(int id) async {
    await update(
      urlPath: '$_base/events/$id/',
      jsonHeaders: authHeaders,
      jsonPayload: {'is_cancelled': true},
    );
  }

  Future<List<GroupPoll>> fetchPolls() async => [
    for (final row in await _list('polls/')) GroupPoll.fromJson(row),
  ];

  Future<void> createPoll({
    required String question,
    required List<String> options,
    bool allowMultiple = false,
    bool isAnonymous = true,
  }) async {
    await post(
      urlPath: '$_base/polls/',
      jsonHeaders: authHeaders,
      jsonPayload: {
        'question': question,
        'options': options,
        'allow_multiple': allowMultiple,
        'is_anonymous': isAnonymous,
      },
      expectedStatusCode: 201,
    );
  }

  Future<void> vote(int pollId, List<int> optionIds) async {
    await post(
      urlPath: '$_base/polls/$pollId/vote/',
      jsonHeaders: authHeaders,
      jsonPayload: {'option_ids': optionIds},
    );
  }

  Future<void> closePoll(int pollId) async {
    await post(
      urlPath: '$_base/polls/$pollId/close/',
      jsonHeaders: authHeaders,
      jsonPayload: const {},
    );
  }
}
