import 'package:flutter/material.dart';
import 'package:npo_community/theme/app_theme.dart';

class ResourceMutualAidScreen extends StatelessWidget {
  const ResourceMutualAidScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.handshake, size: 72, color: AppColors.tertiary),
            const SizedBox(height: 16),
            Text(
              'Need help? Submit a Mutual Aid request to connect with the community.',
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: 200,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.send),
                label: const Text('Requests unavailable'),
                onPressed: null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
