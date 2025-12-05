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

  @override
  void initState() {
    super.initState();
    _tagsController.addListener(() {
      // Rebuild so the Selected Tags chips reflect manual edits
      setState(() {});
    });
  }

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

  Color _colorForTag(String tag) {
    // Derive a stable, high-contrast color per tag using HSL
    final hash = tag.hashCode & 0xFFFFFF;
    final hue = (hash % 360).toDouble();
    // Ensure strong saturation and darker lightness for white text contrast
    final hsl = HSLColor.fromAHSL(1.0, hue, 0.72, 0.42);
    return hsl.toColor();
  }

  void _removeTag(String tag) {
    final controllerTags = _parseControllerTags().toSet();
    controllerTags.remove(tag);
    _selectedSuggestedTags.remove(tag);
    _tagsController.text = controllerTags.join(', ');
    setState(() {});
  }

  Future<void> _openTagsPicker() async {
    final initial = <String>{..._selectedSuggestedTags, ..._parseControllerTags()};
    final picked = await showModalBottomSheet<Set<String>>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        final temp = Set<String>.from(initial);
        return StatefulBuilder(
          builder: (context, setModalState) {
            return SafeArea(
              child: Padding(
                padding: EdgeInsets.only(
                  left: 16,
                  right: 16,
                  top: 16,
                  bottom: MediaQuery.of(context).viewInsets.bottom + 16,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text('Select Tags', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        const Spacer(),
                        TextButton(
                          onPressed: () => setModalState(() => temp.clear()),
                          child: const Text('Clear all'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SingleChildScrollView(
                      child: Wrap(
                        spacing: 8,
                        runSpacing: -8,
                        children: _suggestedTags.map((tag) {
                          final selected = temp.contains(tag);
                          final color = _colorForTag(tag);
                          return FilterChip(
                            label: Text(
                              tag,
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                            ),
                            selected: selected,
                            selectedColor: color,
                            // Use a slightly lighter (but still saturated) variant for unselected state
                            backgroundColor: HSLColor.fromColor(color).withLightness(0.50).toColor(),
                            shape: const StadiumBorder(),
                            checkmarkColor: Colors.white,
                            onSelected: (value) => setModalState(() {
                              if (value) {
                                temp.add(tag);
                              } else {
                                temp.remove(tag);
                              }
                            }),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).colorScheme.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () => Navigator.of(context).pop(temp),
                        child: const Text('Done'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
    if (picked != null) {
      setState(() {
        _selectedSuggestedTags
          ..clear()
          ..addAll(picked);
        _syncTagsController();
      });
    }
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
              // Multi-select dropdown-style control
              Builder(builder: (context) {
                final selectedAll = <String>{..._parseControllerTags(), ..._selectedSuggestedTags}.toList();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    InkWell(
                      onTap: _openTagsPicker,
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Select Tags',
                          border: OutlineInputBorder(),
                          suffixIcon: Icon(Icons.arrow_drop_down),
                        ),
                        child: Text(
                          selectedAll.isEmpty ? 'Choose one or more' : '${selectedAll.length} selected',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                    ),
                  ],
                );
              }),
              const SizedBox(height: 12.0),
              // Selected tags as removable, colored chips
              Builder(builder: (context) {
                final selectedAll = <String>{..._parseControllerTags(), ..._selectedSuggestedTags}.toList();
                if (selectedAll.isEmpty) return const SizedBox.shrink();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Selected Tags', style: Theme.of(context).textTheme.labelLarge),
                    const SizedBox(height: 8.0),
                    Wrap(
                      spacing: 8,
                      runSpacing: -8,
                      children: selectedAll.map((tag) {
                        final color = _colorForTag(tag);
                        return InputChip(
                          label: Text(tag, style: const TextStyle(color: Colors.white)),
                          backgroundColor: color,
                          onDeleted: () => _removeTag(tag),
                          deleteIconColor: Colors.white,
                        );
                      }).toList(),
                    ),
                  ],
                );
              }),
              const SizedBox(height: 8.0),
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
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
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
