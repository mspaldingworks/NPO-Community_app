import 'package:flutter/material.dart';
import 'package:scoped_model/scoped_model.dart';

import '../../core/state/template_state_model.dart';

class DevPage extends StatelessWidget {
  const DevPage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Dev')),
    body: ScopedModelDescendant<TemplateStateModel>(
      builder: (_, __, model) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Scoped model demo counter: ${model.demoCounter}'),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: model.incrementCounter,
              child: const Text('Increment'),
            ),
          ],
        ),
      ),
    ),
  );
}
