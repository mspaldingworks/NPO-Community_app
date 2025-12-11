import 'package:flutter/material.dart';
import 'package:transconnect/core/services/friend_service.dart';
import 'package:transconnect/core/services/auth_service.dart';
import 'package:transconnect/models/friend_request.dart';
import 'package:transconnect/models/user.dart';

class FriendsController with ChangeNotifier {
  final FriendService _friendService = FriendService();

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

      final isPending = (FriendRequest req) => req.status == null || req.status == 'pending';
      final isIncoming = (FriendRequest req) {
        if (me == null) return true; // If we can't resolve current user, show all pending entries
        // Prefer entries explicitly addressed to me
        if (req.toUser?.username == me) return true;
        // Some backends omit to_user; treat as incoming if the sender isn't me
        if (req.fromUser.username != me) return true;
        return false;
      };

      _pendingRequests = requests.where((r) => isPending(r) && isIncoming(r)).toList();
      _pendingSentRequests = requests.where((r) => isPending(r) && me != null && r.fromUser.username == me).toList();
    } catch (e) {
      _pendingError = 'Failed to load pending requests. Please try again.';
    } finally {
      _isLoadingPending = false;
      notifyListeners();
    }
  }

  Future<bool> acceptRequest(String username) async {
    try {
      await _friendService.acceptFriendRequest(username);
      _pendingRequests.removeWhere((req) => req.fromUser.username == username);
      // Refresh friends list when a request is accepted
      await fetchFriends();
      notifyListeners();
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> declineRequest(String username) async {
    try {
      await _friendService.declineFriendRequest(username);
      _pendingRequests.removeWhere((req) => req.fromUser.username == username);
      notifyListeners();
      return true;
    } catch (e) {
      return false;
    }
  }

  // --- Methods for Friends List ---

  Future<void> fetchFriends() async {
    _isLoadingFriends = true;
    _friendsError = null;
    notifyListeners();

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
      _isLoadingFriends = false;
      notifyListeners();
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
