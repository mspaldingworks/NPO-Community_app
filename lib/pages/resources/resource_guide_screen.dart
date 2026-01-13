import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:transconnect/core/services/auth_service.dart';
import 'package:transconnect/core/services/resource_service.dart';
import 'package:transconnect/models/resource.dart';
import 'package:transconnect/models/user.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:transconnect/core/services/report_service.dart';
import 'package:transconnect/widgets/report_dialog.dart';
import 'package:transconnect/features/onboarding_tour/widgets/tour_anchor.dart';

Color _getColorFromTag(String tag) {
  final hash = tag.hashCode;
  final r = (hash & 0xFF0000) >> 16;
  final g = (hash & 0x00FF00) >> 8;
  final b = hash & 0x0000FF;
  return Color.fromRGBO(r, g, b, 1);
}

class ResourceGuideScreen extends StatefulWidget {
  const ResourceGuideScreen({super.key});

  @override
  ResourceGuideScreenState createState() => ResourceGuideScreenState();
}

class ResourceGuideScreenState extends State<ResourceGuideScreen> with SingleTickerProviderStateMixin {
  final ResourceService _resourceService = ResourceService();
  late Future<List<Resource>> _resourcesFuture;
  List<Resource> _allResources = [];
  List<Resource> _filteredResources = [];
  Set<int> _favoriteResourceIds = <int>{};
  final TextEditingController _searchController = TextEditingController();
  TabController? _tabController;
  List<String> _tags = [];

  @override
  void initState() {
    super.initState();
    _resourcesFuture = _fetchAndSetResources();
    _loadFavorites();
    _searchController.addListener(_filterResources);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tabController?.removeListener(_handleTabSelection);
    _tabController?.dispose();
    super.dispose();
  }

  void reloadResources() {
    setState(() {
      _resourcesFuture = _fetchAndSetResources();
    });
  }

  Future<void> _loadFavorites() async {
    final ids = await _resourceService.getFavoriteResourceIds();
    if (!mounted) return;
    setState(() {
      _favoriteResourceIds = ids;
    });
    _filterResources();
  }

  Future<List<Resource>> _fetchAndSetResources() async {
    final resources = await _resourceService.fetchResources();
    if (mounted) {
      final allTags = resources
          .expand((r) => r.tags)
          .where((tag) => tag.isNotEmpty)
          .toSet()
          .toList();
      allTags.insert(0, 'All');

      setState(() {
        _allResources = resources;
        _filteredResources = resources;
        _tags = allTags;
        _tabController = TabController(length: _tags.length, vsync: this);
        _tabController!.addListener(_handleTabSelection);
      });

      _filterResources();
    }
    return resources;
  }

  void _handleTabSelection() {
    if (_tabController!.indexIsChanging) {
      _filterResources();
    }
  }

  void _filterResources() {
    final query = _searchController.text.toLowerCase();
    final selectedTag = _tabController != null && _tabController!.index != 0 ? _tags[_tabController!.index] : null;

    final next = _allResources.where((resource) {
      final nameMatches = resource.name?.toLowerCase().contains(query) ?? false;
      final descriptionMatches = resource.description?.toLowerCase().contains(query) ?? false;
      final tagMatches = selectedTag == null || resource.tags.contains(selectedTag);
      return (nameMatches || descriptionMatches) && tagMatches;
    }).toList();

    final ordered = _applyFavoriteOrdering(next);

    setState(() {
      _filteredResources = ordered;
    });
  }

  List<Resource> _applyFavoriteOrdering(List<Resource> resources) {
    if (_favoriteResourceIds.isEmpty) return resources;

    final favorites = <Resource>[];
    final nonFavorites = <Resource>[];
    for (final resource in resources) {
      if (_favoriteResourceIds.contains(resource.id)) {
        favorites.add(resource);
      } else {
        nonFavorites.add(resource);
      }
    }
    return [...favorites, ...nonFavorites];
  }

  Future<void> _toggleFavorite(Resource resource) async {
    final isFavorite = _favoriteResourceIds.contains(resource.id);
    await _resourceService.setResourceFavorite(resourceId: resource.id, isFavorite: !isFavorite);
    await _loadFavorites();
  }

  Future<void> _launchURL(String? urlString) async {
    if (urlString == null) return;
    final Uri url = Uri.parse(urlString);
    if (!await launchUrl(url)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not launch $urlString')),
      );
    }
  }

  Future<void> _deleteResource(int resourceId) async {
    try {
      await _resourceService.deleteResource(resourceId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Resource deleted successfully')),
      );
      setState(() {
        _resourcesFuture = _fetchAndSetResources();
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete resource: $e')),
      );
    }
  }

  void _showDeleteConfirmation(int resourceId) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirm Delete'),
          content: const Text('Are you sure you want to delete this resource? This action cannot be undone.'),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: const Text('Delete', style: TextStyle(color: Colors.red)),
              onPressed: () {
                Navigator.of(context).pop();
                _deleteResource(resourceId);
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<AuthService>(context, listen: false).currentUser;

    return FutureBuilder<List<Resource>>(
      future: _resourcesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        } else if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        } else if (_tabController == null) {
          return const Center(child: Text('No resources found.'));
        } else {
          return Column(
            children: [
              _buildSearchAndFilter(),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16.0),
                  itemCount: _filteredResources.length,
                  itemBuilder: (context, index) {
                    final resource = _filteredResources[index];
                    return _buildResourceCard(resource, user);
                  },
                ),
              ),
            ],
          );
        }
      },
    );
  }

  Widget _buildResourceCard(Resource resource, User? user) {
    final bool isAdmin = user?.isStaff ?? false;
    final isFavorite = _favoriteResourceIds.contains(resource.id);

    return Card(
      margin: const EdgeInsets.only(bottom: 16.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(resource.name ?? '[No Name]', style: Theme.of(context).textTheme.titleLarge),
                ),
                IconButton(
                  tooltip: isFavorite ? 'Unstar' : 'Star',
                  onPressed: () => _toggleFavorite(resource),
                  icon: Icon(
                    isFavorite ? Icons.star : Icons.star_border,
                    color: isFavorite ? Colors.amber : null,
                  ),
                ),
              ],
            ),
            FutureBuilder<bool?>(
              future: _resourceService.getCachedLinkReachable(resource.url),
              builder: (context, snapshot) {
                final reachable = snapshot.data;
                if (reachable != true) return const SizedBox.shrink();

                return Padding(
                  padding: const EdgeInsets.only(top: 6.0),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.verified, size: 18, color: Colors.green),
                      const SizedBox(width: 6),
                      Text(
                        'Verified link',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.green),
                      ),
                    ],
                  ),
                );
              },
            ),
            if (isAdmin)
              Padding(
                padding: const EdgeInsets.only(top: 4.0),
                child: Text('Added by: ${resource.user ?? 'Unknown'}', style: Theme.of(context).textTheme.bodySmall),
              ),
            const SizedBox(height: 8.0),
            Text(resource.description ?? '[No Description]', style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 12.0),
            Wrap(
              spacing: 8.0,
              runSpacing: 4.0,
              children: resource.tags.map((tag) {
                return Chip(
                  label: Text(tag, style: const TextStyle(color: Colors.white)),
                  backgroundColor: _getColorFromTag(tag),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: BorderSide.none,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 12.0),
            Align(
              alignment: Alignment.centerRight,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isAdmin)
                    TextButton(
                      onPressed: () => _showDeleteConfirmation(resource.id),
                      child: const Text('Delete', style: TextStyle(color: Colors.red)),
                    ),
                  if (isAdmin)
                    TextButton(
                      onPressed: () async {
                        final result = await GoRouter.of(context).push<bool>(
                          '/resources/edit',
                          extra: resource,
                        );
                        if (result == true) {
                          setState(() {
                            _resourcesFuture = _fetchAndSetResources();
                          });
                        }
                      },
                      child: const Text('Edit'),
                    ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: () async {
                      await showReportDialog(
                        context: context,
                        baseRequest: ReportRequest(
                          type: ReportTargetType.resource,
                          reason: '',
                          targetId: resource.id,
                          targetUsername: resource.user,
                          targetUrl: resource.url,
                          details: '${resource.name ?? ''}\n\n${resource.description ?? ''}'.trim(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.flag_outlined),
                  ),
                  TourAnchor(
                    name: 'More Info',
                    child: ElevatedButton(
                      onPressed: () => _launchURL(resource.url),
                      child: const Text('More Info'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchAndFilter() {
    return Card(
      margin: const EdgeInsets.all(16.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TourAnchor(
              name: 'Search Resources',
              child: Text('Search Resources', style: Theme.of(context).textTheme.titleLarge),
            ),
            const SizedBox(height: 16.0),
            TourAnchor(
              name: 'Search by keyword...',
              child: TextField(
                controller: _searchController,
                decoration: const InputDecoration(
                  hintText: 'Search by keyword...',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.search),
                ),
              ),
            ),
            const SizedBox(height: 8.0),
            if (_tabController != null)
              Container(
                height: 45,
                margin: const EdgeInsets.only(top: 8.0),
                child: TabBar(
                  controller: _tabController,
                  isScrollable: true,
                  labelColor: Colors.white,
                  unselectedLabelColor: Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black,
                  indicator: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    color: Colors.deepPurple,
                  ),
                  splashBorderRadius: BorderRadius.circular(20),
                  tabs: _tags.map((tag) => Tab(text: tag)).toList(),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
