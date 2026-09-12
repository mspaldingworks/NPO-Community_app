class GivebutterCampaign {
  const GivebutterCampaign({
    required this.id,
    required this.code,
    required this.type,
    required this.title,
    required this.slug,
    required this.url,
    required this.raised,
    required this.donors,
    required this.currency,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.subtitle,
    this.description,
    this.goal,
    this.cover,
    this.timezone,
    this.endAt,
  });

  final String id;
  final String code;
  final String type;
  final String title;
  final String? subtitle;
  final String? description;
  final String slug;
  final String url;
  final int? goal;
  final double raised;
  final int donors;
  final String currency;
  final String? cover;
  final String status;
  final String? timezone;
  final String? endAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  double get goalProgress {
    if (goal == null || goal == 0) return 0;
    return (raised / goal!).clamp(0.0, 1.0);
  }

  String get raisedLabel {
    final symbol = currency.toUpperCase() == 'USD' ? r'$' : currency;
    return '$symbol${raised.toStringAsFixed(0)}';
  }

  String get goalLabel {
    if (goal == null) return 'No goal set';
    final symbol = currency.toUpperCase() == 'USD' ? r'$' : currency;
    return '$symbol$goal';
  }

  factory GivebutterCampaign.fromJson(Map<String, dynamic> json) {
    return GivebutterCampaign(
      id: json['id']?.toString() ?? '',
      code: json['code'] as String? ?? '',
      type: json['type'] as String? ?? 'fundraiser',
      title: json['title'] as String? ?? '',
      subtitle: json['subtitle'] as String?,
      description: json['description'] as String?,
      slug: json['slug'] as String? ?? '',
      url: json['url'] as String? ?? '',
      goal: json['goal'] as int?,
      raised: (json['raised'] as num?)?.toDouble() ?? 0.0,
      donors: json['donors'] as int? ?? 0,
      currency: json['currency'] as String? ?? 'USD',
      cover: json['cover'] as String?,
      status: json['status'] as String? ?? 'active',
      timezone: json['timezone'] as String?,
      endAt: json['end_at'] as String?,
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ??
          DateTime.now(),
      updatedAt: DateTime.tryParse(json['updated_at'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}
