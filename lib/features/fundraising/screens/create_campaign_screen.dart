import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:npo_community/features/fundraising/fundraising_controller.dart';

class CreateCampaignScreen extends StatefulWidget {
  const CreateCampaignScreen({required this.controller, super.key});

  final FundraisingController controller;

  @override
  State<CreateCampaignScreen> createState() => _CreateCampaignScreenState();
}

class _CreateCampaignScreenState extends State<CreateCampaignScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _subtitleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _goalController = TextEditingController();
  String _type = 'fundraiser';
  DateTime? _endDate;
  bool _submitting = false;

  static const _campaignTypes = [
    ('fundraiser', 'Fundraiser'),
    ('events', 'Event'),
    ('giving-day', 'Giving Day'),
    ('auction', 'Auction'),
    ('peer-to-peer', 'Peer-to-Peer'),
  ];

  @override
  void dispose() {
    _titleController.dispose();
    _subtitleController.dispose();
    _descriptionController.dispose();
    _goalController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New Campaign')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            20,
            20,
            20,
            MediaQuery.viewInsetsOf(context).bottom + 32,
          ),
          children: [
            TextFormField(
              controller: _titleController,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Campaign title *'),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Title is required' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _subtitleController,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Subtitle',
                hintText: 'Optional tagline',
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _descriptionController,
              textCapitalization: TextCapitalization.sentences,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Description',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _goalController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                labelText: 'Goal amount (USD)',
                prefixText: r'$',
                hintText: 'Optional',
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _type,
              decoration: const InputDecoration(labelText: 'Campaign type'),
              items: _campaignTypes
                  .map((t) => DropdownMenuItem(value: t.$1, child: Text(t.$2)))
                  .toList(),
              onChanged: (v) => _type = v ?? 'fundraiser',
            ),
            const SizedBox(height: 16),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('End date'),
              subtitle: Text(
                _endDate != null
                    ? DateFormat.yMMMd().format(_endDate!)
                    : 'No end date',
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_endDate != null)
                    IconButton(
                      icon: const Icon(Icons.clear),
                      tooltip: 'Clear date',
                      onPressed: () => setState(() => _endDate = null),
                    ),
                  IconButton(
                    icon: const Icon(Icons.calendar_today),
                    tooltip: 'Pick date',
                    onPressed: _pickDate,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            FilledButton(
              onPressed: _submitting ? null : _submit,
              child: _submitting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Create on Givebutter'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate ?? now.add(const Duration(days: 30)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365 * 5)),
    );
    if (picked != null) setState(() => _endDate = picked);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    try {
      final goalText = _goalController.text.trim();
      await widget.controller.createCampaign(
        title: _titleController.text.trim(),
        subtitle: _subtitleController.text.trim().isEmpty
            ? null
            : _subtitleController.text.trim(),
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        goal: goalText.isEmpty ? null : int.tryParse(goalText),
        type: _type,
        endAt: _endDate?.toIso8601String(),
      );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }
}
