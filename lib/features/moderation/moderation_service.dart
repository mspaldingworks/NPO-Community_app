import 'package:npo_community/core/services/api_client.dart';

/// One page of a paginated moderation list.
class ModerationPage<T> {
  const ModerationPage({required this.count, required this.results});

  final int count;
  final List<T> results;
}

class ModerationUserRef {
  const ModerationUserRef({
    required this.id,
    required this.username,
    required this.displayName,
    this.moderationStatus,
  });

  final int id;
  final String username;
  final String displayName;
  final String? moderationStatus;

  static ModerationUserRef? fromJson(dynamic json) {
    if (json is! Map<String, dynamic>) return null;
    return ModerationUserRef(
      id: json['id'] as int,
      username: json['username'] as String? ?? '',
      displayName:
          json['display_name'] as String? ?? json['username'] as String? ?? '',
      moderationStatus: json['moderation_status'] as String?,
    );
  }
}

DateTime? _date(dynamic value) => value is String && value.isNotEmpty
    ? DateTime.tryParse(value)?.toLocal()
    : null;

class ModerationMember {
  const ModerationMember({
    required this.id,
    required this.username,
    required this.displayName,
    required this.roles,
    required this.moderationStatus,
    required this.isProtected,
    this.programYear,
    this.regionId,
    this.isMemorial = false,
    this.claimStatus,
    this.moderationReason = '',
    this.suspensionUntil,
    this.email,
  });

  final int id;
  final String username;
  final String displayName;
  final List<String> roles;
  final String moderationStatus;
  final bool isProtected;
  final int? programYear;
  final String? regionId;
  final bool isMemorial;
  final String? claimStatus;
  final String moderationReason;
  final DateTime? suspensionUntil;

  /// Only sent to superusers.
  final String? email;

  bool hasRole(String role) => roles.contains(role);

  factory ModerationMember.fromJson(Map<String, dynamic> json) =>
      ModerationMember(
        id: json['id'] as int,
        username: json['username'] as String? ?? '',
        displayName: json['display_name'] as String? ?? '',
        roles: (json['roles'] as List? ?? const []).cast<String>(),
        moderationStatus: json['moderation_status'] as String? ?? 'active',
        isProtected: json['is_protected'] == true,
        programYear: json['program_year'] as int?,
        regionId: json['region_id'] as String?,
        isMemorial: json['is_memorial'] == true,
        claimStatus: json['claim_status'] as String?,
        moderationReason: json['moderation_reason'] as String? ?? '',
        suspensionUntil: _date(json['suspension_until']),
        email: json['email'] as String?,
      );
}

class ModerationReport {
  const ModerationReport({
    required this.id,
    required this.targetType,
    required this.reason,
    required this.status,
    required this.createdAt,
    this.details = '',
    this.evidenceText,
    this.reporter,
    this.targetUser,
    this.memberAction = '',
    this.resolutionNotes = '',
    this.resolvedBy,
  });

  final int id;
  final String targetType;
  final String reason;
  final String status;
  final DateTime? createdAt;
  final String details;

  /// The server's snapshot of what was reported (title and/or text).
  final String? evidenceText;
  final ModerationUserRef? reporter;
  final ModerationUserRef? targetUser;
  final String memberAction;
  final String resolutionNotes;
  final ModerationUserRef? resolvedBy;

  bool get isActive => status == 'open' || status == 'reviewing';

  factory ModerationReport.fromJson(Map<String, dynamic> json) {
    final evidence = json['evidence'];
    String? text;
    if (evidence is Map) {
      text = [
        evidence['title'],
        evidence['text'],
      ].whereType<String>().where((part) => part.trim().isNotEmpty).join('\n');
      if (text.isEmpty) text = null;
    }
    return ModerationReport(
      id: json['id'] as int,
      targetType: json['target_type'] as String? ?? 'other',
      reason: json['reason'] as String? ?? '',
      status: json['status'] as String? ?? 'open',
      createdAt: _date(json['created_at']),
      details: json['details'] as String? ?? '',
      evidenceText: text,
      reporter: ModerationUserRef.fromJson(json['reporter']),
      targetUser: ModerationUserRef.fromJson(json['target_user']),
      memberAction: json['member_action'] as String? ?? '',
      resolutionNotes: json['resolution_notes'] as String? ?? '',
      resolvedBy: ModerationUserRef.fromJson(json['resolved_by']),
    );
  }
}

class AuditEntry {
  const AuditEntry({
    required this.id,
    required this.action,
    required this.outcome,
    required this.reason,
    this.createdAt,
    this.actor,
    this.target,
    this.notes = '',
  });

  final int id;
  final String action;
  final String outcome;
  final String reason;
  final DateTime? createdAt;
  final ModerationUserRef? actor;
  final ModerationUserRef? target;
  final String notes;

  factory AuditEntry.fromJson(Map<String, dynamic> json) => AuditEntry(
    id: json['id'] as int,
    action: json['action'] as String? ?? '',
    outcome: json['outcome'] as String? ?? '',
    reason: json['reason'] as String? ?? '',
    createdAt: _date(json['created_at']),
    actor: ModerationUserRef.fromJson(json['actor']),
    target: ModerationUserRef.fromJson(json['target']),
    notes: json['notes'] as String? ?? '',
  );
}

/// The moderation control panel API (`/api/moderation/`).
class ModerationService extends ApiClient {
  ModerationService();

  Future<ModerationPage<T>> _page<T>(
    String path,
    Map<String, String> query,
    T Function(Map<String, dynamic>) parse,
  ) async {
    final cleaned = {
      for (final entry in query.entries)
        if (entry.value.isNotEmpty) entry.key: entry.value,
    };
    final url = cleaned.isEmpty
        ? path
        : '$path?${Uri(queryParameters: cleaned).query}';
    final data = await read(urlPath: url, jsonHeaders: authHeaders) as Map;
    return ModerationPage(
      count: data['count'] as int? ?? 0,
      results: (data['results'] as List? ?? const [])
          .map((row) => parse(row as Map<String, dynamic>))
          .toList(),
    );
  }

  Future<ModerationPage<ModerationMember>> fetchMembers({
    String search = '',
    String status = '',
    int page = 1,
  }) => _page('/api/moderation/members/', {
    'search': search,
    'status': status,
    'page': '$page',
  }, ModerationMember.fromJson);

  /// [action] is warn, restrict, suspend, ban or lift.
  Future<void> memberAction(
    int memberId,
    String action, {
    required String reason,
    DateTime? suspensionUntil,
  }) async {
    await post(
      urlPath: '/api/moderation/members/$memberId/$action/',
      jsonHeaders: authHeaders,
      jsonPayload: {
        'reason': reason,
        if (suspensionUntil != null)
          'suspension_until': suspensionUntil.toUtc().toIso8601String(),
      },
    );
  }

  /// Superusers only: [role] is moderator or admin.
  Future<void> setRole(
    int memberId, {
    required String role,
    required bool grant,
    required String reason,
  }) async {
    await post(
      urlPath: '/api/moderation/members/$memberId/role/',
      jsonHeaders: authHeaders,
      jsonPayload: {'role': role, 'grant': grant, 'reason': reason},
    );
  }

  /// [status] is active (open + reviewing), all, or a single status.
  Future<ModerationPage<ModerationReport>> fetchReports({
    String status = 'active',
    int page = 1,
  }) => _page('/api/moderation/reports/', {
    'status': status,
    'page': '$page',
  }, ModerationReport.fromJson);

  /// [status] is reviewing, resolved, dismissed or open.
  Future<void> resolveReport(
    int reportId, {
    required String status,
    String notes = '',
  }) async {
    await post(
      urlPath: '/api/moderation/reports/$reportId/resolve/',
      jsonHeaders: authHeaders,
      jsonPayload: {'status': status, 'notes': notes},
    );
  }

  Future<void> escalateReport(
    int reportId, {
    required String action,
    required String reason,
    DateTime? suspensionUntil,
  }) async {
    await post(
      urlPath: '/api/moderation/reports/$reportId/escalate/',
      jsonHeaders: authHeaders,
      jsonPayload: {
        'action': action,
        'reason': reason,
        if (suspensionUntil != null)
          'suspension_until': suspensionUntil.toUtc().toIso8601String(),
      },
    );
  }

  Future<ModerationPage<AuditEntry>> fetchAudit({
    int? targetId,
    int page = 1,
  }) => _page('/api/moderation/audit-log/', {
    'target': targetId?.toString() ?? '',
    'page': '$page',
  }, AuditEntry.fromJson);
}
