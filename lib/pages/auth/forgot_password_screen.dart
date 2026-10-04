import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:npo_community/core/services/auth_service.dart';

typedef ResetRequester = Future<void> Function(String email);
typedef ResetConfirmer =
    Future<void> Function({
      required String email,
      required String code,
      required String password,
    });

/// Forgot password: request an emailed code, then enter it with a new
/// password. The server never says whether the email has an account.
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key, this.requestReset, this.confirmReset});

  /// Optional injected calls (used in tests).
  final ResetRequester? requestReset;
  final ResetConfirmer? confirmReset;

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _email = TextEditingController();
  final _code = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _codeSent = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [_email, _code, _password, _confirm]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _request() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await (widget.requestReset ?? AuthService().requestPasswordReset)(
        _email.text.trim(),
      );
      setState(() => _codeSent = true);
    } catch (e) {
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirmReset() async {
    if (_password.text != _confirm.text) {
      setState(() => _error = 'The passwords do not match.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await (widget.confirmReset ?? AuthService().confirmPasswordReset)(
        email: _email.text.trim(),
        code: _code.text.trim(),
        password: _password.text,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Password updated. Sign in with your new password.'),
        ),
      );
      context.go('/login');
    } catch (e) {
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reset password'),
        leading: BackButton(onPressed: () => context.go('/login')),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(
              _codeSent
                  ? 'If that email has an account, a code is on its way. '
                        'Enter it with your new password.'
                  : 'Enter the email on your account and we will send a '
                        'reset code.',
              style: theme.textTheme.bodyLarge,
            ),
            const SizedBox(height: 16),
            TextField(
              key: const Key('reset-email'),
              controller: _email,
              enabled: !_codeSent,
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              decoration: const InputDecoration(labelText: 'Email'),
            ),
            if (_codeSent) ...[
              TextField(
                key: const Key('reset-code'),
                controller: _code,
                textCapitalization: TextCapitalization.characters,
                autocorrect: false,
                decoration: const InputDecoration(
                  labelText: 'Reset code',
                  hintText: 'ABCD-2345',
                ),
              ),
              TextField(
                key: const Key('reset-password'),
                controller: _password,
                obscureText: true,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(labelText: 'New password'),
              ),
              TextField(
                key: const Key('reset-confirm'),
                controller: _confirm,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Confirm new password',
                ),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
            ],
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _busy
                  ? null
                  : _codeSent
                  ? (_password.text.isNotEmpty ? _confirmReset : null)
                  : _request,
              child: _busy
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(_codeSent ? 'Set new password' : 'Send code'),
            ),
            if (_codeSent)
              TextButton(
                onPressed: _busy ? null : _request,
                child: const Text('Send a new code'),
              ),
          ],
        ),
      ),
    );
  }
}
