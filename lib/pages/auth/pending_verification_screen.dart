import 'package:flutter/material.dart';
import 'package:npo_community/core/services/auth_service.dart';

/// Shown to a self-signup until a moderator verifies her (or links her to
/// her Emerge Kentucky alumnae roster record). The router sends verified
/// accounts on to Home as soon as a refresh sees the change.
class PendingVerificationScreen extends StatefulWidget {
  const PendingVerificationScreen({super.key, this.refresh, this.signOut});

  /// Optional injected calls (used in tests).
  final Future<void> Function()? refresh;
  final Future<void> Function()? signOut;

  @override
  State<PendingVerificationScreen> createState() =>
      _PendingVerificationScreenState();
}

class _PendingVerificationScreenState extends State<PendingVerificationScreen> {
  bool _checking = false;

  Future<void> _checkAgain() async {
    setState(() => _checking = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await (widget.refresh ?? AuthService().refreshCurrentUser)();
      // A verified account is redirected home by the router; only say
      // "still waiting" when that's true.
      if (AuthService().realUser?.isAwaitingVerification ?? true) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Still waiting for verification.')),
        );
      }
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not reach the server.')),
      );
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Almost there')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const Icon(Icons.hourglass_top, size: 56),
            const SizedBox(height: 16),
            Text(
              'Your account is waiting for verification',
              style: theme.textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            const Text(
              'This app is for Emerge Kentucky alumnae. A moderator will match '
              'your account to the alumnae roster, usually within a few days. '
              'If Emerge Kentucky sent you a claim code, sign out and use '
              '"Claim your profile" instead.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _checking ? null : _checkAgain,
              child: const Text('Check again'),
            ),
            TextButton(
              onPressed: () => (widget.signOut ?? AuthService().signOut)(),
              child: const Text('Sign out'),
            ),
          ],
        ),
      ),
    );
  }
}
