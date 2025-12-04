import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:transconnect/pages/resources/resource_guide_screen.dart';

class ResourcesScreen extends StatefulWidget {
  const ResourcesScreen({super.key});

  @override
  State<ResourcesScreen> createState() => _ResourcesScreenState();
}

class _ResourcesScreenState extends State<ResourcesScreen> {
  final GlobalKey<ResourceGuideScreenState> _guideKey = GlobalKey<ResourceGuideScreenState>();

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _createResource() async {
    final result = await context.push<bool>('/resources/create');
    if (result == true) {
      _guideKey.currentState?.reloadResources();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Resource Guide'),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _createResource,
        child: const Icon(Icons.add),
      ),
      body: ResourceGuideScreen(key: _guideKey),
    );
  }
}

