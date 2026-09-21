import 'package:flutter/material.dart';

import '../../widgets/placeholder_page.dart';

class DevToolsPage extends StatelessWidget {
  const DevToolsPage({super.key});

  @override
  Widget build(BuildContext context) => const PlaceholderPage(
    title: 'Developer Tools',
    message: 'Drop in environment toggles, synthetic fixtures, and diagnostics.',
  );
}
