import 'package:npo_community/core/services/api_client.dart';
import 'package:npo_community/features/fundraisers/fundraisers_service.dart';

DateTime? _date(dynamic value) => value is String && value.isNotEmpty
    ? DateTime.tryParse(value)?.toLocal()
    : null;

/// A volunteer role at an event with a number of slots.
class VolunteerShift {
  const VolunteerShift({
    required this.id,
    required this.roleName,
    required this.startsAt,
    required this.endsAt,
    required this.slots,
    required this.claimed,
    required this.openSlots,
    required this.myClaim,
    this.description = '',
    this.eventId,
    this.eventTitle,
  });

  final int id;
  final String roleName;
  final String description;
  final DateTime startsAt;
  final DateTime endsAt;
  final int slots;
  final int claimed;
  final int openSlots;
  final bool myClaim;

  /// Set on shifts listed under "Mine".
  final int? eventId;
  final String? eventTitle;

  bool get isFull => openSlots <= 0;

  factory VolunteerShift.fromJson(Map<String, dynamic> json) {
    final event = json['event'];
    return VolunteerShift(
      id: json['id'] as int,
      roleName: json['role_name'] as String? ?? '',
      description: json['description'] as String? ?? '',
      startsAt: _date(json['starts_at']) ?? DateTime.now(),
      endsAt: _date(json['ends_at']) ?? DateTime.now(),
      slots: json['slots'] as int? ?? 1,
      claimed: json['claimed'] as int? ?? 0,
      openSlots: json['open_slots'] as int? ?? 0,
      myClaim: json['my_claim'] == true,
      eventId: event is Map ? event['id'] as int? : null,
      eventTitle: event is Map ? event['title'] as String? : null,
    );
  }
}

class EventGroupRef {
  const EventGroupRef({required this.id, required this.name, this.kind = ''});

  final int id;
  final String name;
  final String kind;
}

/// An Emerge KY event: statewide (no group) or for one group.
class CommunityEvent {
  const CommunityEvent({
    required this.id,
    required this.title,
    required this.startsAt,
    this.description = '',
    this.endsAt,
    this.locationName = '',
    this.isVirtual = false,
    this.virtualLink = '',
    this.isCancelled = false,
    this.capacity,
    this.isDemo = false,
    this.group,
    this.goingCount = 0,
    this.maybeCount = 0,
    this.myRsvp,
    this.canManage = false,
    this.shifts = const [],
    this.openVolunteerSlots = 0,
    this.myShiftCount = 0,
    this.fundraiser,
  });

  final int id;
  final String title;
  final String description;
  final DateTime startsAt;
  final DateTime? endsAt;
  final String locationName;
  final bool isVirtual;
  final String virtualLink;
  final bool isCancelled;
  final int? capacity;

  /// Sample data from `seed_demo_events`; shown as such to moderators.
  final bool isDemo;
  final EventGroupRef? group;
  final int goingCount;
  final int maybeCount;

  /// going, maybe, declined or null.
  final String? myRsvp;
  final bool canManage;
  final List<VolunteerShift> shifts;
  final int openVolunteerSlots;
  final int myShiftCount;

  /// Set when this event is an alumna-hosted fundraiser.
  final EventFundraiser? fundraiser;

  bool get isStatewide => group == null;
  String get scopeLabel => group?.name ?? 'Statewide';
  bool get isFull => capacity != null && goingCount >= capacity!;

  factory CommunityEvent.fromJson(Map<String, dynamic> json) {
    final group = json['group'];
    return CommunityEvent(
      id: json['id'] as int,
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      startsAt: _date(json['starts_at']) ?? DateTime.now(),
      endsAt: _date(json['ends_at']),
      locationName: json['location_name'] as String? ?? '',
      isVirtual: json['is_virtual'] == true,
      virtualLink: json['virtual_link'] as String? ?? '',
      isCancelled: json['is_cancelled'] == true,
      capacity: json['capacity'] as int?,
      isDemo: json['is_demo'] == true,
      group: group is Map
          ? EventGroupRef(
              id: group['id'] as int,
              name: group['name'] as String? ?? '',
              kind: group['kind'] as String? ?? '',
            )
          : null,
      goingCount: json['going_count'] as int? ?? 0,
      maybeCount: json['maybe_count'] as int? ?? 0,
      myRsvp: json['my_rsvp'] as String?,
      canManage: json['can_manage'] == true,
      shifts: [
        for (final row in (json['shifts'] as List? ?? const []))
          VolunteerShift.fromJson(row as Map<String, dynamic>),
      ],
      openVolunteerSlots: json['open_volunteer_slots'] as int? ?? 0,
      myShiftCount: json['my_shift_count'] as int? ?? 0,
      fundraiser: json['fundraiser'] is Map
          ? EventFundraiser.fromJson(json['fundraiser'] as Map<String, dynamic>)
          : null,
    );
  }
}

class RosterRow {
  const RosterRow({
    required this.id,
    required this.username,
    required this.displayName,
    required this.status,
    required this.attended,
    this.shifts = const [],
  });

  final int id;
  final String username;
  final String displayName;
  final String status;
  final bool attended;
  final List<String> shifts;

  factory RosterRow.fromJson(Map<String, dynamic> json) => RosterRow(
    id: json['id'] as int,
    username: json['username'] as String? ?? '',
    displayName:
        json['display_name'] as String? ?? json['username'] as String? ?? '',
    status: json['status'] as String? ?? 'going',
    attended: json['attended'] == true,
    shifts: (json['shifts'] as List? ?? const []).cast<String>(),
  );
}

class MyCommitments {
  const MyCommitments({
    this.events = const [],
    this.shifts = const [],
    this.attendedCount = 0,
    this.volunteerHours = 0,
  });

  final List<CommunityEvent> events;
  final List<VolunteerShift> shifts;
  final int attendedCount;
  final double volunteerHours;

  factory MyCommitments.fromJson(Map<String, dynamic> json) => MyCommitments(
    events: [
      for (final row in (json['events'] as List? ?? const []))
        CommunityEvent.fromJson(row as Map<String, dynamic>),
    ],
    shifts: [
      for (final row in (json['shifts'] as List? ?? const []))
        VolunteerShift.fromJson(row as Map<String, dynamic>),
    ],
    attendedCount: json['attended_count'] as int? ?? 0,
    volunteerHours: (json['volunteer_hours'] as num? ?? 0).toDouble(),
  );
}

/// What the event form collects.
class EventDraft {
  const EventDraft({
    required this.title,
    required this.startsAt,
    this.endsAt,
    this.description = '',
    this.locationName = '',
    this.virtualLink = '',
    this.capacity,
  });

  final String title;
  final DateTime startsAt;
  final DateTime? endsAt;
  final String description;
  final String locationName;
  final String virtualLink;
  final int? capacity;

  Map<String, dynamic> toJson() => {
    'title': title,
    'starts_at': startsAt.toUtc().toIso8601String(),
    'ends_at': endsAt?.toUtc().toIso8601String(),
    'description': description,
    'location_name': locationName,
    'is_virtual': virtualLink.isNotEmpty,
    'virtual_link': virtualLink,
    'capacity': capacity,
  };
}

/// `/api/events/` — events, RSVPs and volunteer shifts.
class EventsService extends ApiClient {
  EventsService();

  CommunityEvent _event(dynamic data) =>
      CommunityEvent.fromJson(data as Map<String, dynamic>);

  Future<List<CommunityEvent>> fetchEvents({String when = 'upcoming'}) async {
    final data = await read(
      urlPath: '/api/events/?when=$when',
      jsonHeaders: authHeaders,
    );
    return [for (final row in (data as List)) _event(row)];
  }

  Future<CommunityEvent> fetchEvent(int id) async =>
      _event(await read(urlPath: '/api/events/$id/', jsonHeaders: authHeaders));

  Future<CommunityEvent> createEvent(EventDraft draft, {int? groupId}) async =>
      _event(
        await post(
          urlPath: '/api/events/',
          jsonHeaders: authHeaders,
          jsonPayload: {
            ...draft.toJson(),
            if (groupId != null) 'group_id': groupId,
          },
          expectedStatusCode: 201,
        ),
      );

  Future<CommunityEvent> updateEvent(
    int id,
    Map<String, dynamic> fields,
  ) async => _event(
    await update(
      urlPath: '/api/events/$id/',
      jsonHeaders: authHeaders,
      jsonPayload: fields,
    ),
  );

  Future<CommunityEvent> rsvp(int id, String status) async => _event(
    await post(
      urlPath: '/api/events/$id/rsvp/',
      jsonHeaders: authHeaders,
      jsonPayload: {'status': status},
    ),
  );

  Future<CommunityEvent> addShift(
    int id, {
    required String roleName,
    required DateTime startsAt,
    required DateTime endsAt,
    int slots = 1,
    String description = '',
  }) async => _event(
    await post(
      urlPath: '/api/events/$id/shifts/',
      jsonHeaders: authHeaders,
      jsonPayload: {
        'role_name': roleName,
        'starts_at': startsAt.toUtc().toIso8601String(),
        'ends_at': endsAt.toUtc().toIso8601String(),
        'slots': slots,
        'description': description,
      },
      expectedStatusCode: 201,
    ),
  );

  Future<CommunityEvent> claimShift(int id, int shiftId) async => _event(
    await post(
      urlPath: '/api/events/$id/shifts/$shiftId/claim/',
      jsonHeaders: authHeaders,
      jsonPayload: const {},
    ),
  );

  Future<CommunityEvent> releaseShift(int id, int shiftId) async => _event(
    await post(
      urlPath: '/api/events/$id/shifts/$shiftId/release/',
      jsonHeaders: authHeaders,
      jsonPayload: const {},
    ),
  );

  Future<List<RosterRow>> fetchRoster(int id) async {
    final data = await read(
      urlPath: '/api/events/$id/roster/',
      jsonHeaders: authHeaders,
    );
    return [
      for (final row in (data as List))
        RosterRow.fromJson(row as Map<String, dynamic>),
    ];
  }

  Future<List<RosterRow>> checkIn(
    int id,
    int accountId, {
    bool attended = true,
  }) async {
    final data = await post(
      urlPath: '/api/events/$id/check-in/',
      jsonHeaders: authHeaders,
      jsonPayload: {'account_id': accountId, 'attended': attended},
    );
    return [
      for (final row in (data as List))
        RosterRow.fromJson(row as Map<String, dynamic>),
    ];
  }

  Future<MyCommitments> fetchMine() async => MyCommitments.fromJson(
    await read(urlPath: '/api/events/mine/', jsonHeaders: authHeaders)
        as Map<String, dynamic>,
  );
}
