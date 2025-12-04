import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:transconnect/pages/resources/resource_guide_screen.dart';

class ResourcesScreen extends StatefulWidget {
  const ResourcesScreen({super.key});

  @override
  State<ResourcesScreen> createState() => _ResourcesScreenState();
}

class _ResourcesScreenState extends State<ResourcesScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final GlobalKey<ResourceGuideScreenState> _guideKey = GlobalKey<ResourceGuideScreenState>();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 1, vsync: this);
    _tabController.addListener(_handleTabChange);
  }

  void _handleTabChange() {
    if (!mounted) return;
    setState(() {});
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabChange);
    _tabController.dispose();
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
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.menu_book_outlined), text: 'Guide'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _createResource,
        child: const Icon(Icons.add),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          ResourceGuideScreen(key: _guideKey),
        ],
      ),
    );
  }
}

