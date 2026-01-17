import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:transconnect/core/services/auth_service.dart';
import 'package:transconnect/core/utils/flair_utils.dart';
import 'package:transconnect/features/meadow/controllers/meadow_controller.dart';
import 'package:transconnect/features/meadow/data/meadow_repository.dart';
import 'package:transconnect/features/meadow/models/meadow_chat_flower.dart';
import 'package:transconnect/features/meadow/models/online_user.dart';
import 'package:transconnect/features/meadow/services/meadow_alert_service.dart';
import 'package:transconnect/features/meadow/widgets/meadow_butterfly.dart';
import 'package:transconnect/features/meadow/widgets/meadow_chat_overlay.dart';
import 'package:transconnect/features/meadow/widgets/meadow_create_chat_sheet.dart';
import 'package:transconnect/features/meadow/widgets/meadow_flower.dart';
import 'package:transconnect/features/onboarding_tour/controllers/onboarding_tour_controller.dart';
import 'package:transconnect/features/onboarding_tour/widgets/tour_anchor.dart';
import 'package:transconnect/widgets/pronoun_butterfly.dart';

class MeadowScreen extends StatefulWidget {
  const MeadowScreen({
    super.key,
    required this.groupId,
    required this.groupName,
    this.enableDrift = true,
    this.flightDuration = const Duration(milliseconds: 900),
  });

  final int groupId;
  final String groupName;
  final bool enableDrift;
  final Duration flightDuration;

  @override
  State<MeadowScreen> createState() => _MeadowScreenState();
}

class _MeadowScreenState extends State<MeadowScreen> {
  static const _padding = EdgeInsets.all(40);
  static const _backgroundAsset = 'assets/meadow/backgrounds/All Grass.png';
  static const _meadowTourAsset = 'assets/meadow_tour.json';
  static const _leaveFadeDuration = Duration(milliseconds: 900);

  final _random = Random();
  bool _overlayOpen = false;
  MeadowController? _controller;
  String _displayName = '';

  final Map<String, OnlineUser> _leavingUsers = {};
  final Map<String, Timer> _leavingTimers = {};
  Map<String, OnlineUser> _knownUsersById = {};
  Set<String> _activeUserIds = {};
  final Map<String, Offset> _fallbackPositionsByUserId = {};

  @override
  void initState() {
    super.initState();
    _initialize();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Provider.of<MeadowAlertService>(context, listen: false).markAllRead();
    });
  }

  Offset _resolveUserPosition(
    OnlineUser user,
    Size viewportSize,
  ) {
    final pos = user.position;
    final minX = _padding.left + 15;
    final minY = _padding.top + 15;
    final maxX = viewportSize.width - _padding.right - 15;
    final maxY = viewportSize.height - _padding.bottom - 15;

    if (pos.dx > 1 && pos.dy > 1) {
      return Offset(
        pos.dx.clamp(minX, maxX).toDouble(),
        pos.dy.clamp(minY, maxY).toDouble(),
      );
    }

    if (pos.dx > 0 && pos.dx <= 1 && pos.dy > 0 && pos.dy <= 1) {
      return Offset(
        (pos.dx * viewportSize.width).clamp(minX, maxX).toDouble(),
        (pos.dy * viewportSize.height).clamp(minY, maxY).toDouble(),
      );
    }

    return _fallbackPositionsByUserId.putIfAbsent(user.id, () {
      final seeded = Random(user.id.hashCode);
      final dx = minX + seeded.nextDouble() * max(0, maxX - minX);
      final dy = minY + seeded.nextDouble() * max(0, maxY - minY);
      return Offset(dx, dy);
    });
  }

  Offset? _gatherTargetForUser({
    required OnlineUser user,
    required List<MeadowChatFlower> flowers,
    required Size meadowSize,
  }) {
    final chatId = user.activeChatId;
    if (chatId == null) return null;

    MeadowChatFlower? flower;
    for (final f in flowers) {
      if (f.id == chatId) {
        flower = f;
        break;
      }
    }
    if (flower == null) return null;

    final seeded = Random(user.id.hashCode ^ flower.id.hashCode);
    final angle = seeded.nextDouble() * pi * 2;
    final radius = 28 + seeded.nextDouble() * 34;
    final offset = Offset(cos(angle) * radius, sin(angle) * radius);

    final base = flower.position + offset;
    final minX = _padding.left + 15;
    final minY = _padding.top + 15;
    final maxX = meadowSize.width - _padding.right - 15;
    final maxY = meadowSize.height - _padding.bottom - 15;
    return Offset(
      base.dx.clamp(minX, maxX).toDouble(),
      base.dy.clamp(minY, maxY).toDouble(),
    );
  }

  Future<void> _initialize() async {
    final auth = Provider.of<AuthService>(context, listen: false);

    var user = auth.currentUser;
    try {
      user ??= await auth.getCurrentUser();
    } catch (_) {}

    final currentUserId = user?.id.toString() ?? 'meadow-current';
    final currentUserName = user?.username ?? 'You';
    final pronounString = FlairUtils.extractPronouns(user?.flair) ?? '';
    final currentPronouns = _parsePronounList(pronounString);

    _displayName = widget.groupName.toLowerCase().contains('general')
        ? 'The Meadow'
        : widget.groupName;

    final repo = InMemoryMeadowRepository.instance;
    if (!repo.hasSeededUsers) {
      repo.seedUsers(_seedUsers(currentUserId, currentUserName, currentPronouns));
      repo.seedFlowers(_seedFlowers());
    }

    if (!mounted) return;
    final controller = MeadowController(
      repository: repo,
      currentUserId: currentUserId,
      currentUserName: currentUserName,
      currentUserPronouns: currentPronouns,
    )..initialize();

    controller.addListener(_handlePresenceChanges);
    _knownUsersById = {
      for (final u in controller.onlineUsers) u.id: u,
    };
    _activeUserIds = _knownUsersById.keys.toSet();

    setState(() {
      _controller = controller;
    });

    await _maybeStartMeadowTour(currentUserName);
  }

  List<String> _parsePronounList(String raw) {
    return raw
        .split(RegExp(r'[\n,;]'))
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty)
        .take(5)
        .toList();
  }

  List<OnlineUser> _seedUsers(
    String currentUserId,
    String currentUserName,
    List<String> currentPronouns,
  ) {
    final basePronouns = <String>[
      ...currentPronouns,
      'They/Them',
      'She/Her',
      'He/Him',
      'Xe/Xem',
      'Ze/Zir',
      'Fae/Faer',
      'Ae/Aer',
      'Any',
      'No',
    ].where((p) => p.trim().isNotEmpty).toSet().toList();

    List<String> randomSlots() {
      final copy = List<String>.of(basePronouns)..shuffle(_random);
      final count = 3 + _random.nextInt(3);
      return copy.take(min(count, 5)).toList();
    }

    Offset randomPos() => Offset(
          150 + _random.nextDouble() * 200,
          220 + _random.nextDouble() * 260,
        );

    return [
      OnlineUser(
        id: currentUserId,
        name: currentUserName,
        pronounSlots: currentPronouns.isEmpty ? randomSlots() : currentPronouns,
        position: const Offset(180, 240),
        lastSeen: DateTime.now(),
        isCurrentUser: true,
      ),
      OnlineUser(
        id: 'alex',
        name: 'Alex',
        pronounSlots: randomSlots(),
        position: randomPos(),
        lastSeen: DateTime.now(),
      ),
      OnlineUser(
        id: 'morgan',
        name: 'Morgan',
        pronounSlots: randomSlots(),
        position: randomPos(),
        lastSeen: DateTime.now(),
      ),
      OnlineUser(
        id: 'riley',
        name: 'Riley',
        pronounSlots: randomSlots(),
        position: randomPos(),
        lastSeen: DateTime.now(),
      ),
    ];
  }

  List<MeadowChatFlower> _seedFlowers() {
    return [
      MeadowChatFlower(
        id: 'flower-1',
        emoji: '🌼',
        topic: 'Say hi',
        position: const Offset(260, 220),
        createdBy: 'Alex',
        expiresAt: DateTime.now().add(const Duration(hours: 24)),
        participantCount: 0,
      ),
    ];
  }

  @override
  void dispose() {
    if (mounted) {
      context.read<OnboardingTourController>().resetSeenKeyPrefix();
    }
    _controller?.removeListener(_handlePresenceChanges);
    _controller?.dispose();
    for (final timer in _leavingTimers.values) {
      timer.cancel();
    }
    super.dispose();
  }

  void _handlePresenceChanges() {
    final controller = _controller;
    if (controller == null) return;

    final current = <String, OnlineUser>{
      for (final u in controller.onlineUsers) u.id: u,
    };
    final currentIds = current.keys.toSet();
    var changed = false;

    final currentUserId = controller.currentUserId;
    if (!current.containsKey(currentUserId) && _knownUsersById.containsKey(currentUserId)) {
      current[currentUserId] = _knownUsersById[currentUserId]!;
      currentIds.add(currentUserId);
    }

    if (_leavingUsers.containsKey(currentUserId)) {
      _leavingUsers.remove(currentUserId);
      _leavingTimers.remove(currentUserId)?.cancel();
      changed = true;
    }

    final removed = _activeUserIds.difference(currentIds);

    for (final id in removed) {
      final user = _knownUsersById[id] ?? _leavingUsers[id];
      if (user == null) continue;
      if (user.isCurrentUser) continue;
      if (_leavingUsers.containsKey(id)) continue;

      _leavingUsers[id] = user;
      _leavingTimers[id]?.cancel();
      _leavingTimers[id] = Timer(_leaveFadeDuration, () {
        if (!mounted) return;
        setState(() {
          _leavingUsers.remove(id);
          _leavingTimers.remove(id)?.cancel();
        });
      });
      changed = true;
    }

    for (final id in currentIds) {
      if (_leavingUsers.containsKey(id)) {
        _leavingUsers.remove(id);
        _leavingTimers.remove(id)?.cancel();
        changed = true;
      }
    }

    _knownUsersById = current;
    _activeUserIds = currentIds;

    if (changed && mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    if (controller == null) {
      return Scaffold(
        appBar: AppBar(title: Text(_displayName.isEmpty ? widget.groupName : _displayName)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return ChangeNotifierProvider.value(
      value: controller,
      child: Scaffold(
        appBar: AppBar(title: Text(_displayName.isEmpty ? widget.groupName : _displayName)),
        body: LayoutBuilder(
          builder: (context, constraints) {
            final meadowSize = constraints.biggest;
            return Consumer<MeadowController>(
              builder: (context, meadow, _) {
                final onlineUsers = meadow.onlineUsers;
                final currentUserId = meadow.currentUserId;
                final effectiveOnlineUsers = <OnlineUser>[
                  ...onlineUsers,
                  if (!onlineUsers.any((u) => u.id == currentUserId) &&
                      _knownUsersById.containsKey(currentUserId))
                    _knownUsersById[currentUserId]!,
                ];
                final leavingUsers = _leavingUsers.values
                    .where((u) => !effectiveOnlineUsers.any((o) => o.id == u.id))
                    .toList();
                final displayedUsers = [...effectiveOnlineUsers, ...leavingUsers];

                final sections = max(
                  1,
                  (meadow.flowers.length / MeadowController.flowersPerSection).ceil(),
                );
                final meadowHeight = meadowSize.height * sections;
                final canvasSize = Size(meadowSize.width, meadowHeight);

                final butterflyWidgets = <Widget>[];
                for (var i = 0; i < displayedUsers.length; i++) {
                  final user = displayedUsers[i];
                  final isLeaving = user.id != currentUserId &&
                      _leavingUsers.containsKey(user.id) &&
                      !effectiveOnlineUsers.any((o) => o.id == user.id);

                  final gatherTarget = isLeaving
                      ? null
                      : _gatherTargetForUser(
                          user: user,
                          flowers: meadow.flowers,
                          meadowSize: canvasSize,
                        );
                  final resolved = user.copyWith(
                    position: _resolveUserPosition(user, meadowSize),
                  );

                  final flyTarget = user.id == meadow.currentUserId
                      ? (meadow.flyTarget ?? gatherTarget)
                      : gatherTarget;

                  final inChat = gatherTarget != null;

                  final butterfly = MeadowButterfly(
                    key: ValueKey('meadow-butterfly-${user.id}'),
                    user: resolved,
                    meadowSize: canvasSize,
                    padding: _padding,
                    size: 30,
                    isLeaving: isLeaving,
                    onFadeOutComplete: () {
                      if (!mounted) return;
                      setState(() {
                        _leavingUsers.remove(user.id);
                        _leavingTimers.remove(user.id)?.cancel();
                      });
                    },
                    flyToTarget: flyTarget,
                    onArrived: user.id == meadow.currentUserId
                        ? () => _handleArrived(meadow)
                        : null,
                    onTap: isLeaving ? null : () => _showUserProfile(context, resolved),
                    driftEnabled: widget.enableDrift && !_overlayOpen && !isLeaving && !inChat,
                    flightDuration: widget.flightDuration,
                  );

                  butterflyWidgets.add(butterfly);
                }

                return SingleChildScrollView(
                  child: SizedBox(
                    width: meadowSize.width,
                    height: meadowHeight,
                    child: Stack(
                      children: [
                        TourAnchor(
                          name: 'Meadow overview',
                          child: _MeadowBackground(
                            size: meadowSize,
                            sections: sections,
                          ),
                        ),
                        Positioned.fill(
                          child: IgnorePointer(
                            child: TourAnchor(
                              name: 'Meadow butterflies',
                              child: SizedBox.expand(),
                            ),
                          ),
                        ),
                        for (var i = 0; i < meadow.flowers.length; i++)
                          i == 0
                              ? TourAnchor(
                                  name: 'Meadow flowers',
                                  child: MeadowFlower(
                                    flower: meadow.flowers[i],
                                    onTap: () => meadow.startFlyTo(meadow.flowers[i]),
                                  ),
                                )
                              : MeadowFlower(
                                  flower: meadow.flowers[i],
                                  onTap: () => meadow.startFlyTo(meadow.flowers[i]),
                                ),
                        ...butterflyWidgets,
                        Positioned(
                          right: 16,
                          top: meadowSize.height - 80,
                          child: TourAnchor(
                            name: 'Meadow scroll',
                            child: Icon(
                              Icons.unfold_more,
                              color: Colors.white.withOpacity(0.6),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () => _showCreateChat(context),
          backgroundColor: const Color(0xFFFFD166),
          child: const TourAnchor(
            name: 'Meadow create chat',
            child: Icon(Icons.local_florist, color: Colors.black87),
          ),
        ),
      ),
    );
  }

  Future<void> _handleArrived(MeadowController controller) async {
    if (_overlayOpen) return;

    final flower = controller.selectedFlower;
    if (flower == null) return;

    setState(() {
      _overlayOpen = true;
    });

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return SizedBox(
          height: MediaQuery.of(context).size.height * 0.7,
          child: MeadowChatOverlay(
            chatId: flower.id,
            controller: controller,
            onClose: () => Navigator.of(context).pop(),
          ),
        );
      },
    );

    if (mounted) {
      setState(() {
        _overlayOpen = false;
      });
    }

    controller.clearFlight();
  }

  Future<void> _showCreateChat(BuildContext context) async {
    final result = await showModalBottomSheet<Object?>(
      context: context,
      isScrollControlled: true,
      builder: (context) => const MeadowCreateChatSheet(),
    );

    final parsed = parseCreateChatResult(result);
    if (parsed == null) return;

    final controller = _controller!;
    final size = MediaQuery.of(context).size;
    final sections = max(
      1,
      ((controller.flowers.length + 1) / MeadowController.flowersPerSection).ceil(),
    );

    await controller.createChat(
      emoji: parsed.emoji,
      topic: parsed.topic,
      initialComment: parsed.initialComment,
      meadowSize: Size(size.width, size.height * sections),
      padding: _padding,
    );
  }

  Future<void> _maybeStartMeadowTour(String username) async {
    final trimmed = username.trim();
    if (trimmed.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    final seenKey = '${OnboardingTourController.meadowSeenKeyPrefix}$trimmed';
    if (prefs.getBool(seenKey) ?? false) return;

    if (!mounted) return;
    final controller = context.read<OnboardingTourController>();
    controller.setSeenKeyPrefix(OnboardingTourController.meadowSeenKeyPrefix);
    await controller.load(assetPath: _meadowTourAsset);
    if (!mounted || controller.totalSteps == 0) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      controller.startForUser(trimmed);
    });
  }

  Future<void> _showUserProfile(BuildContext context, OnlineUser user) async {
    if (user.isCurrentUser) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 32,
                      backgroundColor: Colors.white,
                      child: PronounButterflyAvatar(
                        pronouns: user.pronounSlots,
                        size: 56,
                        isFlapping: false,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user.name,
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 6,
                            runSpacing: -6,
                            children: user.pronounSlots
                                .map((p) => Chip(
                                      label: Text(p),
                                      visualDensity: VisualDensity.compact,
                                    ))
                                .toList(),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Shareable info',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Last seen: just now',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Message request sent.')),
                          );
                        },
                        icon: const Icon(Icons.chat_bubble_outline),
                        label: const Text('Message'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Friend request sent.')),
                          );
                        },
                        icon: const Icon(Icons.person_add_alt_1),
                        label: const Text('Friend request'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _MeadowBackground extends StatelessWidget {
  const _MeadowBackground({
    required this.size,
    required this.sections,
  });

  final Size size;
  final int sections;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size.width,
      height: size.height * sections,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Column(
            children: List.generate(
              sections,
              (index) => SizedBox(
                height: size.height,
                width: size.width,
                child: index.isOdd
                    ? Transform(
                        alignment: Alignment.center,
                        transform: Matrix4.rotationX(pi),
                        child: Image.asset(
                          _MeadowScreenState._backgroundAsset,
                          fit: BoxFit.cover,
                        ),
                      )
                    : Image.asset(
                        _MeadowScreenState._backgroundAsset,
                        fit: BoxFit.cover,
                      ),
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.black.withOpacity(0.10),
                  Colors.black.withOpacity(0.22),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
