import 'package:flutter/foundation.dart';
import 'package:npo_community/core/services/api_client.dart';
import 'package:npo_community/features/alumni_directory/alumni_directory_service.dart';
import 'package:npo_community/features/alumni_directory/models/alumni_profile.dart';

enum AlumniDirectoryStatus { idle, loading, loaded, error }

class AlumniDirectoryController extends ChangeNotifier {
  AlumniDirectoryController({AlumniDirectoryService? service})
    : _service = service ?? AlumniDirectoryService();

  final AlumniDirectoryService _service;

  List<AlumniProfile> _alumni = const [];
  AlumniDirectoryStatus _status = AlumniDirectoryStatus.idle;
  String? _error;
  String _search = '';
  int? _cohortYear;
  bool _isOffline = false;

  List<AlumniProfile> get alumni => List.unmodifiable(_alumni);
  AlumniDirectoryStatus get status => _status;
  String? get error => _error;
  String get search => _search;
  int? get cohortYear => _cohortYear;

  /// True when the current list came from the offline cache rather than the
  /// server (the screen labels it so nobody mistakes it for live data).
  bool get isOffline => _isOffline;

  /// Cohort years present in the currently loaded results, newest first.
  List<int> get availableCohorts {
    final years = _alumni
        .map((a) => a.cohortYear)
        .whereType<int>()
        .toSet()
        .toList();
    years.sort((a, b) => b.compareTo(a));
    return years;
  }

  Future<void> load() async {
    if (_status == AlumniDirectoryStatus.loading) return;
    _status = AlumniDirectoryStatus.loading;
    _error = null;
    notifyListeners();

    try {
      _alumni = await _service.fetchAlumni(
        search: _search.isEmpty ? null : _search,
        cohortYear: _cohortYear,
      );
      _isOffline = false;
      _status = AlumniDirectoryStatus.loaded;
    } on ApiClientException catch (e) {
      await _fallBackToCache(e.message);
    } catch (_) {
      await _fallBackToCache(
        'Unable to load the alumni directory. Please try again.',
      );
    }
    notifyListeners();
  }

  /// On a failed fetch, serve the last saved directory (filtered locally)
  /// instead of an error screen — board members are often on the road.
  Future<void> _fallBackToCache(String message) async {
    final cached = await _service.loadCached();
    if (cached == null || cached.isEmpty) {
      _error = message;
      _status = AlumniDirectoryStatus.error;
      return;
    }

    final query = _search.toLowerCase();
    _alumni = cached.where((profile) {
      if (_cohortYear != null && profile.cohortYear != _cohortYear) {
        return false;
      }
      if (query.isEmpty) return true;
      return profile.fullName.toLowerCase().contains(query);
    }).toList();
    _isOffline = true;
    _status = AlumniDirectoryStatus.loaded;
  }

  Future<void> setSearch(String value) async {
    final trimmed = value.trim();
    if (trimmed == _search) return;
    _search = trimmed;
    await load();
  }

  Future<void> setCohortYear(int? year) async {
    if (year == _cohortYear) return;
    _cohortYear = year;
    await load();
  }
}
