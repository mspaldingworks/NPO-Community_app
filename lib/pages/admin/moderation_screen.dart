import 'package:flutter/material.dart';

class ModerationScreen extends StatelessWidget {
  const ModerationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Moderation')),
      body: const Padding(
        padding: EdgeInsets.all(16),
        child: Text(
          'Moderation is unavailable until server authorization is configured.',
        ),
      ),
    );
  }
}
