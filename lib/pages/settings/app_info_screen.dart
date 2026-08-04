import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class AppInfoScreen extends StatelessWidget {
  const AppInfoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Info')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('Welcome to NPO Community', style: textTheme.headlineSmall),
            const SizedBox(height: 12),
            Text(
              'NPO Community is a private workspace for nonprofit volunteers, donors, alumni, partners, committee members, board members, and staff. '
              'It brings coordination, events, resources, and stewardship into one place.',
              style: textTheme.bodyMedium,
            ),
            const SizedBox(height: 20),
            Text('How the app is organized', style: textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              'Use the bottom tabs to move between Community conversations, the Exchange for mutual aid, your Home dashboard, '
              'Resources, and Events. Your Home dashboard is the command center for quick actions, updates, and cards that take '
              'you deeper into the app.',
              style: textTheme.bodyMedium,
            ),
            const SizedBox(height: 20),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Ready for a quick tour?',
                      style: textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'We will highlight the tabs and cards on the Home dashboard so you know where everything lives.',
                      style: textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: () => context.pop(true),
                      child: const Text('Start tour'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => context.pop(false),
              child: const Text('Close'),
            ),
          ],
        ),
      ),
    );
  }
}
