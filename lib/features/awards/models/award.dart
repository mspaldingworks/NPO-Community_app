import 'package:flutter/material.dart';
import 'package:npo_community/theme/app_theme.dart';

DateTime? _date(dynamic value) => value is String && value.isNotEmpty
    ? DateTime.tryParse(value)?.toLocal()
    : null;

/// Icon keys the server allows (awards.ICONS in the API), drawn here.
const Map<String, IconData> awardIcons = {
  'star': Icons.star_outline,
  'trophy': Icons.emoji_events_outlined,
  'medal': Icons.military_tech_outlined,
  'ribbon': Icons.workspace_premium_outlined,
  'heart': Icons.favorite_outline,
  'handshake': Icons.handshake_outlined,
  'campaign': Icons.campaign_outlined,
  'ballot': Icons.how_to_vote_outlined,
  'volunteer': Icons.volunteer_activism_outlined,
  'school': Icons.school_outlined,
  'groups': Icons.groups_outlined,
  'diversity': Icons.diversity_3_outlined,
  'celebration': Icons.celebration_outlined,
  'event': Icons.event_available_outlined,
  'forum': Icons.forum_outlined,
  'savings': Icons.savings_outlined,
  'rocket': Icons.rocket_launch_outlined,
  'flag': Icons.flag_outlined,
  'lightbulb': Icons.lightbulb_outline,
};

IconData iconForAward(String key) => awardIcons[key] ?? Icons.star_outline;

/// The brand colors administrators pick award colors from.
const List<Color> awardColors = [
  AppColors.primary,
  AppColors.green,
  AppColors.periwinkle,
  AppColors.navy,
  AppColors.orange,
  AppColors.crimson,
];

Color colorFromHex(String hex) {
  final value = int.tryParse(hex.replaceFirst('#', ''), radix: 16);
  return value == null ? AppColors.primary : Color(0xFF000000 | value);
}

String hexFromColor(Color color) =>
    '#${(color.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';

/// How far a member is toward an automatic award.
class AwardProgress {
  const AwardProgress({required this.value, required this.target});

  final int value;
  final int target;

  double get fraction => target <= 0 ? 0 : (value / target).clamp(0, 1);

  factory AwardProgress.fromJson(Map<String, dynamic> json) => AwardProgress(
    value: json['value'] as int? ?? 0,
    target: json['target'] as int? ?? 0,
  );
}

/// One award in the catalog administrators design.
class Award {
  const Award({
    required this.id,
    required this.key,
    required this.name,
    this.description = '',
    this.icon = 'star',
    this.color = '#197278',
    this.category = 'special',
    this.categoryLabel = 'Special recognition',
    this.automatic = false,
    this.threshold,
    this.ruleLabel,
    this.unit,
    this.earned = 0,
    this.progress,
    this.rule = '',
    this.isActive = true,
    this.holders = 0,
  });

  final int id;
  final String key;
  final String name;
  final String description;
  final String icon;

  /// '#RRGGBB'.
  final String color;
  final String category;
  final String categoryLabel;

  /// Earned on reaching [threshold] on a rule, rather than given by hand.
  final bool automatic;
  final int? threshold;
  final String? ruleLabel;
  final String? unit;

  /// How many times the viewer holds it (hand-given awards can repeat).
  final int earned;

  /// The viewer's progress toward an automatic award not yet earned.
  final AwardProgress? progress;

  // Administrators only.
  final String rule;
  final bool isActive;
  final int holders;

  IconData get iconData => iconForAward(icon);
  Color get colorValue => colorFromHex(color);

  /// "5 events" for an automatic award, null for a hand-given one.
  String? get goal =>
      automatic && threshold != null ? '$threshold ${unit ?? ''}'.trim() : null;

  factory Award.fromJson(Map<String, dynamic> json) => Award(
    id: json['id'] as int,
    key: json['key'] as String? ?? '',
    name: json['name'] as String? ?? '',
    description: json['description'] as String? ?? '',
    icon: json['icon'] as String? ?? 'star',
    color: json['color'] as String? ?? '#197278',
    category: json['category'] as String? ?? 'special',
    categoryLabel: json['category_label'] as String? ?? '',
    automatic: json['automatic'] as bool? ?? false,
    threshold: json['threshold'] as int?,
    ruleLabel: json['rule_label'] as String?,
    unit: json['unit'] as String?,
    earned: json['earned'] as int? ?? 0,
    progress: json['progress'] is Map<String, dynamic>
        ? AwardProgress.fromJson(json['progress'] as Map<String, dynamic>)
        : null,
    rule: json['rule'] as String? ?? '',
    isActive: json['is_active'] as bool? ?? true,
    holders: json['holders'] as int? ?? 0,
  );
}

/// A member someone can give an award to.
class AwardMember {
  const AwardMember({
    required this.id,
    required this.displayName,
    this.username = '',
    this.programYear,
    this.isActive = true,
  });

  final int id;
  final String displayName;
  final String username;
  final int? programYear;

  /// False for seeded alumnae who haven't claimed their profile yet.
  final bool isActive;

  factory AwardMember.fromJson(Map<String, dynamic> json) => AwardMember(
    id: json['id'] as int,
    displayName:
        json['display_name'] as String? ?? json['username'] as String? ?? '',
    username: json['username'] as String? ?? '',
    programYear: json['program_year'] as int?,
    isActive: json['is_active'] as bool? ?? true,
  );
}

/// An award a member holds.
class AwardGrant {
  const AwardGrant({
    required this.id,
    required this.award,
    this.citation = '',
    this.automatic = false,
    this.grantedAt,
    this.grantedBy,
    this.account,
  });

  final int id;
  final Award award;

  /// Why it was given ("For 40 hours of phone banking"), hand-given only.
  final String citation;
  final bool automatic;
  final DateTime? grantedAt;

  /// Display name of the administrator who gave it.
  final String? grantedBy;

  /// Who holds it (administrators' holder lists only).
  final AwardMember? account;

  factory AwardGrant.fromJson(Map<String, dynamic> json) => AwardGrant(
    id: json['id'] as int,
    award: Award.fromJson(json['award'] as Map<String, dynamic>),
    citation: json['citation'] as String? ?? '',
    automatic: json['automatic'] as bool? ?? false,
    grantedAt: _date(json['granted_at']),
    grantedBy:
        (json['granted_by'] as Map<String, dynamic>?)?['display_name']
            as String?,
    account: json['account'] is Map<String, dynamic>
        ? AwardMember.fromJson(json['account'] as Map<String, dynamic>)
        : null,
  );

  static List<AwardGrant> listFromJson(dynamic rows) => [
    for (final row in (rows as List? ?? const []))
      AwardGrant.fromJson(row as Map<String, dynamic>),
  ];
}

/// The catalog as the viewer sees it, plus the awards they hold.
class AwardCatalog {
  const AwardCatalog({this.awards = const [], this.mine = const []});

  final List<Award> awards;
  final List<AwardGrant> mine;

  factory AwardCatalog.fromJson(Map<String, dynamic> json) => AwardCatalog(
    awards: [
      for (final row in (json['awards'] as List? ?? const []))
        Award.fromJson(row as Map<String, dynamic>),
    ],
    mine: AwardGrant.listFromJson(json['mine']),
  );
}

/// A rule an automatic award can count.
class AwardRule {
  const AwardRule({
    required this.key,
    required this.label,
    this.unit = '',
    this.description = '',
  });

  final String key;
  final String label;
  final String unit;
  final String description;

  factory AwardRule.fromJson(Map<String, dynamic> json) => AwardRule(
    key: json['key'] as String,
    label: json['label'] as String? ?? '',
    unit: json['unit'] as String? ?? '',
    description: json['description'] as String? ?? '',
  );
}

/// What administrators choose from when designing an award.
class AwardOptions {
  const AwardOptions({
    this.rules = const [],
    this.icons = const [],
    this.categories = const {},
    this.currentClassYear,
  });

  final List<AwardRule> rules;
  final List<String> icons;

  /// key → label, in the server's order.
  final Map<String, String> categories;
  final int? currentClassYear;

  factory AwardOptions.fromJson(Map<String, dynamic> json) => AwardOptions(
    rules: [
      for (final row in (json['rules'] as List? ?? const []))
        AwardRule.fromJson(row as Map<String, dynamic>),
    ],
    icons: [
      for (final key in (json['icons'] as List? ?? const [])) key as String,
    ],
    categories: {
      for (final row in (json['categories'] as List? ?? const []))
        (row as Map<String, dynamic>)['key'] as String:
            row['label'] as String? ?? '',
    },
    currentClassYear: json['current_class_year'] as int?,
  );
}

/// Ways a member can say they are helping an alumna's campaign.
enum SupportKind {
  cheering('cheering', 'Cheering on', Icons.campaign_outlined),
  volunteered('volunteered', 'Volunteered', Icons.volunteer_activism_outlined),
  donated('donated', 'Donated', Icons.favorite_outline);

  const SupportKind(this.key, this.label, this.icon);

  final String key;
  final String label;
  final IconData icon;
}

/// Support for one alumna on the ballot: totals, and what the viewer marked.
class CandidateSupport {
  const CandidateSupport({
    required this.seedId,
    this.counts = const {},
    this.supporters = 0,
    this.mine = const {},
  });

  final String seedId;
  final Map<String, int> counts;

  /// Distinct members backing this candidate in any way.
  final int supporters;
  final Set<String> mine;

  bool marked(SupportKind kind) => mine.contains(kind.key);

  factory CandidateSupport.fromJson(Map<String, dynamic> json) =>
      CandidateSupport(
        seedId: json['seed_id'] as String? ?? '',
        counts: {
          for (final entry
              in (json['counts'] as Map<String, dynamic>? ?? const {}).entries)
            entry.key: entry.value as int? ?? 0,
        },
        supporters: json['supporters'] as int? ?? 0,
        mine: {
          for (final kind in (json['mine'] as List? ?? const []))
            kind as String,
        },
      );
}
