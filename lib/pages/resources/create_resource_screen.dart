import 'package:flutter/material.dart';
import 'package:transconnect/core/services/resource_service.dart';

class CreateResourceScreen extends StatefulWidget {
  const CreateResourceScreen({super.key});

  @override
  State<CreateResourceScreen> createState() => _CreateResourceScreenState();
}

class _CreateResourceScreenState extends State<CreateResourceScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _urlController = TextEditingController();
  final _providerController = TextEditingController();
  final _tagsController = TextEditingController();
  final _resourceService = ResourceService();
  String? _selectedType;
  bool _isPublic = false;
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
    final combined = <String>{..._parseControllerTags(), ..._selectedSuggestedTags};
    _tagsController.text = combined.join(', ');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _urlController.dispose();
    _providerController.dispose();
    _tagsController.dispose();
    super.dispose();
  }

  Future<void> _submitForm() async {
    if (_formKey.currentState!.validate()) {
      if (_selectedType == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a resource type')),
        );
        return;
      }

      setState(() {
        _isLoading = true;
      });

      try {
        final tags = <String>{..._parseControllerTags(), ..._selectedSuggestedTags}.toList();
        // Normalize URL (add https:// if no scheme provided)
        String url = _urlController.text.trim();
        if (url.isNotEmpty && !url.startsWith('http://') && !url.startsWith('https://')) {
          url = 'https://$url';
        }

        await _resourceService.addResource(
          name: _nameController.text,
          description: _descriptionController.text,
          type: _selectedType!,
          url: url,
          public: _isPublic,
          provider: _providerController.text,
          tags: tags,
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Resource added successfully!')),
          );
          Navigator.of(context).pop(true); // Pop with a result to indicate success
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to add resource: $e')),
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
      appBar: AppBar(
        title: const Text('Create New Resource'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
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
              const SizedBox(height: 16.0),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(labelText: 'Description'),
                maxLines: 3,
              ),
              const SizedBox(height: 16.0),
              DropdownButtonFormField<String>(
                value: _selectedType,
                hint: const Text('Select Resource Type'),
                isExpanded: true,
                items: ['Blog', 'Website', 'Video', 'Article', 'Other']
                    .map((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value),
                  );
                }).toList(),
                onChanged: (newValue) {
                  setState(() {
                    _selectedType = newValue;
                  });
                },
                validator: (value) => value == null ? 'Please select a type' : null,
              ),
              const SizedBox(height: 16.0),
              TextFormField(
                controller: _urlController,
                decoration: const InputDecoration(labelText: 'URL'),
                validator: (value) {
                  final v = value?.trim() ?? '';
                  if (v.isEmpty) return 'Please enter a URL';
                  final probe = Uri.tryParse(v.startsWith('http') ? v : 'https://$v');
                  if (probe == null || probe.host.isEmpty) return 'Please enter a valid URL';
                  return null;
                },
              ),
              const SizedBox(height: 16.0),
              TextFormField(
                controller: _providerController,
                decoration: const InputDecoration(labelText: 'Provider'),
              ),
              const SizedBox(height: 16.0),
              TextFormField(
                controller: _tagsController,
                decoration: const InputDecoration(labelText: 'Tags (comma-separated)'),
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
              const SizedBox(height: 16.0),
              SwitchListTile(
                title: const Text('Make Public'),
                value: _isPublic,
                onChanged: (bool value) {
                  setState(() {
                    _isPublic = value;
                  });
                },
              ),
              const SizedBox(height: 24.0),
              ElevatedButton(
                onPressed: _isLoading ? null : _submitForm,
                child: _isLoading
                    ? const CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Colors.white))
                    : const Text('Add Resource'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
