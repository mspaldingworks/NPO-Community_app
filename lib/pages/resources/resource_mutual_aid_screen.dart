import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:transconnect/theme/app_theme.dart';

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
            Icon(Icons.handshake, size: 72, color: AppColors.tertiary),
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
                label: const Text('Mutual Aid Form'),
                onPressed: () async {
                  final result = await context.push<bool>('/forms/lgl');
                  if (result == true && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Thanks for submitting the form!')),
                    );
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
