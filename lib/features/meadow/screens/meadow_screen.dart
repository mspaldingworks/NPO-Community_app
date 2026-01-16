import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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

  final _random = Random();
  bool _overlayOpen = false;
  MeadowController? _controller;

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
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    if (controller == null) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.groupName)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return ChangeNotifierProvider.value(
      value: controller,
      child: Scaffold(
        appBar: AppBar(title: Text(widget.groupName)),
        body: LayoutBuilder(
          builder: (context, constraints) {
            final meadowSize = constraints.biggest;
            return Stack(
              children: [
                _MeadowBackground(size: meadowSize),
                Consumer<MeadowController>(
                  builder: (context, meadow, _) {
                    return Stack(
                      children: [
                        for (final flower in meadow.flowers)
                          MeadowFlower(
                            flower: flower,
                            onTap: () => meadow.startFlyTo(flower),
                          ),
                        for (final user in meadow.onlineUsers)
                          MeadowButterfly(
                            key: ValueKey('meadow-butterfly-${user.id}'),
                            user: user,
                            meadowSize: meadowSize,
                            padding: _padding,
                            size: 30,
                            flyToTarget: user.id == meadow.currentUserId
                                ? meadow.flyTarget
                                : null,
                            onArrived: user.id == meadow.currentUserId
                                ? () => _handleArrived(meadow)
                                : null,
                            driftEnabled: widget.enableDrift && !_overlayOpen,
                            flightDuration: widget.flightDuration,
                          ),
                      ],
                    );
                  },
                ),
              ],
            );
          },
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () => _showCreateChat(context),
          backgroundColor: const Color(0xFFFFD166),
          child: const Icon(Icons.add, color: Colors.black87),
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

    await _controller!.createChat(
      topic: parsed.topic,
      description: parsed.description,
      meadowSize: MediaQuery.of(context).size,
      padding: _padding,
    );
  }
}

class _MeadowBackground extends StatelessWidget {
  const _MeadowBackground({required this.size});

  final Size size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size.width,
      height: size.height,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            _MeadowScreenState._backgroundAsset,
            fit: BoxFit.cover,
            alignment: Alignment.center,
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
