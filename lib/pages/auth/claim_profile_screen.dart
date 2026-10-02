import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:npo_community/core/services/auth_service.dart';

typedef ClaimChecker =
    Future<Map<String, dynamic>> Function({
      required String code,
      required String email,
    });
typedef ClaimRedeemer =
    Future<void> Function({
      required String code,
      required String email,
      required String password,
      required bool adultAttestation,
      required bool conductPolicyAccepted,
    });

/// Claim a seeded Emerge Kentucky alumna profile with the code staff sent.
///
/// Step 1 checks the code and email and shows whose profile it is; step 2
/// sets a password and takes the same attestations as signup, then signs in.
class ClaimProfileScreen extends StatefulWidget {
  const ClaimProfileScreen({super.key, this.checkClaim, this.redeemClaim});

  /// Optional injected calls (used in tests).
  final ClaimChecker? checkClaim;
  final ClaimRedeemer? redeemClaim;

  @override
  State<ClaimProfileScreen> createState() => _ClaimProfileScreenState();
}

class _ClaimProfileScreenState extends State<ClaimProfileScreen> {
  final _email = TextEditingController();
  final _code = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  Map<String, dynamic>? _profile;
  bool _adult = false;
  bool _conduct = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    for (final controller in [_email, _code, _password, _confirm]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _check() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final check = widget.checkClaim ?? AuthService().checkClaim;
      final profile = await check(
        code: _code.text.trim(),
        email: _email.text.trim(),
      );
      setState(() => _profile = profile);
    } catch (e) {
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _claim() async {
    if (_password.text != _confirm.text) {
      setState(() => _error = 'The passwords do not match.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final redeem = widget.redeemClaim ?? AuthService().signInWithClaim;
      await redeem(
        code: _code.text.trim(),
        email: _email.text.trim(),
        password: _password.text,
        adultAttestation: _adult,
        conductPolicyAccepted: _conduct,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Welcome! You can sign in as ${_profile?['username'] ?? 'your username'} from now on.',
          ),
        ),
      );
      context.go('/home');
    } catch (e) {
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final profile = _profile;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Claim your profile'),
        leading: BackButton(onPressed: () => context.go('/login')),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(
              profile == null
                  ? 'Emerge Kentucky sent you a claim code. Enter it with the '
                        'email it was sent to.'
                  : 'Welcome, ${profile['display_name']}'
                        '${profile['program_year'] != null ? ' (Class of ${profile['program_year']})' : ''}! '
                        'You will sign in as ${profile['username']}.',
              style: theme.textTheme.bodyLarge,
            ),
            const SizedBox(height: 16),
            TextField(
              key: const Key('claim-email'),
              controller: _email,
              enabled: profile == null,
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              decoration: const InputDecoration(labelText: 'Email'),
            ),
            TextField(
              key: const Key('claim-code'),
              controller: _code,
              enabled: profile == null,
              textCapitalization: TextCapitalization.characters,
              autocorrect: false,
              decoration: const InputDecoration(
                labelText: 'Claim code',
                hintText: 'ABCD-2345',
              ),
            ),
            if (profile != null) ...[
              TextField(
                key: const Key('claim-password'),
                controller: _password,
                obscureText: true,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  labelText: 'Choose a password',
                ),
              ),
              TextField(
                key: const Key('claim-confirm'),
                controller: _confirm,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Confirm password',
                ),
              ),
              CheckboxListTile(
                key: const Key('claim-adult'),
                contentPadding: EdgeInsets.zero,
                value: _adult,
                onChanged: (v) => setState(() => _adult = v ?? false),
                title: const Text('I am 18 or older'),
              ),
              CheckboxListTile(
                key: const Key('claim-conduct'),
                contentPadding: EdgeInsets.zero,
                value: _conduct,
                onChanged: (v) => setState(() => _conduct = v ?? false),
                title: const Text('I agree to the community conduct policy'),
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
                  : profile == null
                  ? _check
                  : (_adult && _conduct && _password.text.isNotEmpty
                        ? _claim
                        : null),
              child: _busy
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(profile == null ? 'Continue' : 'Claim my profile'),
            ),
          ],
        ),
      ),
    );
  }
}
