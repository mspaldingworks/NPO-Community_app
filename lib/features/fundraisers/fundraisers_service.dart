import 'package:npo_community/core/services/api_client.dart';

DateTime? _date(dynamic value) => value is String && value.isNotEmpty
    ? DateTime.tryParse(value)?.toLocal()
    : null;

/// A fundraiser template from the API (fundraiser_templates.py).
class FundraiserTemplate {
  const FundraiserTemplate({
    required this.key,
    required this.name,
    required this.tagline,
    required this.icon,
    required this.campaignType,
    required this.needsDate,
    required this.defaultGoalCents,
    required this.durationHours,
    required this.title,
    required this.description,
    this.ticketPriceCents,
  });

  final String key;
  final String name;
  final String tagline;

  /// Material icon name (home, local_bar, live_tv, cake, school, …).
  final String icon;

  /// Givebutter campaign type: event or fundraise.
  final String campaignType;
  final bool needsDate;
  final int defaultGoalCents;
  final int? ticketPriceCents;
  final int durationHours;

  /// Copy with {host} and {year} placeholders.
  final String title;
  final String description;

  factory FundraiserTemplate.fromJson(Map<String, dynamic> json) =>
      FundraiserTemplate(
        key: json['key'] as String,
        name: json['name'] as String? ?? '',
        tagline: json['tagline'] as String? ?? '',
        icon: json['icon'] as String? ?? 'volunteer_activism',
        campaignType: json['campaign_type'] as String? ?? 'fundraise',
        needsDate: json['needs_date'] == true,
        defaultGoalCents: json['default_goal_cents'] as int? ?? 25000,
        ticketPriceCents: json['ticket_price_cents'] as int?,
        durationHours: json['duration_hours'] as int? ?? 0,
        title: json['title'] as String? ?? '',
        description: json['description'] as String? ?? '',
      );

  String renderTitle({required String host, int? year}) => title
      .replaceAll('{host}', host)
      .replaceAll('{year}', year?.toString() ?? 'your');
}

/// The template catalog plus how the server is wired up.
class FundraiserCatalog {
  const FundraiserCatalog({
    required this.mode,
    required this.reviewRequired,
    required this.minGoalCents,
    required this.maxGoalCents,
    required this.notDeductible,
    required this.templates,
  });

  /// 'preview' until Emerge's Givebutter API key is configured; 'live' after.
  final String mode;
  final bool reviewRequired;
  final int minGoalCents;
  final int maxGoalCents;
  final String notDeductible;
  final List<FundraiserTemplate> templates;

  bool get isPreview => mode != 'live';

  factory FundraiserCatalog.fromJson(Map<String, dynamic> json) =>
      FundraiserCatalog(
        mode: json['mode'] as String? ?? 'preview',
        reviewRequired: json['review_required'] != false,
        minGoalCents: json['min_goal_cents'] as int? ?? 2500,
        maxGoalCents: json['max_goal_cents'] as int? ?? 10000000,
        notDeductible: json['not_deductible'] as String? ?? '',
        templates: [
          for (final row in (json['templates'] as List? ?? const []))
            FundraiserTemplate.fromJson(row as Map<String, dynamic>),
        ],
      );
}

class FundraiserHost {
  const FundraiserHost({required this.id, required this.displayName});

  final int id;
  final String displayName;
}

/// An alumna-hosted fundraiser, mirrored to a Givebutter campaign.
class Fundraiser {
  const Fundraiser({
    required this.id,
    required this.templateKey,
    required this.templateName,
    required this.templateIcon,
    required this.title,
    required this.status,
    required this.goalCents,
    this.message = '',
    this.raisedCents = 0,
    this.donorCount = 0,
    this.percent = 0,
    this.ticketPriceCents,
    this.startsAt,
    this.endsAt,
    this.locationName = '',
    this.isVirtual = false,
    this.virtualLink = '',
    this.isDemo = false,
    this.host,
    this.eventId,
    this.givebutterMode = 'preview',
    this.givebutterCampaignId = '',
    this.givebutterSlug = '',
    this.givebutterUrl = '',
    this.canManage = false,
    this.canReview = false,
    this.reviewNote = '',
    this.createdAt,
  });

  final int id;
  final String templateKey;
  final String templateName;
  final String templateIcon;
  final String title;
  final String message;

  /// pending_review, live, closed or rejected.
  final String status;
  final int goalCents;
  final int raisedCents;
  final int donorCount;
  final int percent;
  final int? ticketPriceCents;
  final DateTime? startsAt;
  final DateTime? endsAt;
  final String locationName;
  final bool isVirtual;
  final String virtualLink;
  final bool isDemo;
  final FundraiserHost? host;
  final int? eventId;
  final String givebutterMode;
  final String givebutterCampaignId;
  final String givebutterSlug;
  final String givebutterUrl;
  final bool canManage;
  final bool canReview;
  final String reviewNote;
  final DateTime? createdAt;

  bool get isPending => status == 'pending_review';
  bool get isLive => status == 'live';
  bool get isOpen => isPending || isLive;
  bool get hasPage => givebutterUrl.isNotEmpty;

  String get statusLabel => switch (status) {
    'pending_review' => 'Waiting for review',
    'live' => givebutterMode == 'live' ? 'Live' : 'Live (preview)',
    'closed' => 'Closed',
    'rejected' => 'Not approved',
    _ => status,
  };

  factory Fundraiser.fromJson(Map<String, dynamic> json) {
    final template = json['template'] as Map? ?? const {};
    final host = json['host'] as Map?;
    final gb = json['givebutter'] as Map? ?? const {};
    return Fundraiser(
      id: json['id'] as int,
      templateKey: json['template_key'] as String? ?? '',
      templateName: template['name'] as String? ?? '',
      templateIcon: template['icon'] as String? ?? 'volunteer_activism',
      title: json['title'] as String? ?? '',
      message: json['message'] as String? ?? '',
      status: json['status'] as String? ?? 'pending_review',
      goalCents: json['goal_cents'] as int? ?? 0,
      raisedCents: json['raised_cents'] as int? ?? 0,
      donorCount: json['donor_count'] as int? ?? 0,
      percent: json['percent'] as int? ?? 0,
      ticketPriceCents: json['ticket_price_cents'] as int?,
      startsAt: _date(json['starts_at']),
      endsAt: _date(json['ends_at']),
      locationName: json['location_name'] as String? ?? '',
      isVirtual: json['is_virtual'] == true,
      virtualLink: json['virtual_link'] as String? ?? '',
      isDemo: json['is_demo'] == true,
      host: host == null
          ? null
          : FundraiserHost(
              id: host['id'] as int,
              displayName: host['display_name'] as String? ?? '',
            ),
      eventId: json['event_id'] as int?,
      givebutterMode: gb['mode'] as String? ?? 'preview',
      givebutterCampaignId: gb['campaign_id'] as String? ?? '',
      givebutterSlug: gb['slug'] as String? ?? '',
      givebutterUrl: gb['url'] as String? ?? '',
      canManage: json['can_manage'] == true,
      canReview: json['can_review'] == true,
      reviewNote: json['review_note'] as String? ?? '',
      createdAt: _date(json['created_at']),
    );
  }
}

/// The summary of a fundraiser attached to an event (serialize_event).
class EventFundraiser {
  const EventFundraiser({
    required this.id,
    required this.status,
    required this.goalCents,
    required this.raisedCents,
    required this.donorCount,
    required this.url,
    required this.mode,
  });

  final int id;
  final String status;
  final int goalCents;
  final int raisedCents;
  final int donorCount;
  final String url;
  final String mode;

  bool get isLive => status == 'live';
  bool get isPreview => mode != 'live';

  factory EventFundraiser.fromJson(Map<String, dynamic> json) =>
      EventFundraiser(
        id: json['id'] as int,
        status: json['status'] as String? ?? 'live',
        goalCents: json['goal_cents'] as int? ?? 0,
        raisedCents: json['raised_cents'] as int? ?? 0,
        donorCount: json['donor_count'] as int? ?? 0,
        url: json['url'] as String? ?? '',
        mode: json['mode'] as String? ?? 'preview',
      );
}

/// What the start-a-fundraiser form collects.
class FundraiserDraft {
  const FundraiserDraft({
    required this.templateKey,
    required this.title,
    required this.goalCents,
    this.message = '',
    this.startsAt,
    this.endsAt,
    this.locationName = '',
    this.virtualLink = '',
  });

  final String templateKey;
  final String title;
  final int goalCents;
  final String message;
  final DateTime? startsAt;
  final DateTime? endsAt;
  final String locationName;
  final String virtualLink;

  Map<String, dynamic> toJson() => {
    'template_key': templateKey,
    'title': title,
    'goal_cents': goalCents,
    'message': message,
    'starts_at': startsAt?.toUtc().toIso8601String(),
    'ends_at': endsAt?.toUtc().toIso8601String(),
    'location_name': locationName,
    'is_virtual': virtualLink.isNotEmpty,
    'virtual_link': virtualLink,
  };
}

/// Dollars for display: $1,250 or $12.50.
String formatDollars(int cents) {
  final dollars = cents ~/ 100;
  final rest = cents % 100;
  final buffer = StringBuffer();
  final text = dollars.toString();
  for (var i = 0; i < text.length; i++) {
    if (i > 0 && (text.length - i) % 3 == 0) buffer.write(',');
    buffer.write(text[i]);
  }
  return rest == 0
      ? '\$$buffer'
      : '\$$buffer.${rest.toString().padLeft(2, '0')}';
}

/// `/api/fundraisers/` — alumnae-hosted Givebutter fundraisers.
class FundraisersService extends ApiClient {
  FundraisersService();

  Fundraiser _one(dynamic data) =>
      Fundraiser.fromJson(data as Map<String, dynamic>);

  List<Fundraiser> _many(dynamic data) => [
    for (final row in (data as List)) _one(row),
  ];

  Future<FundraiserCatalog> fetchCatalog() async => FundraiserCatalog.fromJson(
    await read(urlPath: '/api/fundraisers/templates/', jsonHeaders: authHeaders)
        as Map<String, dynamic>,
  );

  Future<List<Fundraiser>> fetchMine() async => _many(
    await read(
      urlPath: '/api/fundraisers/?scope=mine',
      jsonHeaders: authHeaders,
    ),
  );

  /// Every fundraiser, for the control console (moderators and admins).
  Future<List<Fundraiser>> fetchAll({String status = ''}) async => _many(
    await read(
      urlPath:
          '/api/fundraisers/?scope=all${status.isEmpty ? '' : '&status=$status'}',
      jsonHeaders: authHeaders,
    ),
  );

  Future<List<Fundraiser>> fetchPending() async => _many(
    await read(
      urlPath: '/api/fundraisers/?scope=pending',
      jsonHeaders: authHeaders,
    ),
  );

  Future<Fundraiser> fetchOne(int id) async => _one(
    await read(urlPath: '/api/fundraisers/$id/', jsonHeaders: authHeaders),
  );

  Future<Fundraiser> create(FundraiserDraft draft) async => _one(
    await post(
      urlPath: '/api/fundraisers/',
      jsonHeaders: authHeaders,
      jsonPayload: draft.toJson(),
      expectedStatusCode: 201,
    ),
  );

  Future<Fundraiser> edit(int id, Map<String, dynamic> fields) async => _one(
    await update(
      urlPath: '/api/fundraisers/$id/',
      jsonHeaders: authHeaders,
      jsonPayload: fields,
    ),
  );

  Future<Fundraiser> _action(int id, String action, {String note = ''}) async =>
      _one(
        await post(
          urlPath: '/api/fundraisers/$id/$action/',
          jsonHeaders: authHeaders,
          jsonPayload: {'note': note},
        ),
      );

  Future<Fundraiser> approve(int id, {String note = ''}) =>
      _action(id, 'approve', note: note);

  Future<Fundraiser> reject(int id, {String note = ''}) =>
      _action(id, 'reject', note: note);

  Future<Fundraiser> close(int id) => _action(id, 'close');

  Future<Fundraiser> sync(int id) => _action(id, 'sync');
}
