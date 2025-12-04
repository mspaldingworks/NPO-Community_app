import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:transconnect/core/services/auth_service.dart';
import 'package:transconnect/core/services/resource_service.dart';
import 'package:transconnect/models/resource.dart';
import 'package:transconnect/models/user.dart';
import 'package:url_launcher/url_launcher.dart';

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

class ResourceGuideScreenState extends State<ResourceGuideScreen> {
  final ResourceService _resourceService = ResourceService();
  late Future<List<Resource>> _resourcesFuture;
  List<Resource> _allResources = [];
  List<Resource> _filteredResources = [];
  final TextEditingController _searchController = TextEditingController();
  List<String> _allTags = [];
  List<String> _popularTags = [];
  final Set<String> _selectedTags = {};

  @override
  void initState() {
    super.initState();
    _resourcesFuture = _fetchAndSetResources();
    _searchController.addListener(_filterResources);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void reloadResources() {
    setState(() {
      _resourcesFuture = _fetchAndSetResources();
    });
  }

  Future<List<Resource>> _fetchAndSetResources() async {
    final resources = await _resourceService.fetchResources();
    if (mounted) {
      // Build tag frequencies
      final Map<String, int> tagCounts = {};
      for (final r in resources) {
        for (final raw in r.tags) {
          final t = raw.trim();
          if (t.isEmpty) continue;
          tagCounts[t] = (tagCounts[t] ?? 0) + 1;
        }
      }

      final allTags = tagCounts.keys.toList()
        ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
      final popularTags = tagCounts.keys.toList()
        ..sort((a, b) => (tagCounts[b] ?? 0).compareTo(tagCounts[a] ?? 0));

      setState(() {
        _allResources = resources;
        _filteredResources = resources;
        _allTags = allTags;
        _popularTags = popularTags.take(10).toList();
      });
    }
    return resources;
  }

  void _filterResources() {
    final query = _searchController.text.toLowerCase().trim();
    final selectedLower = _selectedTags.map((e) => e.toLowerCase()).toSet();

    setState(() {
      _filteredResources = _allResources.where((resource) {
        final nameMatches = (resource.name ?? '').toLowerCase().contains(query);
        final tagsLower = resource.tags.map((t) => t.toLowerCase()).toSet();
        final tagMatches = selectedLower.isEmpty || selectedLower.any((t) => tagsLower.contains(t));
        return nameMatches && tagMatches;
      }).toList();
    });
  }

  void _toggleTag(String tag) {
    if (_selectedTags.contains(tag)) {
      _selectedTags.remove(tag);
    } else {
      _selectedTags.add(tag);
    }
    _filterResources();
  }

  void _setSingleTag(String tag) {
    _selectedTags
      ..clear()
      ..add(tag);
    _filterResources();
  }

  void _clearTags() {
    _selectedTags.clear();
    _filterResources();
  }

  Future<void> _openTagFilterBottomSheet() async {
    final Set<String> temp = {..._selectedTags};
    String tagQuery = '';
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            final filtered = _allTags
                .where((t) => t.toLowerCase().contains(tagQuery.toLowerCase()))
                .toList();
            return SafeArea(
              child: Padding(
                padding: EdgeInsets.only(
                  left: 16,
                  right: 16,
                  top: 16,
                  bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Filter by tags', style: Theme.of(ctx).textTheme.titleLarge),
                    const SizedBox(height: 12),
                    TextField(
                      decoration: const InputDecoration(
                        hintText: 'Search tags...',
                        prefixIcon: Icon(Icons.search),
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (v) => setModalState(() => tagQuery = v),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: SingleChildScrollView(
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final t in filtered)
                              FilterChip(
                                label: Text(t),
                                selected: temp.contains(t),
                                onSelected: (sel) => setModalState(() {
                                  if (sel) temp.add(t); else temp.remove(t);
                                }),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        TextButton(onPressed: () => setModalState(() => temp.clear()), child: const Text('Clear')),
                        ElevatedButton(
                          onPressed: () {
                            Navigator.pop(ctx);
                            setState(() {
                              _selectedTags
                                ..clear()
                                ..addAll(temp);
                            });
                            _filterResources();
                          },
                          child: const Text('Apply'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
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
        } else if (_allResources.isEmpty) {
          return const Center(child: Text('No resources found.'));
        } else {
          return Column(
            children: [
              _buildSearchAndFilter(),
              _buildBrowseCategories(),
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
    const bool isAdmin = false;

    return Card(
      margin: const EdgeInsets.only(bottom: 16.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(resource.name ?? '[No Name]', style: Theme.of(context).textTheme.titleLarge),
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
                  ElevatedButton(
                    onPressed: () => _launchURL(resource.url),
                    child: const Text('More Info'),
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
            Text('Search Resources', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16.0),
            TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                hintText: 'Search by name...',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.search),
              ),
            ),
            const SizedBox(height: 12.0),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Quick filters', style: Theme.of(context).textTheme.titleMedium),
                TextButton(onPressed: _clearTags, child: const Text('Clear')),
              ],
            ),
            const SizedBox(height: 8.0),
            Wrap(
              spacing: 8.0,
              runSpacing: 8.0,
              children: [
                for (final tag in _popularTags)
                  ChoiceChip(
                    label: Text(tag),
                    selected: _selectedTags.contains(tag),
                    onSelected: (_) => _toggleTag(tag),
                  ),
                OutlinedButton.icon(
                  onPressed: _openTagFilterBottomSheet,
                  icon: const Icon(Icons.tune),
                  label: const Text('Filter tags'),
                ),
              ],
            ),
            const SizedBox(height: 8.0),
          ],
        ),
      ),
    );
  }

  Widget _buildBrowseCategories() {
    final categories = [
      _Category(label: 'Healthcare', tag: 'Healthcare', icon: Icons.local_hospital),
      _Category(label: 'Mental Health', tag: 'Mental Health', icon: Icons.psychology),
      _Category(label: 'Legal', tag: 'Legal', icon: Icons.gavel),
      _Category(label: 'Education', tag: 'Education', icon: Icons.school),
      _Category(label: 'Housing', tag: 'Housing', icon: Icons.house),
      _Category(label: 'Crisis Support', tag: 'Crisis support', icon: Icons.sos),
      _Category(label: 'Financial', tag: 'Financial Assistance', icon: Icons.attach_money),
      _Category(label: 'Hotlines', tag: 'Hotline', icon: Icons.phone_in_talk),
      _Category(label: 'Community', tag: 'Community Support', icon: Icons.groups),
      _Category(label: 'Employment', tag: 'Employment', icon: Icons.work),
      _Category(label: 'Advocacy', tag: 'Advocacy', icon: Icons.campaign),
      _Category(label: 'Nutrition', tag: 'Nutrition', icon: Icons.restaurant),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: categories.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 1.2,
        ),
        itemBuilder: (context, index) {
          final c = categories[index];
          return _CategoryCard(
            label: c.label,
            icon: c.icon,
            onTap: () => _setSingleTag(c.tag),
          );
        },
      ),
    );
  }
}
class _Category {
  final String label;
  final String tag;
  final IconData icon;
  _Category({required this.label, required this.tag, required this.icon});
}

class _CategoryCard extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  const _CategoryCard({required this.label, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return InkWell(
      onTap: onTap,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [color.withOpacity(0.15), color.withOpacity(0.35)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
            Center(
              child: Icon(icon, size: 64, color: color.withOpacity(0.7)),
            ),
            Align(
              alignment: Alignment.bottomLeft,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.transparent, Colors.black54],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                child: Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

