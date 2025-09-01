import 'package:flutter/material.dart';
import 'package:transconnect/core/services/resource_service.dart';
import 'package:transconnect/features/resources/dialogs/add_resource_dialog.dart';
import 'package:transconnect/features/resources/models/resource_model.dart';
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
  bool _isSearching = false;

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
        final nameMatches = resource.name.toLowerCase().contains(query);
        final descriptionMatches = resource.description.toLowerCase().contains(query);
        return nameMatches || descriptionMatches;
      }).toList();
    });
  }

  void _refreshResources() {
    setState(() {
      _resourcesFuture = _fetchAndSetResources();
    });
  }

  void _showAddResourceDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return const AddResourceDialog();
      },
    ).then((value) {
      // Refresh the list if a resource was added
      if (value == true) {
        _refreshResources();
      }
    });
  }

  Future<void> _launchURL(String urlString) async {
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
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Search resources...',
                  border: InputBorder.none,
                ),
              )
            : const Text('Resource Guide'),
        actions: [
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search),
            onPressed: () {
              setState(() {
                _isSearching = !_isSearching;
                if (!_isSearching) {
                  _searchController.clear();
                }
              });
            },
          ),
        ],
      ),
      body: FutureBuilder<List<Resource>>(
        future: _resourcesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (_filteredResources.isEmpty) {
            return const Center(child: Text('No resources found.'));
          }

          return ListView.builder(
            itemCount: _filteredResources.length,
            itemBuilder: (context, index) {
              final resource = _filteredResources[index];
              return ListTile(
                title: Text(resource.name),
                subtitle: Text(resource.description),
                trailing: resource.website != null && resource.website!.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.open_in_new),
                        onPressed: () => _launchURL(resource.website!),
                      )
                    : null,
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddResourceDialog,
        child: const Icon(Icons.add),
        tooltip: 'Add a Resource',
      ),
    );
  }
}
