import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:npo_community/core/services/api_client.dart';
import 'package:npo_community/features/alumni_running/campaign_capabilities.dart';
import 'package:npo_community/features/alumni_running/campaign_repository.dart';
import 'package:npo_community/features/alumni_running/models/alumni_candidate.dart';
import 'package:npo_community/features/alumni_running/models/campaign_shift.dart';
import 'package:npo_community/features/alumni_running/models/candidate_draft.dart';

enum CampaignHubStatus { idle, loading, loaded, error }

/// A user-facing failure from a hub action.
class CampaignHubError implements Exception {
  const CampaignHubError(this.message);

  final String message;

  @override
  String toString() => message;
}

/// State for the Campaign Support Hub.
///
/// Channel memberships and shift sign-ups are political-opinion data. They
/// live only in this in-memory cache, are cleared whenever the session
/// changes, and are never persisted, logged, or sent to analytics.
class CampaignHubController extends ChangeNotifier {
  CampaignHubController({
    required CampaignRepository repository,
    bool Function()? isPreviewActive,
    Listenable? previewChanges,
    Stream<Object?>? sessionChanges,
  }) : _repository = repository,
       _isPreviewActive = isPreviewActive ?? _never,
       _previewChanges = previewChanges {
    _previewChanges?.addListener(_onPreviewChanged);
    _sessionSub = sessionChanges?.listen((_) => clearSession());
  }

  static bool _never() => false;

  final CampaignRepository _repository;
  final bool Function() _isPreviewActive;
  final Listenable? _previewChanges;
  StreamSubscription<Object?>? _sessionSub;

  CampaignRepository get repository => _repository;

  CampaignHubStatus _status = CampaignHubStatus.idle;
  String? _error;
  List<AlumniCandidate> _candidates = const [];
  final Map<String, String> _channelByCandidate = {};
  final Map<String, List<CampaignShift>> _shiftsByCandidate = {};
  final Set<String> _loadingShifts = {};
  final Map<String, String> _shiftErrors = {};
  final Set<String> _busy = {};
  List<CampaignShift> _myShifts = const [];
  bool _managementGranted = false;

  CampaignHubStatus get status => _status;
  String? get error => _error;
  List<AlumniCandidate> get candidates => List.unmodifiable(_candidates);

  /// Candidates whose race status is a win, for the Wins feed.
  List<AlumniCandidate> get wins =>
      _candidates.where((c) => c.status.isWin).toList(growable: false);

  CampaignCapabilities get capabilities {
    if (!_repository.supportsWrites) return CampaignCapabilities.readOnlyDemo;
    if (_isPreviewActive()) return CampaignCapabilities.readOnlyPreview;
    return _managementGranted
        ? const CampaignCapabilities(
            writesEnabled: true,
            managementGranted: true,
          )
        : CampaignCapabilities.full;
  }

  AlumniCandidate? candidateById(String id) {
    for (final c in _candidates) {
      if (c.id == id) return c;
    }
    return null;
  }

  bool isJoined(String candidateId) =>
      _channelByCandidate.containsKey(candidateId);

  String? channelIdFor(String candidateId) => _channelByCandidate[candidateId];

  List<AlumniCandidate> get joinedCandidates => _candidates
      .where((c) => _channelByCandidate.containsKey(c.id))
      .toList(growable: false);

  /// Whether a join/leave or sign-up for [key] is in flight.
  bool isBusy(String key) => _busy.contains(key);

  List<CampaignShift>? shiftsFor(String candidateId) =>
      _shiftsByCandidate[candidateId];
  bool isLoadingShifts(String candidateId) =>
      _loadingShifts.contains(candidateId);
  String? shiftErrorFor(String candidateId) => _shiftErrors[candidateId];

  /// Shifts the user has signed up for, for the Events calendar.
  List<CampaignShift> get myShifts => List.unmodifiable(_myShifts);

  Future<void>? _inFlight;

  /// Loads once per session; concurrent callers share the same load.
  Future<void> ensureLoaded() {
    if (_status == CampaignHubStatus.idle) return load();
    return _inFlight ?? Future<void>.value();
  }

  Future<void> load() {
    return _inFlight ??= _load().whenComplete(() => _inFlight = null);
  }

  /// Bumped on every session change so results from an earlier session
  /// are discarded.
  int _generation = 0;

  Future<void> _load() async {
    final generation = _generation;
    _status = CampaignHubStatus.loading;
    _error = null;
    notifyListeners();
    try {
      final candidates = await _repository.fetchCandidates();
      final channels = await _repository.fetchMyChannels();
      final myShifts = await _repository.fetchMyShifts();
      final canManage = await _fetchCanManage();
      if (generation != _generation) return;
      _managementGranted = canManage;
      _candidates = candidates;
      _channelByCandidate
        ..clear()
        ..addEntries(channels.map((m) => MapEntry(m.candidateId, m.channelId)));
      _myShifts = myShifts.where((s) => s.signedUp).toList();
      _status = CampaignHubStatus.loaded;
    } on ApiClientException catch (e) {
      if (generation != _generation) return;
      _error = e.message;
      _status = CampaignHubStatus.error;
    } catch (_) {
      if (generation != _generation) return;
      _error = 'Unable to load alumni candidates. Please try again.';
      _status = CampaignHubStatus.error;
    }
    notifyListeners();
  }

  /// Management is fail-closed: any error means no management controls.
  Future<bool> _fetchCanManage() async {
    try {
      return await _repository.fetchCanManageCandidates();
    } catch (_) {
      return false;
    }
  }

  /// Creates a candidate, or updates [id] when given. Returns the saved
  /// candidate's id, or throws a user-facing message as [CampaignHubError].
  Future<String> saveCandidate(CandidateDraft draft, {String? id}) async {
    if (!capabilities.canManageCandidates) {
      throw CampaignHubError(
        capabilities.reason ??
            "You don't have permission to manage candidates.",
      );
    }
    const key = 'candidate:save';
    if (_busy.contains(key)) throw const CampaignHubError('Already saving.');
    _busy.add(key);
    notifyListeners();
    try {
      final saved = id == null
          ? await _repository.createCandidate(draft)
          : await _repository.updateCandidate(id, draft);
      _candidates = [
        for (final c in _candidates)
          if (c.id != saved.id) c,
        saved,
      ];
      if (id != null && id != saved.id) {
        _candidates = [
          for (final c in _candidates)
            if (c.id != id) c,
        ];
      }
      return saved.id;
    } catch (e) {
      if (_isForbidden(e)) _managementGranted = false;
      throw CampaignHubError(_messageFor(e));
    } finally {
      _busy.remove(key);
      notifyListeners();
    }
  }

  /// Removes a candidate. Returns an error message, or `null` on success.
  Future<String?> deleteCandidate(String id) async {
    if (!capabilities.canManageCandidates) {
      return capabilities.reason ??
          "You don't have permission to manage candidates.";
    }
    final key = 'candidate:delete:$id';
    if (_busy.contains(key)) return null;
    _busy.add(key);
    notifyListeners();
    try {
      await _repository.deleteCandidate(id);
      _removeCandidate(id);
      return null;
    } on ApiClientException catch (e) {
      if (e.statusCode == 404) {
        _removeCandidate(id);
        return null;
      }
      if (e.isForbidden) _managementGranted = false;
      return _messageFor(e);
    } catch (e) {
      return _messageFor(e);
    } finally {
      _busy.remove(key);
      notifyListeners();
    }
  }

  void _removeCandidate(String id) {
    _candidates = [
      for (final c in _candidates)
        if (c.id != id) c,
    ];
    final channelId = _channelByCandidate.remove(id);
    if (channelId != null) _repository.unwatchChannel(channelId);
    _shiftsByCandidate.remove(id);
    _myShifts = [
      for (final s in _myShifts)
        if (s.candidateId != id) s,
    ];
  }

  /// Joins [candidateId]'s supporter channel. Returns an error message, or
  /// `null` on success.
  Future<String?> join(String candidateId) async {
    if (!capabilities.canJoinChannels) return capabilities.reason;
    final key = 'channel:$candidateId';
    if (_busy.contains(key)) return null;
    _busy.add(key);
    notifyListeners();
    try {
      final membership = await _repository.joinChannel(candidateId);
      _channelByCandidate[candidateId] = membership.channelId;
      return null;
    } catch (e) {
      if (_isForbidden(e)) _channelByCandidate.remove(candidateId);
      return _messageFor(e);
    } finally {
      _busy.remove(key);
      notifyListeners();
    }
  }

  /// Leaves [candidateId]'s supporter channel. Leaving is always offered; a
  /// `403`/`404` means the server already considers the user out.
  Future<String?> leave(String candidateId) async {
    if (!capabilities.writesEnabled) return capabilities.reason;
    final key = 'channel:$candidateId';
    if (_busy.contains(key)) return null;
    _busy.add(key);
    notifyListeners();
    try {
      final channelId = _channelByCandidate[candidateId];
      await _repository.leaveChannel(candidateId);
      _channelByCandidate.remove(candidateId);
      if (channelId != null) _repository.unwatchChannel(channelId);
      return null;
    } on ApiClientException catch (e) {
      if (e.statusCode == 403 || e.statusCode == 404) {
        _channelByCandidate.remove(candidateId);
        return null;
      }
      return e.message;
    } catch (e) {
      return _messageFor(e);
    } finally {
      _busy.remove(key);
      notifyListeners();
    }
  }

  /// Called when the server refuses channel access: the server is the
  /// authority, so the local membership is dropped.
  void markNotMember(String candidateId) {
    if (_channelByCandidate.remove(candidateId) != null) notifyListeners();
  }

  Future<void> loadShifts(String candidateId) async {
    if (_loadingShifts.contains(candidateId)) return;
    _loadingShifts.add(candidateId);
    _shiftErrors.remove(candidateId);
    notifyListeners();
    try {
      _shiftsByCandidate[candidateId] = await _repository.fetchShifts(
        candidateId,
      );
    } catch (e) {
      _shiftErrors[candidateId] = _messageFor(e);
    } finally {
      _loadingShifts.remove(candidateId);
      notifyListeners();
    }
  }

  Future<String?> signUp(CampaignShift shift) =>
      _changeShift(shift, _repository.signUpForShift);

  Future<String?> cancel(CampaignShift shift) =>
      _changeShift(shift, _repository.cancelShift);

  Future<String?> _changeShift(
    CampaignShift shift,
    Future<CampaignShift> Function(CampaignShift) action,
  ) async {
    if (!capabilities.canSignUpForShifts) return capabilities.reason;
    final key = 'shift:${shift.id}';
    if (_busy.contains(key)) return null;
    _busy.add(key);
    notifyListeners();
    try {
      final updated = await action(shift);
      _replaceShift(updated);
      return null;
    } catch (e) {
      return _messageFor(e);
    } finally {
      _busy.remove(key);
      notifyListeners();
    }
  }

  void _replaceShift(CampaignShift updated) {
    final list = _shiftsByCandidate[updated.candidateId];
    if (list != null) {
      _shiftsByCandidate[updated.candidateId] = [
        for (final s in list) s.id == updated.id ? updated : s,
      ];
    }
    _myShifts = [
      for (final s in _myShifts)
        if (s.id != updated.id) s,
      if (updated.signedUp) updated,
    ]..sort((a, b) => a.startsAt.compareTo(b.startsAt));
  }

  /// Drops all cached hub state. Called on every session change.
  void clearSession() {
    _generation++;
    _inFlight = null;
    for (final channelId in _channelByCandidate.values) {
      _repository.unwatchChannel(channelId);
    }
    _status = CampaignHubStatus.idle;
    _error = null;
    _candidates = const [];
    _channelByCandidate.clear();
    _shiftsByCandidate.clear();
    _loadingShifts.clear();
    _shiftErrors.clear();
    _busy.clear();
    _myShifts = const [];
    _managementGranted = false;
    notifyListeners();
  }

  void _onPreviewChanged() => notifyListeners();

  static bool _isForbidden(Object e) =>
      e is ApiClientException && e.isForbidden;

  static String _messageFor(Object e) {
    if (e is ApiClientException) {
      return e.isForbidden
          ? "You don't have access to that. Please contact Emerge Kentucky "
                'if you think this is a mistake.'
          : e.message;
    }
    if (e is CampaignWritesDisabledException) return e.message;
    return 'Something went wrong. Please try again.';
  }

  @override
  void dispose() {
    _previewChanges?.removeListener(_onPreviewChanged);
    _sessionSub?.cancel();
    super.dispose();
  }
}
