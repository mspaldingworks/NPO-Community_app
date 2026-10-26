import 'package:npo_community/core/services/api_client.dart';

DateTime? _date(dynamic value) => value is String && value.isNotEmpty
    ? DateTime.tryParse(value)?.toLocal()
    : null;

/// A member as the People tab shows them.
class Person {
  const Person({
    required this.id,
    required this.displayName,
    this.username = '',
    this.email = '',
    this.programYear,
    this.isActive = true,
    this.roles = const [],
    this.canChange = false,
  });

  final int id;
  final String displayName;
  final String username;
  final String email;
  final int? programYear;

  /// False for seeded alumnae who haven't claimed their profile.
  final bool isActive;
  final List<String> roles;

  /// Whether I may change their roles (they rank below me).
  final bool canChange;

  factory Person.fromJson(Map<String, dynamic> json) => Person(
    id: json['id'] as int,
    displayName: json['display_name'] as String? ?? '',
    username: json['username'] as String? ?? '',
    email: json['email'] as String? ?? '',
    programYear: json['program_year'] as int?,
    isActive: json['is_active'] as bool? ?? true,
    roles: [for (final r in (json['roles'] as List? ?? const [])) r as String],
    canChange: json['can_change'] as bool? ?? false,
  );
}

/// A role I may give or remove.
class RoleOption {
  const RoleOption({required this.key, required this.label});

  final String key;
  final String label;

  factory RoleOption.fromJson(Map<String, dynamic> json) => RoleOption(
    key: json['key'] as String,
    label: json['label'] as String? ?? json['key'] as String,
  );
}

/// An invitation to join.
class Invite {
  const Invite({
    required this.id,
    required this.code,
    required this.link,
    required this.status,
    this.name = '',
    this.email = '',
    this.programYear,
    this.roles = const [],
    this.createdBy,
    this.expiresAt,
    this.usedBy,
  });

  final int id;

  /// XXXX-XXXX, entered at signup.
  final String code;

  /// The page to share: the code and how to join.
  final String link;

  /// open, used, expired or revoked.
  final String status;
  final String name;
  final String email;
  final int? programYear;
  final List<String> roles;
  final String? createdBy;
  final DateTime? expiresAt;

  /// Who joined with it.
  final String? usedBy;

  bool get isOpen => status == 'open';

  factory Invite.fromJson(Map<String, dynamic> json) => Invite(
    id: json['id'] as int,
    code: json['code'] as String? ?? '',
    link: json['link'] as String? ?? '',
    status: json['status'] as String? ?? 'open',
    name: json['name'] as String? ?? '',
    email: json['email'] as String? ?? '',
    programYear: json['program_year'] as int?,
    roles: [for (final r in (json['roles'] as List? ?? const [])) r as String],
    createdBy: json['created_by'] as String?,
    expiresAt: _date(json['expires_at']),
    usedBy:
        (json['used_by'] as Map<String, dynamic>?)?['display_name'] as String?,
  );
}

/// /api/people/ (the API's member_admin.py): staff and administrators.
class PeopleService extends ApiClient {
  PeopleService();

  Future<List<Person>> search(String query) async {
    final data = await read(
      urlPath: '/api/people/?q=${Uri.encodeQueryComponent(query)}',
      jsonHeaders: authHeaders,
    );
    return [
      for (final row in (data as List))
        Person.fromJson(row as Map<String, dynamic>),
    ];
  }

  Future<List<RoleOption>> fetchRoleOptions() async {
    final data = await read(
      urlPath: '/api/people/roles/',
      jsonHeaders: authHeaders,
    );
    return [
      for (final row in (data as List))
        RoleOption.fromJson(row as Map<String, dynamic>),
    ];
  }

  Future<Person> setRole(
    int personId,
    String role, {
    required bool grant,
    required String reason,
  }) async => Person.fromJson(
    await post(
          urlPath: '/api/people/$personId/roles/',
          jsonHeaders: authHeaders,
          jsonPayload: {'role': role, 'grant': grant, 'reason': reason},
        )
        as Map<String, dynamic>,
  );

  Future<List<Invite>> fetchInvites() async {
    final data = await read(
      urlPath: '/api/people/invites/',
      jsonHeaders: authHeaders,
    );
    return [
      for (final row in (data as List))
        Invite.fromJson(row as Map<String, dynamic>),
    ];
  }

  Future<Invite> createInvite({
    String name = '',
    String email = '',
    int? programYear,
    List<String> roles = const [],
    String note = '',
  }) async => Invite.fromJson(
    await post(
          urlPath: '/api/people/invites/',
          jsonHeaders: authHeaders,
          jsonPayload: {
            'name': name,
            'email': email,
            'program_year': programYear,
            'roles': roles,
            'note': note,
          },
          expectedStatusCode: 201,
        )
        as Map<String, dynamic>,
  );

  Future<Invite> revokeInvite(int id) async => Invite.fromJson(
    await post(
          urlPath: '/api/people/invites/$id/revoke/',
          jsonHeaders: authHeaders,
          jsonPayload: const {},
        )
        as Map<String, dynamic>,
  );
}
