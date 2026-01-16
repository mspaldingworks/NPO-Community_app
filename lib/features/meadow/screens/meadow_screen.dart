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

  final _random = Random();
  bool _overlayOpen = false;
  MeadowController? _controller;
  String _displayName = '';

  @override
  void initState() {
    super.initState();
    _initialize();
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
        topic: 'Say hi',
        position: const Offset(260, 220),
        createdBy: 'Alex',
        expiresAt: DateTime.now().add(const Duration(hours: 1)),
        participantCount: 0,
      ),
    ];
  }

  @override
  void dispose() {
    if (mounted) {
      context.read<OnboardingTourController>().resetSeenKeyPrefix();
    }
    _controller?.dispose();
    super.dispose();
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
                final sections = max(
                  1,
                  (meadow.flowers.length / MeadowController.flowersPerSection).ceil(),
                );
                final meadowHeight = meadowSize.height * sections;
                final canvasSize = Size(meadowSize.width, meadowHeight);

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
                        for (var i = 0; i < meadow.onlineUsers.length; i++)
                          i == 0
                              ? TourAnchor(
                                  name: 'Meadow butterflies',
                                  child: MeadowButterfly(
                                    key: ValueKey('meadow-butterfly-${meadow.onlineUsers[i].id}'),
                                    user: meadow.onlineUsers[i],
                                    meadowSize: canvasSize,
                                    padding: _padding,
                                    size: 30,
                                    flyToTarget: meadow.onlineUsers[i].id == meadow.currentUserId
                                        ? meadow.flyTarget
                                        : null,
                                    onArrived: meadow.onlineUsers[i].id == meadow.currentUserId
                                        ? () => _handleArrived(meadow)
                                        : null,
                                    onTap: () => _showUserProfile(context, meadow.onlineUsers[i]),
                                    driftEnabled: widget.enableDrift && !_overlayOpen,
                                    flightDuration: widget.flightDuration,
                                  ),
                                )
                              : MeadowButterfly(
                                  key: ValueKey('meadow-butterfly-${meadow.onlineUsers[i].id}'),
                                  user: meadow.onlineUsers[i],
                                  meadowSize: canvasSize,
                                  padding: _padding,
                                  size: 30,
                                  flyToTarget: meadow.onlineUsers[i].id == meadow.currentUserId
                                      ? meadow.flyTarget
                                      : null,
                                  onArrived: meadow.onlineUsers[i].id == meadow.currentUserId
                                      ? () => _handleArrived(meadow)
                                      : null,
                                  onTap: () => _showUserProfile(context, meadow.onlineUsers[i]),
                                  driftEnabled: widget.enableDrift && !_overlayOpen,
                                  flightDuration: widget.flightDuration,
                                ),
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
      topic: parsed.topic,
      description: parsed.description,
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
