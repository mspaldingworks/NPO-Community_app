import 'package:flutter/material.dart';
import 'package:npo_community/core/services/friend_service.dart';
import 'package:npo_community/core/services/auth_service.dart';
import 'package:npo_community/models/friend_request.dart';
import 'package:npo_community/models/user.dart';

class FriendsController with ChangeNotifier {
  final FriendService _friendService = FriendService();

  final Set<String> _requestActionsInProgress = {};
  bool isRequestActionInProgress(String username) =>
      _requestActionsInProgress.contains(username);

  // State for pending requests
  List<FriendRequest> _pendingRequests = [];
  List<FriendRequest> get pendingRequests => _pendingRequests;
  // Outgoing (sent) pending requests
  List<FriendRequest> _pendingSentRequests = [];
  List<FriendRequest> get pendingSentRequests => _pendingSentRequests;
  bool _isLoadingPending = false;
  bool get isLoadingPending => _isLoadingPending;
  String? _pendingError;
  String? get pendingError => _pendingError;

  // State for friends list
  List<Friend> _friends = [];
  List<Friend> get friends => _friends;
  bool _isLoadingFriends = false;
  bool get isLoadingFriends => _isLoadingFriends;
  String? _friendsError;
  String? get friendsError => _friendsError;

  // State for user search
  List<Friend> _searchResults = [];
  List<Friend> get searchResults => _searchResults;
  bool _isLoadingSearch = false;
  bool get isLoadingSearch => _isLoadingSearch;
  String? _searchError;
  String? get searchError => _searchError;

  // State for sent requests to manage button states
  final Set<String> _sentRequests = {};
  bool isRequestSent(String username) => _sentRequests.contains(username);

  // --- Methods for Pending Requests ---

  Future<void> fetchPendingRequests() async {
    _isLoadingPending = true;
    _pendingError = null;
    notifyListeners();

    try {
      final requests = await _friendService.listPendingRequests();
      // Determine the current user so we can filter for incoming requests only.
      String? me;
      try {
        me = (await AuthService().getCurrentUser()).username;
      } catch (_) {}

      final isPending = (FriendRequest req) =>
          req.status == null || req.status == 'pending';
      final isIncoming = (FriendRequest req) {
        if (me == null)
          return true; // If we can't resolve current user, show all pending entries
        // Prefer entries explicitly addressed to me
        if (req.toUser?.username == me) return true;
        // Some backends omit to_user; treat as incoming if the sender isn't me
        if (req.fromUser.username != me) return true;
        return false;
      };

      _pendingRequests = requests
          .where((r) => isPending(r) && isIncoming(r))
          .toList();
      _pendingSentRequests = requests
          .where((r) => isPending(r) && me != null && r.fromUser.username == me)
          .toList();
    } catch (e) {
      _pendingError = 'Failed to load pending requests. Please try again.';
    } finally {
      _isLoadingPending = false;
      notifyListeners();
    }
  }

  Future<bool> acceptRequest(String username) async {
    if (_requestActionsInProgress.contains(username)) {
      return false;
    }

    final previousPending = List<FriendRequest>.from(_pendingRequests);
    final previousFriends = List<Friend>.from(_friends);

    final FriendRequest? request = _pendingRequests
        .cast<FriendRequest?>()
        .firstWhere(
          (req) => req?.fromUser.username == username,
          orElse: () => null,
        );

    _requestActionsInProgress.add(username);
    _pendingRequests.removeWhere((req) => req.fromUser.username == username);
    if (request != null &&
        !_friends.any((f) => f.username == request.fromUser.username)) {
      _friends = [request.fromUser, ..._friends];
    }
    notifyListeners();

    try {
      await _friendService.acceptFriendRequest(username);
      await fetchFriendsWithLoading(showLoading: false);
      _requestActionsInProgress.remove(username);
      notifyListeners();
      return true;
    } catch (e) {
      _pendingRequests = previousPending;
      _friends = previousFriends;
      _requestActionsInProgress.remove(username);
      notifyListeners();
      return false;
    }
  }

  Future<bool> declineRequest(String username) async {
    if (_requestActionsInProgress.contains(username)) {
      return false;
    }

    final previousIncoming = List<FriendRequest>.from(_pendingRequests);
    final previousOutgoing = List<FriendRequest>.from(_pendingSentRequests);

    _requestActionsInProgress.add(username);
    _pendingRequests.removeWhere((req) => req.fromUser.username == username);
    _pendingSentRequests.removeWhere((req) => req.toUser?.username == username);
    notifyListeners();

    try {
      await _friendService.declineFriendRequest(username);
      _requestActionsInProgress.remove(username);
      notifyListeners();
      return true;
    } catch (e) {
      _pendingRequests = previousIncoming;
      _pendingSentRequests = previousOutgoing;
      _requestActionsInProgress.remove(username);
      notifyListeners();
      return false;
    }
  }

  // --- Methods for Friends List ---

  Future<void> fetchFriends() async {
    await fetchFriendsWithLoading(showLoading: true);
  }

  Future<void> fetchFriendsWithLoading({required bool showLoading}) async {
    if (showLoading) {
      _isLoadingFriends = true;
      _friendsError = null;
      notifyListeners();
    }

    try {
      final apiFriends = await _friendService.listFriends();
      if (apiFriends.isNotEmpty) {
        _friends = apiFriends;
      } else {
        // Fallback: many endpoints embed friends within the current user payload
        try {
          final me = await AuthService().getCurrentUser();
          _friends = me.friends;
        } catch (_) {
          _friends = [];
        }
      }
    } catch (e) {
      _friendsError = 'Failed to load friends. Please try again.';
    } finally {
      if (showLoading) {
        _isLoadingFriends = false;
        notifyListeners();
      }
    }
  }

  Future<bool> removeFriend(String username) async {
    try {
      await _friendService.removeFriend(username);
      _friends.removeWhere((friend) => friend.username == username);
      notifyListeners();
      return true;
    } catch (e) {
      return false;
    }
  }

  // --- Methods for User Search ---

  Future<void> searchUsers(String query) async {
    if (query.isEmpty) {
      _searchResults = [];
      notifyListeners();
      return;
    }

    _isLoadingSearch = true;
    _searchError = null;
    notifyListeners();

    try {
      _searchResults = await _friendService.searchFriends(query);
    } catch (e) {
      _searchError = 'Search failed. Please check your connection.';
    } finally {
      _isLoadingSearch = false;
      notifyListeners();
    }
  }

  Future<bool> sendFriendRequest(String username) async {
    try {
      await _friendService.sendFriendRequest(username);
      _sentRequests.add(username);
      notifyListeners();
      return true;
    } catch (e) {
      return false;
    }
  }
}
