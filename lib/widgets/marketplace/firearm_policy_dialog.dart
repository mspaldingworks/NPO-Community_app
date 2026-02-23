import 'package:flutter/material.dart';

class FirearmPolicyDialog extends StatefulWidget {
  const FirearmPolicyDialog({super.key});

  @override
  State<FirearmPolicyDialog> createState() => _FirearmPolicyDialogState();
}

class _FirearmPolicyDialogState extends State<FirearmPolicyDialog> {
  bool _agreed = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Marketplace Safety Policy'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Firearm listings are strictly prohibited on this marketplace. '
              'Do not create posts to sell, trade, transfer, request, or advertise guns, '
              'gun parts intended to assemble firearms, or ammunition.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            const Text(
              'Accounts that violate this policy may be suspended or permanently banned.',
            ),
            const SizedBox(height: 12),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _agreed,
              title: const Text(
                'I understand and agree not to post firearm-related listings.',
              ),
              onChanged: (value) {
                setState(() {
                  _agreed = value ?? false;
                });
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _agreed ? () => Navigator.of(context).pop(true) : null,
          child: const Text('Agree & Continue'),
        ),
      ],
    );
  }
}
