import 'package:flutter/material.dart';
import 'package:npo_community/core/services/resource_service.dart';
import 'package:npo_community/models/resource.dart';

class EditResourceScreen extends StatefulWidget {
  final Resource resource;

  const EditResourceScreen({super.key, required this.resource});

  @override
  _EditResourceScreenState createState() => _EditResourceScreenState();
}

class _EditResourceScreenState extends State<EditResourceScreen> {
  final _formKey = GlobalKey<FormState>();
  final _resourceService = ResourceService();
  late TextEditingController _nameController;
  late TextEditingController _descriptionController;
  late TextEditingController _typeController;
  late TextEditingController _urlController;
  late TextEditingController _providerController;
  late TextEditingController _tagsController;
  late bool _isPublic;
  bool _isLoading = false;
  final List<String> _suggestedTags = const [
    'Youth',
    'Counseling',
    'Non-profit',
    'Mental Health',
    'Healthcare',
    'Legal',
    'Housing',
    'Crisis',
    'Hotline',
    'Support Group',
    'Education',
    'Employment',
    'Food',
    'Shelter',
    'Transportation',
    'Parents & Families',
    'Advocacy',
    'Financial Assistance',
    'LGBTQ+',
    'Trans',
  ];
  final Set<String> _selectedSuggestedTags = {};

  List<String> _parseControllerTags() {
    return _tagsController.text
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
  }

  void _syncTagsController() {
    final combined = <String>{
      ..._parseControllerTags(),
      ..._selectedSuggestedTags,
    };
    _tagsController.text = combined.join(', ');
  }

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.resource.name);
    _descriptionController = TextEditingController(
      text: widget.resource.description,
    );
    _typeController = TextEditingController(text: widget.resource.type);
    _urlController = TextEditingController(text: widget.resource.url);
    _providerController = TextEditingController(text: widget.resource.provider);
    _tagsController = TextEditingController(
      text: widget.resource.tags.join(', '),
    );
    _isPublic = widget.resource.public ?? false;
    final existing = widget.resource.tags.toSet();
    for (final t in _suggestedTags) {
      if (existing.contains(t)) {
        _selectedSuggestedTags.add(t);
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _typeController.dispose();
    _urlController.dispose();
    _providerController.dispose();
    _tagsController.dispose();
    super.dispose();
  }

  Future<void> _updateResource() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      try {
        final updatedResource = Resource(
          id: widget.resource.id,
          name: _nameController.text,
          description: _descriptionController.text,
          type: _typeController.text,
          url: _urlController.text,
          provider: _providerController.text,
          public: _isPublic,
          tags: <String>{
            ..._parseControllerTags(),
            ..._selectedSuggestedTags,
          }.toList(),
        );

        await _resourceService.updateResource(updatedResource);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Resource updated successfully!')),
          );
          Navigator.of(context).pop(true);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to update resource: $e')),
          );
        }
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edit Resource')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Name'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a name';
                  }
                  return null;
                },
              ),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(labelText: 'Description'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a description';
                  }
                  return null;
                },
              ),
              TextFormField(
                controller: _typeController,
                decoration: const InputDecoration(labelText: 'Type'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a type';
                  }
                  return null;
                },
              ),
              TextFormField(
                controller: _urlController,
                decoration: const InputDecoration(labelText: 'URL'),
              ),
              TextFormField(
                controller: _providerController,
                decoration: const InputDecoration(labelText: 'Provider'),
              ),
              TextFormField(
                controller: _tagsController,
                decoration: const InputDecoration(
                  labelText: 'Tags (comma-separated)',
                ),
              ),
              const SizedBox(height: 12.0),
              const Text('Suggested Tags'),
              const SizedBox(height: 8.0),
              Wrap(
                spacing: 8,
                runSpacing: -8,
                children: _suggestedTags.map((tag) {
                  final selected = _selectedSuggestedTags.contains(tag);
                  return FilterChip(
                    label: Text(tag),
                    selected: selected,
                    onSelected: (value) {
                      setState(() {
                        if (value) {
                          _selectedSuggestedTags.add(tag);
                        } else {
                          _selectedSuggestedTags.remove(tag);
                        }
                        _syncTagsController();
                      });
                    },
                  );
                }).toList(),
              ),
              SwitchListTile(
                title: const Text('Make Public'),
                value: _isPublic,
                onChanged: (bool value) {
                  setState(() {
                    _isPublic = value;
                  });
                },
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _isLoading ? null : _updateResource,
                child: _isLoading
                    ? const CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      )
                    : const Text('Save Changes'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
