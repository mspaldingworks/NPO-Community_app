import 'package:flutter/material.dart';

import '../../widgets/placeholder_page.dart';

class AuthPage extends StatelessWidget {
  const AuthPage({super.key});

  @override
  Widget build(BuildContext context) => const PlaceholderPage(
    title: 'Auth',
    message: 'Implement sign in, sign up, and password reset with your backend.',
  );
}
