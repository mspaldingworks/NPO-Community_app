import 'package:npo_community/core/services/api_client.dart';

/// Program cohort metadata.
class ProgramService extends ApiClient {
  static final ProgramService _instance = ProgramService._internal();
  factory ProgramService() => _instance;
  ProgramService._internal();

  /// The first year the program ran. Used only as a fallback when the API is
  /// unreachable — the server is the source of truth.
  static const int fallbackStartYear = 2010;

  List<int>? _cached;

  /// Selectable program years, newest first.
  ///
  /// Served by the API so the list rolls over each January without a new
  /// build. Falls back to a locally computed range if the call fails, so the
  /// signup form stays usable offline.
  Future<List<int>> fetchProgramYears() async {
    final cached = _cached;
    if (cached != null) {
      return cached;
    }

    try {
      final data = await read(
        urlPath: '/api/program-years/',
        jsonHeaders: const {'Content-Type': 'application/json'},
      );
      if (data is Map && data['years'] is List) {
        final years = (data['years'] as List)
            .map((y) => y is int ? y : int.tryParse('$y'))
            .whereType<int>()
            .toList();
        if (years.isNotEmpty) {
          _cached = years;
          return years;
        }
      }
    } catch (_) {
      // Fall through to the locally computed range.
    }

    return _localRange();
  }

  static List<int> _localRange() {
    final now = DateTime.now().year;
    return [for (var y = now; y >= fallbackStartYear; y--) y];
  }
}
