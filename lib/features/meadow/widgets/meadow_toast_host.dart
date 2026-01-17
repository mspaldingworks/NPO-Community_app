import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:transconnect/features/meadow/data/meadow_repository.dart';
import 'package:transconnect/features/meadow/models/meadow_chat_flower.dart';
import 'package:transconnect/features/meadow/services/meadow_alert_service.dart';

class MeadowToastHost extends StatefulWidget {
  const MeadowToastHost({
    super.key,
    required this.child,
    required this.scaffoldMessengerKey,
  });

  final Widget child;
  final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey;

  @override
  State<MeadowToastHost> createState() => _MeadowToastHostState();
}

class _MeadowToastHostState extends State<MeadowToastHost> {
  StreamSubscription<MeadowChatFlower>? _subscription;

  @override
  void initState() {
    super.initState();
    _subscription = InMemoryMeadowRepository.instance
        .watchChatCreated()
        .listen(_handleChatCreated);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  void _handleChatCreated(MeadowChatFlower chat) {
    if (!mounted) return;

    final alertService = Provider.of<MeadowAlertService>(
      context,
      listen: false,
    );
    alertService.registerNewChat(chat);

    final messenger = widget.scaffoldMessengerKey.currentState;
    messenger?.hideCurrentSnackBar();

    final message = 'New Meadow chat: ${chat.emoji} ${chat.topic}';

    messenger?.showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 7),
        content: Row(
          children: [
            const Icon(Icons.local_florist, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        action: SnackBarAction(
          label: 'Dismiss',
          onPressed: () {
            messenger.hideCurrentSnackBar();
          },
          textColor: Colors.white,
        ),
        backgroundColor: Colors.green.shade700,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
