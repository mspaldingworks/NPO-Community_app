import 'package:npo_community/core/services/api_client.dart';
import 'package:npo_community/features/fundraisers/fundraisers_service.dart';

DateTime? _date(dynamic value) => value is String && value.isNotEmpty
    ? DateTime.tryParse(value)?.toLocal()
    : null;

double _num(dynamic value) => (value as num? ?? 0).toDouble();

/// "$412.50", "7 sessions", "3.5 hours".
String formatAmount(double value, String unit) {
  if (unit == 'dollars') return formatDollars((value * 100).round());
  final text = value == value.roundToDouble()
      ? value.toInt().toString()
      : value.toStringAsFixed(1);
  return unit.isEmpty ? text : '$text $unit';
}

/// Something a class member completes to graduate.
class GradRequirement {
  const GradRequirement({
    required this.id,
    required this.name,
    this.description = '',
    this.source = 'manual',
    this.sourceLabel = '',
    this.target = 1,
    this.unit = '',
    this.isActive = true,
  });

  final int id;
  final String name;
  final String description;

  /// class_fundraising, class_sessions, volunteer_hours, events_attended or
  /// manual.
  final String source;
  final String sourceLabel;
  final double target;
  final String unit;
  final bool isActive;

  bool get isManual => source == 'manual';

  factory GradRequirement.fromJson(Map<String, dynamic> json) =>
      GradRequirement(
        id: json['id'] as int,
        name: json['name'] as String? ?? '',
        description: json['description'] as String? ?? '',
        source: json['source'] as String? ?? 'manual',
        sourceLabel: json['source_label'] as String? ?? '',
        target: _num(json['target']),
        unit: json['unit'] as String? ?? '',
        isActive: json['is_active'] as bool? ?? true,
      );
}

/// One member's standing on one requirement.
class GradStatus {
  const GradStatus({
    required this.requirementId,
    this.automatic = 0,
    this.adjustment = 0,
    this.value = 0,
    this.target = 1,
    this.waived = false,
    this.met = false,
    this.note = '',
    this.updatedBy,
    this.updatedAt,
  });

  final int requirementId;

  /// Counted by the app (check-ins, shifts, Givebutter).
  final double automatic;

  /// Staff's +/- on top of the automatic count.
  final double adjustment;

  /// automatic + adjustment, never below zero.
  final double value;
  final double target;
  final bool waived;
  final bool met;

  // Member detail only.
  final String note;
  final String? updatedBy;
  final DateTime? updatedAt;

  double get fraction => target <= 0 ? 0 : (value / target).clamp(0.0, 1.0);

  factory GradStatus.fromJson(Map<String, dynamic> json) => GradStatus(
    requirementId: json['requirement_id'] as int,
    automatic: _num(json['automatic']),
    adjustment: _num(json['adjustment']),
    value: _num(json['value']),
    target: _num(json['target']),
    waived: json['waived'] as bool? ?? false,
    met: json['met'] as bool? ?? false,
    note: json['note'] as String? ?? '',
    updatedBy:
        (json['updated_by'] as Map<String, dynamic>?)?['display_name']
            as String?,
    updatedAt: _date(json['updated_at']),
  );
}

class GradMember {
  const GradMember({
    required this.id,
    required this.displayName,
    this.joined = true,
    this.met = 0,
    this.total = 0,
    this.complete = false,
    this.requirements = const [],
  });

  final int id;
  final String displayName;

  /// False for seeded alumnae who haven't claimed their profile yet.
  final bool joined;
  final int met;
  final int total;
  final bool complete;

  /// In the same order as the overview's requirements.
  final List<GradStatus> requirements;

  factory GradMember.fromJson(Map<String, dynamic> json) => GradMember(
    id: json['id'] as int,
    displayName: json['display_name'] as String? ?? '',
    joined: json['joined'] as bool? ?? true,
    met: json['met'] as int? ?? 0,
    total: json['total'] as int? ?? 0,
    complete: json['complete'] as bool? ?? false,
    requirements: [
      for (final row in (json['requirements'] as List? ?? const []))
        GradStatus.fromJson(row as Map<String, dynamic>),
    ],
  );
}

/// A class against every active requirement.
class GraduationOverview {
  const GraduationOverview({
    required this.year,
    this.years = const [],
    this.requirements = const [],
    this.members = const [],
    this.complete = 0,
    this.metByRequirement = const {},
    this.fundraisingSample = false,
    this.fundraisingAvailable = true,
  });

  final int year;

  /// Every class year, newest first.
  final List<int> years;
  final List<GradRequirement> requirements;
  final List<GradMember> members;
  final int complete;
  final Map<int, int> metByRequirement;

  /// Fundraising figures are samples until Givebutter is connected.
  final bool fundraisingSample;
  final bool fundraisingAvailable;

  factory GraduationOverview.fromJson(Map<String, dynamic> json) {
    final summary = json['summary'] as Map<String, dynamic>? ?? const {};
    return GraduationOverview(
      year: json['year'] as int,
      years: [for (final y in (json['years'] as List? ?? const [])) y as int],
      requirements: [
        for (final row in (json['requirements'] as List? ?? const []))
          GradRequirement.fromJson(row as Map<String, dynamic>),
      ],
      members: [
        for (final row in (json['members'] as List? ?? const []))
          GradMember.fromJson(row as Map<String, dynamic>),
      ],
      complete: summary['complete'] as int? ?? 0,
      metByRequirement: {
        for (final entry
            in (summary['met_by_requirement'] as Map<String, dynamic>? ??
                    const {})
                .entries)
          int.parse(entry.key): entry.value as int? ?? 0,
      },
      fundraisingSample: json['fundraising_sample'] as bool? ?? false,
      fundraisingAvailable: json['fundraising_available'] as bool? ?? true,
    );
  }
}

class GradHistoryEntry {
  const GradHistoryEntry({required this.notes, this.at, this.by});

  final String notes;
  final DateTime? at;
  final String? by;

  factory GradHistoryEntry.fromJson(Map<String, dynamic> json) =>
      GradHistoryEntry(
        notes: json['notes'] as String? ?? '',
        at: _date(json['at']),
        by: (json['by'] as Map<String, dynamic>?)?['display_name'] as String?,
      );
}

/// One member's progress, staff notes and edit history.
class GradMemberDetail {
  const GradMemberDetail({
    required this.member,
    required this.programYear,
    this.requirements = const [],
    this.history = const [],
    this.fundraisingSample = false,
  });

  final GradMember member;
  final int programYear;

  /// The requirements, in the order of [member]'s statuses.
  final List<GradRequirement> requirements;
  final List<GradHistoryEntry> history;
  final bool fundraisingSample;

  factory GradMemberDetail.fromJson(Map<String, dynamic> json) =>
      GradMemberDetail(
        member: GradMember.fromJson(json),
        programYear: json['program_year'] as int? ?? 0,
        requirements: [
          for (final row in (json['requirements_info'] as List? ?? const []))
            GradRequirement.fromJson(row as Map<String, dynamic>),
        ],
        history: [
          for (final row in (json['history'] as List? ?? const []))
            GradHistoryEntry.fromJson(row as Map<String, dynamic>),
        ],
        fundraisingSample: json['fundraising_sample'] as bool? ?? false,
      );
}

/// /api/graduation/ (the API's graduation.py): staff and administrators.
class GraduationService extends ApiClient {
  GraduationService();

  Future<GraduationOverview> fetchOverview({int? year}) async =>
      GraduationOverview.fromJson(
        await read(
              urlPath: year == null
                  ? '/api/graduation/'
                  : '/api/graduation/?year=$year',
              jsonHeaders: authHeaders,
            )
            as Map<String, dynamic>,
      );

  Future<GradMemberDetail> fetchMember(int memberId) async =>
      GradMemberDetail.fromJson(
        await read(
              urlPath: '/api/graduation/members/$memberId/',
              jsonHeaders: authHeaders,
            )
            as Map<String, dynamic>,
      );

  /// Sets the adjustment and/or waiver; [note] (why) is required.
  Future<GradMemberDetail> editProgress(
    int memberId,
    int requirementId, {
    double? adjustment,
    bool? waived,
    required String note,
  }) async => GradMemberDetail.fromJson(
    await update(
          urlPath:
              '/api/graduation/members/$memberId/requirements/$requirementId/',
          jsonHeaders: authHeaders,
          jsonPayload: {
            'adjustment': ?adjustment,
            'waived': ?waived,
            'note': note,
          },
        )
        as Map<String, dynamic>,
  );

  /// Every requirement (retired ones too) and the sources to choose from.
  Future<(List<GradRequirement>, Map<String, String>)>
  fetchRequirements() async {
    final data =
        await read(
              urlPath: '/api/graduation/requirements/',
              jsonHeaders: authHeaders,
            )
            as Map<String, dynamic>;
    return (
      [
        for (final row in (data['requirements'] as List? ?? const []))
          GradRequirement.fromJson(row as Map<String, dynamic>),
      ],
      {
        for (final row in (data['sources'] as List? ?? const []))
          (row as Map<String, dynamic>)['key'] as String:
              row['label'] as String? ?? '',
      },
    );
  }

  Future<GradRequirement> createRequirement(
    Map<String, dynamic> fields,
  ) async => GradRequirement.fromJson(
    await post(
          urlPath: '/api/graduation/requirements/',
          jsonHeaders: authHeaders,
          jsonPayload: fields,
          expectedStatusCode: 201,
        )
        as Map<String, dynamic>,
  );

  Future<GradRequirement> updateRequirement(
    int id,
    Map<String, dynamic> fields,
  ) async => GradRequirement.fromJson(
    await update(
          urlPath: '/api/graduation/requirements/$id/',
          jsonHeaders: authHeaders,
          jsonPayload: fields,
        )
        as Map<String, dynamic>,
  );
}
