import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:transconnect/features/geocaching/repositories/geocache_repository.dart';
import 'package:transconnect/features/geocaching/utils/cache_password.dart';
import 'package:transconnect/pages/resources/resource_guide_screen.dart';

class _UnlockResult {
  final String cacheId;
  final String passwordHash;

  const _UnlockResult({required this.cacheId, required this.passwordHash});
}

class ResourcesScreen extends StatefulWidget {
  const ResourcesScreen({super.key});

  @override
  State<ResourcesScreen> createState() => _ResourcesScreenState();
}

class _ResourcesScreenState extends State<ResourcesScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final GlobalKey<ResourceGuideScreenState> _guideKey = GlobalKey<ResourceGuideScreenState>();
  int _lastContentTabIndex = 0;

  static String _unlockKey(String id) => 'cache_unlocked_hash_$id';

  Future<_UnlockResult?> _promptForCachePassword() async {
    final repo = Provider.of<GeocacheRepository>(context, listen: false);

    final ctrl = TextEditingController();
    String? error;
    bool working = false;

    try {
      return await showDialog<_UnlockResult>(
        context: context,
        builder: (dialogContext) {
          return StatefulBuilder(
            builder: (dialogContext, setDialogState) {
              Future<void> handleSubmit() async {
                final password = ctrl.text.trim();
                if (password.isEmpty) {
                  setDialogState(() => error = 'Enter a password.');
                  return;
                }

                setDialogState(() {
                  working = true;
                  error = null;
                });

                try {
                  final caches = await repo.getAllOnce();
                  final found = caches
                      .where(
                        (c) => verifyCachePassword(
                          cacheId: c.id,
                          password: password,
                          passwordHash: c.passwordHash,
                        ),
                      )
                      .toList();

                  if (!dialogContext.mounted) return;

                  if (found.isEmpty) {
                    setDialogState(() {
                      working = false;
                      error = 'No cache found for that password.';
                    });
                    return;
                  }

                  if (found.length != 1) {
                    setDialogState(() {
                      working = false;
                      error = 'That password matches multiple caches.';
                    });
                    return;
                  }

                  Navigator.of(dialogContext).pop(
                    _UnlockResult(cacheId: found.first.id, passwordHash: found.first.passwordHash),
                  );
                  return;
                } catch (e) {
                  if (!dialogContext.mounted) return;
                  setDialogState(() {
                    working = false;
                    error = e.toString();
                  });
                }
              }

              return AlertDialog(
                title: const Text('Enter cache password'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: ctrl,
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: 'Password',
                        border: const OutlineInputBorder(),
                        errorText: error,
                      ),
                      onSubmitted: working ? null : (_) => handleSubmit(),
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: working ? null : () => Navigator.of(dialogContext).pop(null),
                    child: const Text('Cancel'),
                  ),
                  FilledButton(
                    onPressed: working ? null : handleSubmit,
                    child: working
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Continue'),
                  ),
                ],
              );
            },
          );
        },
      );
    } finally {
      ctrl.dispose();
    }
  }

  Future<void> _handleLockTap() async {
    _tabController.animateTo(_lastContentTabIndex);

    final result = await _promptForCachePassword();
    if (result == null) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_unlockKey(result.cacheId), result.passwordHash);
    if (!mounted) return;

    await context.push('/geocaching/cache/${result.cacheId}');
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_handleTabChange);
  }

  void _handleTabChange() {
    if (!mounted) return;
    if (_tabController.index != 1) {
      _lastContentTabIndex = _tabController.index;
    }
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
        actions: [
          IconButton(
            icon: const Icon(Icons.route),
            tooltip: 'Plan your migration',
            onPressed: () => context.push('/resources/migration'),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          onTap: (index) async {
            if (index != 1) return;

            await _handleLockTap();
          },
          tabs: const [
            Tab(icon: Icon(Icons.menu_book_outlined), text: 'Guide'),
            Tab(icon: Icon(Icons.lock_outline)),
          ],
        ),
      ),
      floatingActionButton: _tabController.index == 0
          ? FloatingActionButton(
              onPressed: _createResource,
              child: const Icon(Icons.add),
            )
          : null,
      body: TabBarView(
        controller: _tabController,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          ResourceGuideScreen(key: _guideKey),
          const SizedBox.shrink(),
        ],
      ),
    );
  }
}

