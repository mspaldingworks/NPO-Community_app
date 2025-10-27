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
        final tags = _tagsController.text.split(',').map((s) => s.trim()).toList();

        await _resourceService.addResource(
          name: _nameController.text,
          description: _descriptionController.text,
          type: _selectedType!,
          url: _urlController.text,
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
                decoration: const InputDecoration(labelText: 'Website URL'),
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
