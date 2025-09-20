import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:transconnect/models/resource.dart';
import 'package:transconnect/core/services/resource_service.dart';
import 'package:url_launcher/url_launcher.dart';

class ResourcesScreen extends StatefulWidget {
  const ResourcesScreen({super.key});

  @override
  State<ResourcesScreen> createState() => _ResourcesScreenState();
}

class _ResourcesScreenState extends State<ResourcesScreen> {
  final ResourceService _resourceService = ResourceService();
  late Future<List<Resource>> _resourcesFuture;
  List<Resource> _allResources = [];
  List<Resource> _filteredResources = [];
  final TextEditingController _searchController = TextEditingController();
  String? _selectedTag;

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

  Future<List<Resource>> _fetchAndSetResources() async {
    final resources = await _resourceService.fetchResources();
    if (mounted) {
      setState(() {
        _allResources = resources;
        _filteredResources = resources;
      });
    }
    return resources;
  }

  void _filterResources() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredResources = _allResources.where((resource) {
        final nameMatches = resource.name?.toLowerCase().contains(query) ?? false;
        final descriptionMatches = resource.description?.toLowerCase().contains(query) ?? false;
        final tagMatches = _selectedTag == null || resource.tags.contains(_selectedTag);
        return (nameMatches || descriptionMatches) && tagMatches;
      }).toList();
    });
  }

  void _selectTag(String? tag) {
    setState(() {
      _selectedTag = tag;
    });
    _filterResources();
  }

  Future<void> _launchURL(String? urlString) async {
    if (urlString == null) return;
    final Uri url = Uri.parse(urlString);
    if (!await launchUrl(url)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not launch $urlString')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Resource Guide'),
        elevation: 0,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        foregroundColor: Theme.of(context).textTheme.bodyLarge?.color,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await GoRouter.of(context).push<bool>('/resources/create');
          if (result == true) {
            // Refresh the list if a new resource was added
            setState(() {
              _resourcesFuture = _fetchAndSetResources();
            });
          }
        },
        child: const Icon(Icons.add),
      ),
      body: FutureBuilder<List<Resource>>(
        future: _resourcesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No resources found.'));
          } else {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  ..._filteredResources.map((resource) => _buildResourceCard(resource)).toList(),
                  _buildSearchCard(),
                ],
              ),
            );
          }
        },
      ),
    );
  }

  Widget _buildResourceCard(Resource resource) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(resource.name ?? '[No Name]', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8.0),
            Text(resource.description ?? '[No Description]', style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 8.0),
            Text('Provider: ${resource.provider ?? 'N/A'}', style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 12.0),
            Wrap(
              spacing: 8.0,
              runSpacing: 4.0,
              children: resource.tags.map((tag) => Chip(label: Text(tag))).toList(),
            ),
            const SizedBox(height: 12.0),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton(
                onPressed: () => _launchURL(resource.url),
                child: const Text('More Info'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchCard() {
    final allTags = _allResources.expand((r) => r.tags).toSet().toList();

    return Card(
      margin: const EdgeInsets.only(top: 16.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Search Resources', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16.0),
            TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                hintText: 'Search resources...',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.search),
              ),
            ),
            const SizedBox(height: 16.0),
            Wrap(
              spacing: 8.0,
              children: [
                ChoiceChip(
                  label: const Text('All'),
                  selected: _selectedTag == null,
                  onSelected: (selected) => _selectTag(null),
                ),
                ...allTags.map((tag) => ChoiceChip(
                  label: Text(tag),
                  selected: _selectedTag == tag,
                  onSelected: (selected) => _selectTag(tag),
                )).toList(),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
