import 'package:flutter/material.dart';

import '../../widgets/placeholder_page.dart';

class MemberDirectoryPage extends StatelessWidget {
  const MemberDirectoryPage({super.key});

  @override
  Widget build(BuildContext context) => const PlaceholderPage(
    title: 'Member Directory',
    message: 'Connect this screen to your own member API (not CRM passthrough).',
  );
}
