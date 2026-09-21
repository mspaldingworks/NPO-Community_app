import 'package:flutter/material.dart';

import '../../widgets/placeholder_page.dart';

class UnauthorizedPage extends StatelessWidget {
  const UnauthorizedPage({super.key});

  @override
  Widget build(BuildContext context) => const PlaceholderPage(
    title: 'Unauthorized',
    message:
        'You do not have permission to open this section. Keep client checks in a typed capability service and enforce access server-side.',
  );
}
