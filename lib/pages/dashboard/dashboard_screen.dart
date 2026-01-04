import 'dart:io';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:transconnect/core/services/calendar_service.dart';
import 'package:transconnect/data/affirmation_quotes.dart';
import 'package:transconnect/core/services/profile_service.dart';
import 'package:transconnect/theme/app_theme.dart';
import 'package:transconnect/models/post.dart';
import 'package:transconnect/models/user.dart';
import 'package:transconnect/core/services/auth_service.dart';
import 'package:transconnect/widgets/display_profile_pic.dart';
import 'package:transconnect/core/services/friend_service.dart';
import 'package:transconnect/core/utils/time_ago.dart';
import 'package:transconnect/core/services/community_service.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';
import 'package:transconnect/widgets/emergency_alert_banner.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_selector/file_selector.dart';
import 'package:transconnect/core/services/chat_service.dart';
import 'package:transconnect/models/chat_message.dart';
import 'package:transconnect/core/services/report_service.dart';
import 'package:transconnect/widgets/report_dialog.dart';
import 'package:transconnect/core/utils/flair_utils.dart';
import 'package:transconnect/features/geocaching/utils/cache_collections.dart';
import 'package:transconnect/features/onboarding_tour/widgets/tour_anchor.dart';
import 'package:transconnect/widgets/link_preview_card.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _PathPoint {
  final double t;
  final double x;
  final double y;
  const _PathPoint(this.t, this.x, this.y);
}

class _HotspotPathPainter extends CustomPainter {
  final List<_PathPoint> points;
  final double margin;
  final Color color;

  const _HotspotPathPainter({
    required this.points,
    required this.margin,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round;

    final path = Path();
    for (int i = 0; i < points.length; i++) {
      final p = points[i];
      final x = (margin + p.x * (1 - 2 * margin)) * size.width;
      final y = p.y * size.height;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _HotspotPathPainter oldDelegate) {
    return oldDelegate.margin != margin || oldDelegate.color != color || oldDelegate.points != points;
  }
}

class _ToggleCalibrationIntent extends Intent {
  const _ToggleCalibrationIntent();
}

class _ToggleVideoPauseIntent extends Intent {
  const _ToggleVideoPauseIntent();
}

class _SeekBackwardIntent extends Intent {
  const _SeekBackwardIntent();
}

class _SeekForwardIntent extends Intent {
  const _SeekForwardIntent();
}

class _SeekBackwardLargeIntent extends Intent {
  const _SeekBackwardLargeIntent();
}

class _SeekForwardLargeIntent extends Intent {
  const _SeekForwardLargeIntent();
}


class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final CalendarService _calendarService = CalendarService();
  final ProfileService _profileService = ProfileService();
  final FriendService _friendService = FriendService();
  final CommunityService _communityService = CommunityService();
  final ChatService _chatService = ChatService();
  Map<int, String?> _userFlairById = {};
  Map<int, String?> _userPicById = {};

  bool _hasUnreadCacheCollections = false;

  Future<void> _loadUnreadCacheCollections() async {
    final hasUnread = await CacheCollections.hasUnread();
    if (!mounted) return;
    setState(() {
      _hasUnreadCacheCollections = hasUnread;
    });
  }
  File? _profileImage;
  bool _isLoading = true;
  AffirmationQuote? _quote;
  List<Friend> _friendStatusFeed = [];
  bool _isLoadingFriendFeed = true;
  final Map<int, TextEditingController> _statusCommentCtrls = {};
  final Map<int, Post> _statusPostByFriendId = {};
  final Map<int, List<ChatMessage>> _statusDmCommentsByFriendId = {};
  bool _isLoadingStatusPosts = false;
  bool _updatingProfilePic = false;
  int _todaysEventsCount = 0;

  static const String _statusDmPrefix = '[STATUS_COMMENT] ';

  bool _quoteVisible = false;
  Timer? _quoteTimer;

  double get _hotspotCycleSeconds {
    if (_loadedButterflyAsset == 'assets/animations/Green_TWC_butterfly.mp4') {
      return 13.5;
    }
    return 10.0;
  }
  final double _hotspotMarginSeconds = 1.0;
  final double _hotspotWidthFraction = 0.18;
  final double _hotspotPauseSeconds = 10.0;
  final double _hotspotPhaseOffsetSeconds = 0.0;

  VideoPlayerController? _videoCtrl;
  bool _videoReady = false;
  bool _videoWaitingForRestart = false;
  Timer? _videoPauseTimer;
  final double _videoPlaybackSpeed = 1.0;
  bool _animVisible = true;
  bool _suppressUntilNextLoop = false;
  final double _hotspotHeightFraction = 0.15;
  bool _calibrationMode = false;
  final FocusNode _shortcutFocusNode = FocusNode(debugLabel: 'DashboardShortcuts');

  static const List<String> _butterflyVideoAssets = <String>[
    'assets/animations/blue_butterfly.mp4',
    'assets/animations/Pink_TWC_butterfly.mp4',
    'assets/animations/Green_TWC_butterfly.mp4',
  ];
  static const String _butterflyVideoIndexPrefKey = 'dashboard_butterfly_video_index';
  int _butterflyVideoIndex = 0;
  bool _butterflyPrefLoaded = false;
  String _loadedButterflyAsset = _butterflyVideoAssets.first;

  String get _currentButterflyAsset => _butterflyVideoAssets[_butterflyVideoIndex % _butterflyVideoAssets.length];

  void _toggleCalibrationMode() {
    setState(() {
      _calibrationMode = !_calibrationMode;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_calibrationMode) {
        _shortcutFocusNode.requestFocus();
      } else {
        _shortcutFocusNode.unfocus();
      }
    });
  }

  static const List<_PathPoint> _hotspotPathBlue = <_PathPoint>[
    _PathPoint(0.000, 0.000, 0.696),
    _PathPoint(0.079, 0.000, 0.696),
    _PathPoint(0.129, 0.000, 0.752),
    _PathPoint(0.179, 0.000, 0.581),
    _PathPoint(0.219, 0.077, 0.503),
    _PathPoint(0.269, 0.196, 0.378),
    _PathPoint(0.299, 0.259, 0.382),
    _PathPoint(0.339, 0.320, 0.547),
    _PathPoint(0.379, 0.366, 0.665),
    _PathPoint(0.419, 0.408, 0.514),
    _PathPoint(0.449, 0.374, 0.430),
    _PathPoint(0.469, 0.358, 0.479),
    _PathPoint(0.509, 0.398, 0.662),
    _PathPoint(0.539, 0.444, 0.689),
    _PathPoint(0.569, 0.571, 0.456),
    _PathPoint(0.589, 0.580, 0.454),
    _PathPoint(0.609, 0.614, 0.511),
    _PathPoint(0.629, 0.662, 0.585),
    _PathPoint(0.659, 0.723, 0.649),
    _PathPoint(0.669, 0.765, 0.700),
    _PathPoint(0.699, 0.780, 0.612),
    _PathPoint(0.719, 0.782, 0.582),
    _PathPoint(0.819, 1.000, 0.627),
    _PathPoint(0.849, 1.000, 0.679),
    _PathPoint(0.879, 1.000, 0.761),
    _PathPoint(0.899, 1.000, 0.797),
    _PathPoint(1.000, 1.000, 0.797),
  ];

  static const List<_PathPoint> _hotspotPathPink = <_PathPoint>[
    _PathPoint(0.000, 1.000, 0.240),
    _PathPoint(0.100, 0.900, 0.205),
    _PathPoint(0.200, 0.800, 0.240),
    _PathPoint(0.300, 0.700, 0.215),
    _PathPoint(0.400, 0.600, 0.255),
    _PathPoint(0.500, 0.500, 0.230),
    _PathPoint(0.600, 0.400, 0.265),
    _PathPoint(0.700, 0.300, 0.235),
    _PathPoint(0.800, 0.200, 0.260),
    _PathPoint(0.900, 0.100, 0.245),
    _PathPoint(1.000, 0.000, 0.260),
  ];

  static const List<_PathPoint> _hotspotPathGreen = <_PathPoint>[
    _PathPoint(0.000, 0.000, 0.220),
    _PathPoint(0.060, 0.080, 0.230),
    _PathPoint(0.120, 0.160, 0.260),
    _PathPoint(0.180, 0.240, 0.300),
    _PathPoint(0.240, 0.320, 0.350),
    _PathPoint(0.304, 0.500, 0.720),
    _PathPoint(0.674, 0.500, 0.720),
    _PathPoint(0.740, 0.400, 0.650),
    _PathPoint(0.810, 0.300, 0.560),
    _PathPoint(0.880, 0.200, 0.440),
    _PathPoint(0.940, 0.100, 0.300),
    _PathPoint(1.000, 0.000, 0.220),
  ];

  List<_PathPoint> get _activeHotspotPath {
    if (_loadedButterflyAsset == _butterflyVideoAssets[2]) {
      return _hotspotPathGreen;
    }
    if (_loadedButterflyAsset == _butterflyVideoAssets[1]) {
      return _hotspotPathPink;
    }
    return _hotspotPathBlue;
  }

  double get _effectiveCycleSeconds {
    if (_videoReady && _videoCtrl != null && _videoCtrl!.value.isInitialized) {
      final durMs = _videoCtrl!.value.duration.inMilliseconds;
      if (durMs > 0) {
        final playedSeconds = (durMs / 1000.0) / (_videoPlaybackSpeed <= 0 ? 1.0 : _videoPlaybackSpeed);
        // Force the cycle to 10s if the video is longer than that.
        return playedSeconds > _hotspotCycleSeconds ? _hotspotCycleSeconds : playedSeconds;
      }
    }
    return _hotspotCycleSeconds;
  }

  Future<void> _showStatusDmCommentsSheet(Friend friend) async {
    List<ChatMessage> msgs = _statusDmCommentsByFriendId[friend.id] ?? const [];
    if (msgs.isEmpty) {
      try {
        final all = await _chatService.getConversation(friend.id);
        msgs = _filterStatusDmMessages(all);
        _statusDmCommentsByFriendId[friend.id] = msgs;
        if (mounted) setState(() {});
      } catch (_) {}
    }

    if (!mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        final bottomInset = MediaQuery.of(context).viewInsets.bottom;
        final height = MediaQuery.of(context).size.height;
        return Padding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottomInset),
          child: SizedBox(
            height: height * 0.6,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Comments',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                if (msgs.isEmpty)
                  const Text('No comments yet.')
                else
                  Expanded(
                    child: ListView.separated(
                      itemCount: msgs.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, i) {
                        final m = msgs[i];
                        final content = m.content.startsWith(_statusDmPrefix)
                            ? m.content.substring(_statusDmPrefix.length)
                            : m.content;
                        final flair = _userFlairById[m.sender.id];
                        final isPrivate = FlairUtils.isProfilePrivate(flair);
                        final String? pronounsDisplay = isPrivate
                            ? null
                            : (FlairUtils.extractPronouns(flair) ?? '')
                                .split(RegExp(r'[\n,]'))
                                .map((p) => p.trim())
                                .where((p) => p.isNotEmpty)
                                .join(' • ');
                        return Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              DisplayProfilePic(
                                radius: 20,
                                imageUrl: _userPicById[m.sender.id],
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      m.sender.username,
                                      style: const TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                    if (pronounsDisplay != null && pronounsDisplay.isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 2),
                                        child: Text(
                                          pronounsDisplay,
                                          style: Theme.of(context).textTheme.bodySmall,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    const SizedBox(height: 4),
                                    Text(content),
                                    LinkPreviewCard(urlOrText: content),
                                  ],
                                ),
                              ),
                              IconButton(
                                tooltip: 'Report comment',
                                icon: const Icon(Icons.flag_outlined, size: 18),
                                onPressed: () async {
                                  await showReportDialog(
                                    context: context,
                                    baseRequest: ReportRequest(
                                      type: ReportTargetType.statusComment,
                                      reason: '',
                                      targetId: m.id,
                                      targetUserId: m.sender.id,
                                      targetUsername: m.sender.username,
                                      details: content,
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Close'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Offset _samplePath(double t) {
    final hotspotPath = _activeHotspotPath;
    if (hotspotPath.isEmpty) return const Offset(0.5, 0.5);
    final clamped = t.clamp(0.0, 1.0);
    for (int i = 0; i < hotspotPath.length - 1; i++) {
      final a = hotspotPath[i];
      final b = hotspotPath[i + 1];
      if (clamped >= a.t && clamped <= b.t) {
        final span = (b.t - a.t).abs() < 1e-6 ? 1.0 : (clamped - a.t) / (b.t - a.t);
        final x = a.x + (b.x - a.x) * span;
        final y = a.y + (b.y - a.y) * span;
        return Offset(x, y);
      }
    }
    final last = hotspotPath.last;
    return Offset(last.x, last.y);
  }

  TextEditingController _ctrlFor(int friendId)
      => _statusCommentCtrls.putIfAbsent(friendId, () => TextEditingController());

  Future<void> _loadUserFlairMap() async {
    try {
      final users = await AuthService().getAllUsers();
      if (!mounted) return;
      setState(() {
        _userFlairById = {for (final u in users) u.id: u.flair};
        _userPicById = {for (final u in users) u.id: u.fullProfilePicUrl};
      });
    } catch (_) {
      // Ignore silently; pronouns will not be displayed
    }
  }

  @override
  void initState() {
    super.initState();
    _initVideo();
    _loadUserFlairMap();
    _loadDashboardData();
    _loadUnreadCacheCollections();
  }

  Future<void> _loadButterflyVideoPreference() async {
    if (_butterflyPrefLoaded) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      _butterflyVideoIndex = prefs.getInt(_butterflyVideoIndexPrefKey) ?? 0;
    } catch (_) {
      _butterflyVideoIndex = 0;
    }
    _butterflyPrefLoaded = true;
  }

  Future<void> _saveButterflyVideoPreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_butterflyVideoIndexPrefKey, _butterflyVideoIndex);
    } catch (_) {}
  }

  @override
  void dispose() {
    _quoteTimer?.cancel();
    _videoPauseTimer?.cancel();
    awaitDisposeVideo();
    _shortcutFocusNode.dispose();
    for (final c in _statusCommentCtrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  void awaitDisposeVideo() {
    try {
      _videoCtrl?.removeListener(_onVideoTick);
      _videoCtrl?.dispose();
    } catch (_) {}
    _videoCtrl = null;
  }

  Future<void> _initVideo() async {
    await _loadButterflyVideoPreference();
    try {
      VideoPlayerController? ctrl;
      try {
        final c1 = VideoPlayerController.asset(_currentButterflyAsset);
        await c1.initialize();
        ctrl = c1;
      } catch (e) {
        debugPrint('[DashboardScreen] VideoPlayerController.asset init failed: $e');
        try {
          final data = await rootBundle.load(_currentButterflyAsset);
          final dir = await getTemporaryDirectory();
          final fileName = _currentButterflyAsset.split('/').last;
          final f = File('${dir.path}/$fileName');
          await f.writeAsBytes(data.buffer.asUint8List(), flush: true);
          final c2 = VideoPlayerController.file(f);
          await c2.initialize();
          ctrl = c2;
        } catch (e) {
          debugPrint('[DashboardScreen] VideoPlayerController.file init failed: $e');
          if (_currentButterflyAsset != _butterflyVideoAssets.first) {
            _butterflyVideoIndex = 0;
            await _saveButterflyVideoPreference();
            if (mounted) {
              await _initVideo();
            }
            return;
          }
          if (!mounted) return;
          setState(() {
            _videoReady = false;
          });
          return;
        }
      }
      await ctrl.setLooping(false);
      await ctrl.setVolume(0.0);
      try { await ctrl.setPlaybackSpeed(_videoPlaybackSpeed); } catch (_) {}
      ctrl.addListener(_onVideoTick);
      if (!mounted) return;
      setState(() {
        _videoCtrl = ctrl;
        _videoReady = true;
        _loadedButterflyAsset = _currentButterflyAsset;
      });
      final readyCtrl = ctrl;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted || _videoCtrl != readyCtrl) return;
        try {
          await readyCtrl.play();
        } catch (e) {
          debugPrint('[DashboardScreen] Video play failed: $e');
        }
      });
    } catch (e) {
      debugPrint('[DashboardScreen] _initVideo unexpected failure: $e');
      if (!mounted) return;
      setState(() {
        _videoReady = false;
      });
    }
  }

  void _onVideoTick() {
    final c = _videoCtrl;
    if (c == null || !_videoReady) return;
    final v = c.value;
    if (!v.isInitialized) return;
    // Loop end in CONTENT time that corresponds to 10s in REAL time at current playback speed
    final loopEndContentMs = (v.duration.inMilliseconds < (_videoPlaybackSpeed * _hotspotCycleSeconds * 1000))
        ? v.duration.inMilliseconds
        : (_videoPlaybackSpeed * _hotspotCycleSeconds * 1000).round();
    final loopEndContent = Duration(milliseconds: loopEndContentMs);
    final remaining = loopEndContent - v.position;
    if (remaining <= const Duration(milliseconds: 80) || (!v.isPlaying && v.position >= loopEndContent && !_calibrationMode)) {
      _handleVideoCompleted();
    }
  }

  void _handleVideoCompleted() {
    if (_videoWaitingForRestart) return;
    final c = _videoCtrl;
    if (c == null) return;
    _videoWaitingForRestart = true;
    c.pause();
    _videoPauseTimer?.cancel();
    // Compute pause to make the full cycle exactly _hotspotCycleSeconds in REAL time
    final contentMs = c.value.duration.inMilliseconds; // content ms
    final playedContentMs = (
      contentMs < (_videoPlaybackSpeed * _hotspotCycleSeconds * 1000)
        ? contentMs
        : (_videoPlaybackSpeed * _hotspotCycleSeconds * 1000).round()
    );
    final playedRealMs = (playedContentMs / (_videoPlaybackSpeed <= 0 ? 1.0 : _videoPlaybackSpeed)).round();
    final targetRealMs = (_hotspotCycleSeconds * 1000).round();
    final remainingToTenMs = (targetRealMs - playedRealMs).clamp(0, targetRealMs);
    final pauseMs = remainingToTenMs + (_hotspotPauseSeconds * 1000).round();
    _videoPauseTimer = Timer(Duration(milliseconds: pauseMs), () async {
      if (!mounted) return;

      final previousIndex = _butterflyVideoIndex;
      final nextIndex = (previousIndex + 1) % _butterflyVideoAssets.length;
      _butterflyVideoIndex = nextIndex;

      final previous = _videoCtrl;
      final swapped = await _swapButterflyVideo();

      if (!swapped) {
        _butterflyVideoIndex = previousIndex;
      }
      await _saveButterflyVideoPreference();

      if (!mounted) return;
      _videoWaitingForRestart = false;

      if (_suppressUntilNextLoop) {
        setState(() {
          _animVisible = true;
          _suppressUntilNextLoop = false;
        });
      }

      if (!swapped) {
        final stillSame = _videoCtrl == previous;
        if (stillSame && previous != null) {
          try {
            await previous.seekTo(Duration.zero);
            await previous.play();
          } catch (_) {}
        }
      }
    });
  }

  Future<bool> _swapButterflyVideo() async {
    final oldCtrl = _videoCtrl;

    VideoPlayerController? newCtrl;
    String? resolvedAsset;

    Future<VideoPlayerController?> tryCreate(String assetPath) async {
      try {
        final c1 = VideoPlayerController.asset(assetPath);
        await c1.initialize();
        return c1;
      } catch (_) {
        try {
          final data = await rootBundle.load(assetPath);
          final dir = await getTemporaryDirectory();
          final fileName = assetPath.split('/').last;
          final f = File('${dir.path}/$fileName');
          await f.writeAsBytes(data.buffer.asUint8List(), flush: true);
          final c2 = VideoPlayerController.file(f);
          await c2.initialize();
          return c2;
        } catch (_) {
          return null;
        }
      }
    }

    newCtrl = await tryCreate(_currentButterflyAsset);
    resolvedAsset = _currentButterflyAsset;

    if (newCtrl == null && _currentButterflyAsset != _butterflyVideoAssets.first) {
      newCtrl = await tryCreate(_butterflyVideoAssets.first);
      resolvedAsset = _butterflyVideoAssets.first;
      if (newCtrl != null) {
        _butterflyVideoIndex = 0;
        await _saveButterflyVideoPreference();
      }
    }

    if (newCtrl == null) {
      return false;
    }

    try {
      await newCtrl.setLooping(false);
      await newCtrl.setVolume(0.0);
      try {
        await newCtrl.setPlaybackSpeed(_videoPlaybackSpeed);
      } catch (_) {}
      newCtrl.addListener(_onVideoTick);
    } catch (_) {
      try {
        await newCtrl.dispose();
      } catch (_) {}
      return false;
    }

    try {
      oldCtrl?.removeListener(_onVideoTick);
      await oldCtrl?.dispose();
    } catch (_) {}

    if (!mounted) {
      try {
        await newCtrl.dispose();
      } catch (_) {}
      return false;
    }

    setState(() {
      _videoCtrl = newCtrl;
      _videoReady = true;
      _loadedButterflyAsset = resolvedAsset ?? _loadedButterflyAsset;
    });

    try {
      await newCtrl.play();
    } catch (_) {}

    return true;
  }

  Future<void> _loadDashboardData() async {
    await _loadUnreadCacheCollections();
    await _loadUserFlairMap();
    final allEvents = await _calendarService.fetchEvents();
    final imagePath = await _profileService.getImagePath();
    final now = DateTime.now();

    final quote = pickRandomQuote();

    // Load friends and prepare status feed (descending by updated time)
    var apiFriends = await _friendService.listFriends();
    // Ensure auth/session is loaded, then retry once
    if (apiFriends.isEmpty) {
      try { await AuthService().getCurrentUser(); } catch (_) {}
      apiFriends = await _friendService.listFriends();
    }

    // Merge with friends embedded in current user payload; prefer entries with non-empty status
    List<Friend> meFriends = const [];
    try { meFriends = (await AuthService().getCurrentUser()).friends; } catch (_) {}

    final Map<int, Friend> friendsById = {};
    void addOrPrefer(Friend f) {
      final existing = friendsById[f.id];
      if (existing == null) {
        friendsById[f.id] = f;
      } else {
        final hasStatus = (f.statusMessage?.trim().isNotEmpty ?? false);
        final existingHasStatus = (existing.statusMessage?.trim().isNotEmpty ?? false);
        if (hasStatus && !existingHasStatus) {
          friendsById[f.id] = f;
        } else if (hasStatus == existingHasStatus) {
          // If both or neither have status, prefer the newer update time
          final fa = f.statusUpdatedAt;
          final fb = existing.statusUpdatedAt;
          if (fa != null && (fb == null || fa.isAfter(fb))) {
            friendsById[f.id] = f;
          }
        }
      }
    }

    for (final f in apiFriends) {
      addOrPrefer(f);
    }
    for (final f in meFriends) {
      addOrPrefer(f);
    }

    final mergedFriends = friendsById.values.toList();
    final statuses = mergedFriends
        .where((f) => (f.statusMessage?.trim().isNotEmpty ?? false))
        .toList();
    statuses.sort((a, b) {
      final A = a.statusUpdatedAt;
      final B = b.statusUpdatedAt;
      if (A == null && B == null) return 0;
      if (A == null) return 1; // nulls last
      if (B == null) return -1;
      return B.compareTo(A); // newest first
    });

    // Today-only events in chronological order
    final todaysEvents = allEvents.where((event) {
      final d = event.start.toLocal();
      return d.year == now.year && d.month == now.month && d.day == now.day;
    }).toList()
      ..sort((a, b) => a.start.compareTo(b.start));

    if (mounted) {
      setState(() {
        _todaysEventsCount = todaysEvents.length;
        if (imagePath != null) {
          _profileImage = File(imagePath);
        }
        _isLoading = false;
        _quote = quote;
        _friendStatusFeed = statuses;
        _isLoadingFriendFeed = false;
      });
    }

    await _loadStatusPostsFor(statuses);
    await _loadStatusDmCountsFor(statuses);
  }

  List<ChatMessage> _filterStatusDmMessages(List<ChatMessage> msgs) {
    return msgs.where((m) => m.content.startsWith(_statusDmPrefix)).toList();
  }

  Future<void> _loadStatusDmCountsFor(List<Friend> statuses) async {
    try {
      final futures = statuses.map((f) async {
        try {
          final msgs = await _chatService.getConversation(f.id);
          final filtered = _filterStatusDmMessages(msgs);
          _statusDmCommentsByFriendId[f.id] = filtered;
        } catch (_) {
          _statusDmCommentsByFriendId[f.id] = const [];
        }
      }).toList();
      if (futures.isNotEmpty) {
        await Future.wait(futures);
      }
      if (!mounted) return;
      setState(() {});
    } catch (_) {
      // ignore
    }
  }

  DateTime _postSortDate(Post p) {
    final raw = (p.updatedAt ?? '').isNotEmpty ? p.updatedAt : p.pubDate;
    if (raw == null || raw.isEmpty) return DateTime.fromMillisecondsSinceEpoch(0);
    try {
      return DateTime.parse(raw).toUtc();
    } catch (_) {
      return DateTime.fromMillisecondsSinceEpoch(0);
    }
  }

  Future<void> _loadStatusPostsFor(List<Friend> statuses) async {
    if (_isLoadingStatusPosts) return;
    setState(() {
      _isLoadingStatusPosts = true;
    });

    try {
      final posts = await _communityService.fetchAllPosts();

      final Map<String, List<Post>> byAuthorUsername = {};
      for (final p in posts) {
        final sm = (p.statusMessage ?? '').trim();
        if (sm.isEmpty) continue;
        final u = (p.authorUsername ?? '').trim().toLowerCase();
        if (u.isEmpty) continue;
        byAuthorUsername.putIfAbsent(u, () => <Post>[]).add(p);
      }

      final Map<int, Post> selected = {};
      for (final f in statuses) {
        final candidates = byAuthorUsername[f.username.trim().toLowerCase()];
        if (candidates == null || candidates.isEmpty) continue;
        final want = (f.statusMessage ?? '').trim();
        Post? best;
        for (final p in candidates) {
          if (want.isNotEmpty && (p.statusMessage ?? '').trim() != want) {
            continue;
          }
          if (best == null || _postSortDate(p).isAfter(_postSortDate(best))) {
            best = p;
          }
        }
        best ??= candidates.reduce((a, b) => _postSortDate(a).isAfter(_postSortDate(b)) ? a : b);
        selected[f.id] = best;
      }

      final Map<int, Post> hydrated = {};
      final futures = <Future<void>>[];
      selected.forEach((friendId, post) {
        futures.add(
          _communityService.fetchPostById(post.id).then((full) {
            hydrated[friendId] = full;
          }).catchError((_) {
            hydrated[friendId] = post;
          }),
        );
      });
      if (futures.isNotEmpty) {
        await Future.wait(futures);
      }

      if (!mounted) return;
      setState(() {
        _statusPostByFriendId
          ..clear()
          ..addAll(hydrated.isEmpty ? selected : hydrated);
      });
    } catch (_) {
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingStatusPosts = false;
        });
      }
    }
  }

  Future<void> _pickAndUploadProfilePic() async {
    if (_updatingProfilePic) return;
    final auth = Provider.of<AuthService>(context, listen: false);
    final me = auth.currentUser;
    if (me == null) return;

    final messenger = ScaffoldMessenger.of(context);

    late final XFile picked;
    if (Platform.isMacOS) {
      try {
        const typeGroup = XTypeGroup(
          label: 'images',
          extensions: ['png', 'jpg', 'jpeg', 'gif', 'webp'],
        );
        final f = await openFile(acceptedTypeGroups: [typeGroup]);
        if (f == null) return;
        picked = f;
      } catch (e) {
        messenger.showSnackBar(
          SnackBar(content: Text('Unable to open file picker: $e')),
        );
        return;
      }
    } else {
      final picker = ImagePicker();
      try {
        final f = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
        if (f == null) return;
        picked = f;
      } catch (e) {
        messenger.showSnackBar(
          SnackBar(content: Text('Unable to open photo picker: $e')),
        );
        return;
      }
    }

    setState(() {
      _updatingProfilePic = true;
    });

    try {
      final currentStatus = (me.statusMessage ?? '').trim();
      await _profileService.saveProfile(currentStatus, picked.path);
      await auth.getProfile();
      if (!mounted) return;
      setState(() {
        _profileImage = File(picked.path);
      });
      messenger.showSnackBar(
        const SnackBar(content: Text('Profile picture updated.')),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Failed to update profile picture: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _updatingProfilePic = false;
        });
      }
    }
  }

  Future<void> _showStatusCommentsSheet(Post post) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        final bottomInset = MediaQuery.of(context).viewInsets.bottom;
        final comments = post.comments;
        final height = MediaQuery.of(context).size.height;
        return Padding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottomInset),
          child: SizedBox(
            height: height * 0.6,
            child: Column(
              mainAxisSize: MainAxisSize.max,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Comments',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              if (comments.isEmpty)
                const Text('No comments yet.')
              else
                Expanded(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: comments.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, i) {
                      final c = comments[i];
                      final flair = _userFlairById[c.authorId];
                      final isPrivate = FlairUtils.isProfilePrivate(flair);
                      final String? pronounsDisplay = isPrivate
                          ? null
                          : (FlairUtils.extractPronouns(flair) ?? '')
                              .split(RegExp(r'[\n,]'))
                              .map((p) => p.trim())
                              .where((p) => p.isNotEmpty)
                              .join(' • ');
                      return Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            DisplayProfilePic(
                              radius: 20,
                              imageUrl: c.authorProfilePic ?? _userPicById[c.authorId],
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    c.authorUsername,
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  if (pronounsDisplay != null && pronounsDisplay.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 2),
                                      child: Text(
                                        pronounsDisplay,
                                        style: Theme.of(context).textTheme.bodySmall,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  const SizedBox(height: 4),
                                  Text(c.content),
                                ],
                              ),
                            ),
                            IconButton(
                              tooltip: 'Report comment',
                              icon: const Icon(Icons.flag_outlined, size: 18),
                              onPressed: () async {
                                await showReportDialog(
                                  context: context,
                                  baseRequest: ReportRequest(
                                    type: ReportTargetType.statusComment,
                                    reason: '',
                                    targetId: c.id,
                                    targetUserId: c.authorId,
                                    targetUsername: c.authorUsername,
                                    details: c.content,
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Close'),
                ),
              ),
            ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final me = Provider.of<AuthService>(context, listen: true).currentUser;
    final isAdmin = me?.username == 'Mad.E' ||
        me?.username == 'Mad.E.Made' ||
        me?.username == 'pmaxwell';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Home'),
        actions: [
          TourAnchor(
            name: 'Settings',
            child: IconButton(
              icon: const Icon(Icons.settings_outlined),
              onPressed: () {
                context.push('/profile/settings');
              },
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadDashboardData,
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            const EmergencyAlertBanner(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                TourAnchor(
                  name: 'Friends',
                  child: GestureDetector(
                    onTap: () {
                      context.push('/chat');
                    },
                    child: Container(
                      width: 110,
                      height: 90,
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.chat, size: 30, color: Colors.grey[600]),
                          const SizedBox(height: 8),
                          Text(
                            'Friends',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                TourAnchor(
                  name: 'No new replies',
                  child: _buildInfoCard(Icons.notifications_none_outlined, 'No new replies'),
                ),
                TourAnchor(
                  name: '$_todaysEventsCount upcoming events',
                  child: _buildInfoCard(
                    Icons.calendar_today_outlined,
                    _isLoading ? '...' : '$_todaysEventsCount upcoming events',
                    onTap: () {
                      context.push('/events/calendar');
                    },
                    isHighlighted: _todaysEventsCount > 0,
                  ),
                ),
              ],
            ),
            if (isAdmin) ...[
              const SizedBox(height: 16),
              TourAnchor(
                name: 'Admin Portal',
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        const Icon(Icons.admin_panel_settings_outlined),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Admin Portal',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                        OutlinedButton(
                          onPressed: () {
                            context.push('/admin/moderation');
                          },
                          child: const Text('Open'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 16),
            TourAnchor(
              name: 'Caches',
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      const Icon(Icons.map_outlined),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Caches',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                      if (isAdmin)
                        IconButton(
                          tooltip: 'Cache Admin',
                          icon: Icon(
                            Icons.admin_panel_settings_outlined,
                            color: _hasUnreadCacheCollections ? Colors.pinkAccent : null,
                          ),
                          onPressed: () async {
                            await context.push('/geocaching/admin');
                            await _loadUnreadCacheCollections();
                          },
                        ),
                      OutlinedButton(
                        onPressed: () {
                          context.push('/geocaching');
                        },
                        child: const Text('Open'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            _buildButterflyPerchSection(),
            Builder(
              builder: (context) {
                final authService = Provider.of<AuthService>(context, listen: false);
                final mutualAid = (FlairUtils.extractMutualAidEmojis(authService.currentUser?.flair) ?? '').trim();
                if (mutualAid.isEmpty) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Center(
                    child: Text(
                      mutualAid,
                      style: Theme.of(context).textTheme.bodyLarge,
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
            TourAnchor(
              name: 'Edit Profile',
              child: _buildEditProfileButton(),
            ),
            const SizedBox(height: 24),
            _buildFriendsStatusUpdates(),
          ],
        ),
      ),
    );
  }

  Widget _buildButterflyPerchSection() {
    final double aspect = (_videoReady && _videoCtrl != null && _videoCtrl!.value.isInitialized && _videoCtrl!.value.aspectRatio > 0)
        ? _videoCtrl!.value.aspectRatio
        : (644 / 144);

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = width / aspect;
        const avatarDiameter = 80.0;
        const overlap = 57.0;
        final sectionHeight = height + avatarDiameter - overlap;

        return SizedBox(
          height: sectionHeight,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: height,
                child: _buildAffirmationGif(),
              ),
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: _buildProfileAvatar(),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAffirmationGif() {
    final double aspect = (_videoReady && _videoCtrl != null && _videoCtrl!.value.isInitialized && _videoCtrl!.value.aspectRatio > 0)
        ? _videoCtrl!.value.aspectRatio
        : (644 / 144);
    final quote = _quote ?? pickRandomQuote();

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = width / aspect;
        final vc = _videoCtrl;
        Rect? hotspotRect;
        double hotspotCenterX = 0;
        double hotspotCenterY = 0;
        String? calibrationText;
        final bool canTrack = _videoReady && vc != null && vc.value.isInitialized;
        final cycle = canTrack ? _effectiveCycleSeconds : _hotspotCycleSeconds;
        final margin = (cycle <= 0 ? 0.0 : (_hotspotMarginSeconds / cycle)).clamp(0.0, 0.45);

        if (_calibrationMode && canTrack) {
          final dur = vc.value.duration;
          final pos = vc.value.position;
          final cycleContentMs = (
            dur.inMilliseconds < (_videoPlaybackSpeed * _hotspotCycleSeconds * 1000)
              ? dur.inMilliseconds
              : (_videoPlaybackSpeed * _hotspotCycleSeconds * 1000).round()
          );
          final double baseP = cycleContentMs == 0 ? 0.0 : pos.inMilliseconds / cycleContentMs;
          final phase = cycle <= 0 ? 0.0 : (_hotspotPhaseOffsetSeconds / cycle);
          final rawP = baseP + phase;
          final p = vc.value.isPlaying
              ? ((rawP % 1.0) == 0.0 && rawP > 0.0 ? 1.0 : (rawP % 1.0))
              : rawP.clamp(0.0, 1.0);
          final Offset center = _samplePath(p);
          final centerX = (margin + center.dx * (1 - 2 * margin)).clamp(0.0, 1.0);
          final centerY = center.dy.clamp(0.0, 1.0);
          hotspotCenterX = centerX;
          hotspotCenterY = centerY;
          final halfW = _hotspotWidthFraction / 2;
          final halfH = _hotspotHeightFraction / 2;
          final left = ((centerX - halfW) * width).clamp(0.0, width);
          final top = ((centerY - halfH) * height).clamp(0.0, height);
          final right = ((centerX + halfW) * width).clamp(0.0, width);
          final bottom = ((centerY + halfH) * height).clamp(0.0, height);
          hotspotRect = Rect.fromLTRB(left, top, right, bottom);
          calibrationText = 'calibration: ON   p=${p.toStringAsFixed(3)}   x=${centerX.toStringAsFixed(3)}   y=${centerY.toStringAsFixed(3)}';
        }

        return FocusableActionDetector(
          enabled: _calibrationMode,
          focusNode: _shortcutFocusNode,
          autofocus: _calibrationMode,
          shortcuts: _calibrationMode
              ? {
                  LogicalKeySet(LogicalKeyboardKey.keyC): const _ToggleCalibrationIntent(),
                  LogicalKeySet(LogicalKeyboardKey.escape): const _ToggleCalibrationIntent(),
                  LogicalKeySet(LogicalKeyboardKey.space): const _ToggleVideoPauseIntent(),
                  LogicalKeySet(LogicalKeyboardKey.arrowLeft): const _SeekBackwardIntent(),
                  LogicalKeySet(LogicalKeyboardKey.arrowRight): const _SeekForwardIntent(),
                  LogicalKeySet(LogicalKeyboardKey.shift, LogicalKeyboardKey.arrowLeft): const _SeekBackwardLargeIntent(),
                  LogicalKeySet(LogicalKeyboardKey.shift, LogicalKeyboardKey.arrowRight): const _SeekForwardLargeIntent(),
                }
              : const <ShortcutActivator, Intent>{},
          actions: {
            _ToggleCalibrationIntent: CallbackAction<_ToggleCalibrationIntent>(
              onInvoke: (intent) {
                _toggleCalibrationMode();
                return null;
              },
            ),
            _ToggleVideoPauseIntent: CallbackAction<_ToggleVideoPauseIntent>(
              onInvoke: (intent) async {
                if (!_calibrationMode) return null;
                final c = _videoCtrl;
                if (c == null || !c.value.isInitialized) return null;
                try {
                  if (c.value.isPlaying) {
                    await c.pause();
                  } else {
                    await c.play();
                  }
                } catch (_) {}
                return null;
              },
            ),
            _SeekBackwardIntent: CallbackAction<_SeekBackwardIntent>(
              onInvoke: (intent) async {
                if (!_calibrationMode) return null;
                final c = _videoCtrl;
                if (c == null || !c.value.isInitialized) return null;
                final cur = c.value.position;
                final next = cur - const Duration(milliseconds: 100);
                try {
                  await c.seekTo(next < Duration.zero ? Duration.zero : next);
                } catch (_) {}
                return null;
              },
            ),
            _SeekForwardIntent: CallbackAction<_SeekForwardIntent>(
              onInvoke: (intent) async {
                if (!_calibrationMode) return null;
                final c = _videoCtrl;
                if (c == null || !c.value.isInitialized) return null;
                final dur = c.value.duration;
                final cur = c.value.position;
                final next = cur + const Duration(milliseconds: 100);
                try {
                  await c.seekTo(next > dur ? dur : next);
                } catch (_) {}
                return null;
              },
            ),
            _SeekBackwardLargeIntent: CallbackAction<_SeekBackwardLargeIntent>(
              onInvoke: (intent) async {
                if (!_calibrationMode) return null;
                final c = _videoCtrl;
                if (c == null || !c.value.isInitialized) return null;
                final cur = c.value.position;
                final next = cur - const Duration(milliseconds: 500);
                try {
                  await c.seekTo(next < Duration.zero ? Duration.zero : next);
                } catch (_) {}
                return null;
              },
            ),
            _SeekForwardLargeIntent: CallbackAction<_SeekForwardLargeIntent>(
              onInvoke: (intent) async {
                if (!_calibrationMode) return null;
                final c = _videoCtrl;
                if (c == null || !c.value.isInitialized) return null;
                final dur = c.value.duration;
                final cur = c.value.position;
                final next = cur + const Duration(milliseconds: 500);
                try {
                  await c.seekTo(next > dur ? dur : next);
                } catch (_) {}
                return null;
              },
            ),
          },
          child: SizedBox(
            width: width,
            height: height,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onLongPress: _toggleCalibrationMode,
              onTapDown: (details) {
                final vc = _videoCtrl;
                final isVideoActive = _videoReady && _animVisible && vc != null && vc.value.isInitialized;
                if (!isVideoActive) {
                  return;
                }

                final dx = details.localPosition.dx / width;
                final dy = details.localPosition.dy / height;
                final cycle = _effectiveCycleSeconds;
                final margin = (cycle <= 0 ? 0.0 : (_hotspotMarginSeconds / cycle)).clamp(0.0, 0.45);

                final dur = vc.value.duration;
                final pos = vc.value.position;
                final cycleContentMs = (
                  dur.inMilliseconds < (_videoPlaybackSpeed * _hotspotCycleSeconds * 1000)
                    ? dur.inMilliseconds
                    : (_videoPlaybackSpeed * _hotspotCycleSeconds * 1000).round()
                );
                final double baseP = cycleContentMs == 0 ? 0.0 : pos.inMilliseconds / cycleContentMs;

                final phase = cycle <= 0 ? 0.0 : (_hotspotPhaseOffsetSeconds / cycle);
                final rawP = baseP + phase;
                final p = vc.value.isPlaying
                    ? ((rawP % 1.0) == 0.0 && rawP > 0.0 ? 1.0 : (rawP % 1.0))
                    : rawP.clamp(0.0, 1.0);

                if (_calibrationMode) {
                  final denom = (1 - 2 * margin);
                  final px = (denom <= 0) ? dx : ((dx - margin) / denom).clamp(0.0, 1.0);
                  final py = dy.clamp(0.0, 1.0);
                  debugPrint('_PathPoint(${p.toStringAsFixed(3)}, ${px.toStringAsFixed(3)}, ${py.toStringAsFixed(3)}),');
                  return;
                }

                final Offset center = _samplePath(p);
                final centerX = margin + center.dx * (1 - 2 * margin);
                final centerY = center.dy;
                final halfW = _hotspotWidthFraction / 2;
                final halfH = _hotspotHeightFraction / 2;
                final inX = (dx - centerX).abs() <= halfW;
                final inY = (dy - centerY).abs() <= halfH;
                final inHotspot = inX && inY;
                if (inHotspot) {
                  _quoteTimer?.cancel();
                  setState(() {
                    _quote = pickRandomQuote();
                    _quoteVisible = true;
                    _animVisible = false;
                    _suppressUntilNextLoop = true;
                  });
                  _quoteTimer = Timer(const Duration(seconds: 10), () {
                    if (!mounted) return;
                    setState(() {
                      _quoteVisible = false;
                      _quote = pickRandomQuote();
                    });
                  });
                }
              },
              child: Stack(
                fit: StackFit.expand,
                children: [
                AnimatedOpacity(
                  duration: const Duration(milliseconds: 500),
                  curve: Curves.easeInOut,
                  opacity: _animVisible ? 1.0 : 0.0,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: _videoReady && _videoCtrl != null && _videoCtrl!.value.isInitialized
                        ? FittedBox(
                            fit: BoxFit.cover,
                            alignment: Alignment.bottomCenter,
                            child: SizedBox(
                              width: _videoCtrl!.value.size.width,
                              height: _videoCtrl!.value.size.height,
                              child: VideoPlayer(_videoCtrl!),
                            ),
                          )
                        : Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                  ),
                ),
                if (_calibrationMode)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: CustomPaint(
                        painter: _HotspotPathPainter(
                          points: _activeHotspotPath,
                          margin: margin,
                          color: const Color(0xFF7C4DFF),
                        ),
                      ),
                    ),
                  ),
                if (_calibrationMode && hotspotRect != null)
                  Positioned(
                    left: hotspotRect.left,
                    top: hotspotRect.top,
                    width: hotspotRect.width,
                    height: hotspotRect.height,
                    child: IgnorePointer(
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.red, width: 2),
                        ),
                      ),
                    ),
                  ),
                if (_calibrationMode && hotspotRect != null)
                  Positioned(
                    left: (hotspotCenterX * width) - 3,
                    top: (hotspotCenterY * height) - 3,
                    width: 6,
                    height: 6,
                    child: IgnorePointer(
                      child: Container(
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ),
                if (_calibrationMode && calibrationText != null)
                  Positioned(
                    left: 8,
                    bottom: 8,
                    child: IgnorePointer(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.black.withAlpha(153),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          calibrationText,
                          style: const TextStyle(color: Colors.white, fontSize: 12),
                        ),
                      ),
                    ),
                  ),
                Positioned(
                  left: 12,
                  right: 12,
                  top: 10,
                  child: IgnorePointer(
                    ignoring: true,
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 600),
                      curve: Curves.easeInOut,
                      opacity: _quoteVisible ? 1.0 : 0.0,
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.deepPurple.withAlpha(217),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '"${quote.text}"',
                              style: const TextStyle(
                                fontSize: 16,
                                fontStyle: FontStyle.italic,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Align(
                              alignment: Alignment.bottomRight,
                              child: Text(
                                '- ${quote.author}',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildInfoCard(IconData icon, String text, {VoidCallback? onTap, bool isHighlighted = false}) {
    final Color backgroundColor = isHighlighted ? AppColors.tertiary : Colors.grey[200]!;
    final Color contentColor = isHighlighted ? AppColors.textWhite : Colors.grey[700]!;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 110,
        height: 90,
        padding: const EdgeInsets.all(8.0),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 30, color: contentColor),
            const SizedBox(height: 8),
            Text(
              text,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: contentColor, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileAvatar() {
    final authService = Provider.of<AuthService>(context, listen: false);
    final currentUser = authService.currentUser;
    final imageUrl = currentUser?.fullProfilePicUrl;

    return Center(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: _updatingProfilePic ? null : _pickAndUploadProfilePic,
          child: Stack(
            alignment: Alignment.bottomRight,
            children: [
              if (_profileImage != null)
                CircleAvatar(
                  radius: 40,
                  backgroundImage: FileImage(_profileImage!),
                )
              else
                DisplayProfilePic(radius: 40, imageUrl: imageUrl),
              if (_updatingProfilePic)
                const Positioned(
                  bottom: 4,
                  right: 4,
                  child: SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              else
                const Positioned(
                  bottom: 2,
                  right: 2,
                  child: CircleAvatar(
                    radius: 12,
                    backgroundColor: Colors.black54,
                    child: Icon(Icons.camera_alt_outlined, size: 14, color: Colors.white),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEditProfileButton() {
    return Center(
      child: ElevatedButton(
        onPressed: () {
          context.push('/profile');
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.secondary,
          foregroundColor: AppColors.textBlack,
          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
        ),
        child: const Text('Edit Profile'),
      ),
    );
  }

  Widget _buildFriendsStatusUpdates() {
    if (_isLoadingFriendFeed) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Friends Status Updates',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        if (_friendStatusFeed.isEmpty)
          const Center(child: Text('No recent status updates.'))
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _friendStatusFeed.length,
            itemBuilder: (context, index) {
              final friend = _friendStatusFeed[index];
              final when = friend.statusUpdatedAt;
              final msg = friend.statusMessage?.trim() ?? '';
              final isPrivate = FlairUtils.isProfilePrivate(friend.flair);
              final String? pronounsDisplay = isPrivate
                  ? null
                  : (FlairUtils.extractPronouns(friend.flair) ?? '')
                      .split(RegExp(r'[\n,]'))
                      .map((p) => p.trim())
                      .where((p) => p.isNotEmpty)
                      .join(' • ');
              return Card(
                margin: const EdgeInsets.only(bottom: 8.0),
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: GestureDetector(
                          onTap: () {
                            context.push('/users/${friend.id}');
                          },
                          child: DisplayProfilePic(radius: 20, imageUrl: friend.fullProfilePicUrl),
                        ),
                        title: GestureDetector(
                          onTap: () {
                            context.push('/users/${friend.id}');
                          },
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(friend.username),
                              if (pronounsDisplay != null && pronounsDisplay.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 2),
                                  child: Text(
                                    pronounsDisplay,
                                    style: Theme.of(context).textTheme.bodySmall,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        subtitle: Text(
                          when == null ? msg : '$msg • ${timeAgo(when)}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Builder(
                            builder: (context) {
                              final p = _statusPostByFriendId[friend.id];
                              final dmCount = _statusDmCommentsByFriendId[friend.id]?.length ?? 0;
                              final count = (p?.comments.length ?? 0) + (p == null ? dmCount : 0);
                              final hasComments = count > 0;
                              return IconButton(
                                icon: const Icon(Icons.add_circle_outline),
                                color: hasComments ? Colors.amber : Colors.grey,
                                onPressed: () async {
                                  if (p != null) {
                                    try {
                                      final refreshed = await _communityService.fetchPostById(p.id);
                                      if (!mounted) return;
                                      setState(() {
                                        _statusPostByFriendId[friend.id] = refreshed;
                                      });
                                      _showStatusCommentsSheet(refreshed);
                                      return;
                                    } catch (_) {
                                      _showStatusCommentsSheet(p);
                                      return;
                                    }
                                  }
                                  await _showStatusDmCommentsSheet(friend);
                                },
                              );
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.flag_outlined),
                            onPressed: () async {
                              final p = _statusPostByFriendId[friend.id];
                              final msg = friend.statusMessage?.trim() ?? '';
                              await showReportDialog(
                                context: context,
                                baseRequest: ReportRequest(
                                  type: ReportTargetType.status,
                                  reason: '',
                                  targetId: p?.id,
                                  targetUserId: friend.id,
                                  targetUsername: friend.username,
                                  details: msg,
                                ),
                              );
                            },
                          ),
                          DisplayProfilePic(
                            radius: 16,
                            imageUrl: Provider.of<AuthService>(context, listen: false).currentUser?.fullProfilePicUrl,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: _ctrlFor(friend.id),
                              decoration: InputDecoration(
                                hintText: "Comment on ${friend.username}'s status...",
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(20)),
                                suffixIcon: IconButton(
                                  icon: const Icon(Icons.arrow_upward_rounded),
                                  color: Colors.red,
                                  onPressed: () async {
                                    final messenger = ScaffoldMessenger.of(context);
                                    final text = _ctrlFor(friend.id).text.trim();
                                    if (text.isEmpty) return;
                                    try {
                                      final post = _statusPostByFriendId[friend.id];
                                      if (post == null) {
                                        await _chatService.sendMessage(
                                          recipientId: friend.id,
                                          content: '$_statusDmPrefix$text',
                                        );
                                        try {
                                          final all = await _chatService.getConversation(friend.id);
                                          final filtered = _filterStatusDmMessages(all);
                                          _statusDmCommentsByFriendId[friend.id] = filtered;
                                          if (mounted) setState(() {});
                                        } catch (_) {}
                                        messenger.showSnackBar(
                                          SnackBar(content: Text('Comment posted on ${friend.username}\'s status')),
                                        );
                                        _ctrlFor(friend.id).clear();
                                        return;
                                      }
                                      await _communityService.addComment(postId: post.id, content: text);
                                      final refreshed = await _communityService.fetchPostById(post.id);
                                      if (!mounted) return;
                                      messenger.showSnackBar(
                                        SnackBar(content: Text('Comment posted on ${friend.username}\'s status')),
                                      );
                                      _ctrlFor(friend.id).clear();
                                      setState(() {
                                        _statusPostByFriendId[friend.id] = refreshed;
                                      });
                                    } catch (e) {
                                      if (!mounted) return;
                                      messenger.showSnackBar(
                                        SnackBar(content: Text('Failed to comment: $e')),
                                      );
                                    }
                                  },
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
      ],
    );
  }

}
