import 'package:npo_community/core/services/api_client.dart';

/// Everything `/api/admin/overview/` sums up, kept as sections of plain
/// values so new numbers on the server show up without a model change.
class AdminOverview {
  const AdminOverview(this.raw);

  final Map<String, dynamic> raw;

  Map<String, dynamic> section(String key) {
    final value = raw[key];
    return value is Map ? value.cast<String, dynamic>() : const {};
  }

  Map<String, dynamic> subsection(String key, String sub) {
    final value = section(key)[sub];
    return value is Map ? value.cast<String, dynamic>() : const {};
  }

  int count(String key, String field) =>
      (section(key)[field] as num?)?.toInt() ?? 0;

  double number(String key, String field) =>
      (section(key)[field] as num?)?.toDouble() ?? 0;

  String text(String key, String field) =>
      section(key)[field]?.toString() ?? '';

  List<Map<String, dynamic>> list(String key, String field) {
    final value = section(key)[field];
    if (value is! List) return const [];
    return [
      for (final row in value)
        if (row is Map) row.cast<String, dynamic>(),
    ];
  }

  DateTime? get generatedAt {
    final value = raw['generated_at'];
    return value is String ? DateTime.tryParse(value)?.toLocal() : null;
  }

  factory AdminOverview.fromJson(Map<String, dynamic> json) =>
      AdminOverview(json);
}

/// `/api/admin/` — the administrators' control console.
class AdminConsoleService extends ApiClient {
  AdminConsoleService();

  Future<AdminOverview> fetchOverview() async => AdminOverview.fromJson(
    await read(urlPath: '/api/admin/overview/', jsonHeaders: authHeaders)
        as Map<String, dynamic>,
  );
}
