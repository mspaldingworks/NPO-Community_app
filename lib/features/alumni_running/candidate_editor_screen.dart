import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:npo_community/features/alumni_running/campaign_hub_controller.dart';
import 'package:npo_community/features/alumni_running/models/alumni_candidate.dart';
import 'package:npo_community/features/alumni_running/models/candidate_draft.dart';

/// Staff form for adding or editing a candidate card.
///
/// Shown only when [CampaignCapabilities.canManageCandidates] is true; the
/// server still checks its own permission on every write.
class CandidateEditorScreen extends StatefulWidget {
  const CandidateEditorScreen({super.key, this.candidateId});

  /// The candidate being edited, or `null` to add a new one.
  final String? candidateId;

  @override
  State<CandidateEditorScreen> createState() => _CandidateEditorScreenState();
}

class _CandidateEditorScreenState extends State<CandidateEditorScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _office = TextEditingController();
  final _electionName = TextEditingController();
  final _bio = TextEditingController();
  final _vanId = TextEditingController();
  final _campaignUrl = TextEditingController();
  final _donateUrl = TextEditingController();
  final _volunteerUrl = TextEditingController();
  final _infoUrl = TextEditingController();
  DateTime? _electionDate;
  CandidateRaceStatus _status = CandidateRaceStatus.running;
  bool _prefilled = false;
  bool _saving = false;
  String? _error;

  bool get _isNew => widget.candidateId == null;

  @override
  void initState() {
    super.initState();
    final hub = context.read<CampaignHubController>();
    WidgetsBinding.instance.addPostFrameCallback((_) => hub.ensureLoaded());
  }

  @override
  void dispose() {
    for (final c in [
      _name,
      _office,
      _electionName,
      _bio,
      _vanId,
      _campaignUrl,
      _donateUrl,
      _volunteerUrl,
      _infoUrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  void _prefill(AlumniCandidate candidate) {
    final draft = CandidateDraft.fromCandidate(candidate);
    _name.text = draft.name;
    _office.text = draft.office;
    _electionName.text = draft.electionName ?? '';
    _bio.text = draft.bio ?? '';
    _vanId.text = draft.vanId?.toString() ?? '';
    _campaignUrl.text = draft.campaignUrl?.toString() ?? '';
    _donateUrl.text = draft.donateUrl?.toString() ?? '';
    _volunteerUrl.text = draft.volunteerUrl?.toString() ?? '';
    _infoUrl.text = draft.infoUrl?.toString() ?? '';
    _electionDate = draft.electionDate;
    _status = draft.status;
    _prefilled = true;
  }

  static String? _optional(TextEditingController c) {
    final text = c.text.trim();
    return text.isEmpty ? null : text;
  }

  static String? _validateLink(String? value) {
    try {
      CandidateDraft.parseLink(value);
      return null;
    } on FormatException catch (e) {
      return e.message;
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _electionDate ?? now,
      firstDate: DateTime(now.year - 2),
      lastDate: DateTime(now.year + 6),
    );
    if (picked != null) setState(() => _electionDate = picked);
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final draft = CandidateDraft(
      name: _name.text.trim(),
      office: _office.text.trim(),
      electionName: _optional(_electionName),
      electionDate: _electionDate,
      status: _status,
      bio: _optional(_bio),
      vanId: int.tryParse(_vanId.text.trim()),
      campaignUrl: CandidateDraft.parseLink(_campaignUrl.text),
      donateUrl: CandidateDraft.parseLink(_donateUrl.text),
      volunteerUrl: CandidateDraft.parseLink(_volunteerUrl.text),
      infoUrl: CandidateDraft.parseLink(_infoUrl.text),
    );
    setState(() {
      _saving = true;
      _error = null;
    });
    final hub = context.read<CampaignHubController>();
    try {
      final id = await hub.saveCandidate(draft, id: widget.candidateId);
      if (!mounted) return;
      context.go('/alumni/running/${Uri.encodeComponent(id)}');
    } on CampaignHubError catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete(AlumniCandidate candidate) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove candidate?'),
        content: Text(
          '${candidate.name} will be removed from Alumni on the Ballot, '
          'along with their supporter channel and volunteer shifts.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const Key('confirm-delete-candidate'),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final hub = context.read<CampaignHubController>();
    final error = await hub.deleteCandidate(candidate.id);
    if (!mounted) return;
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    context.go('/alumni/running');
  }

  @override
  Widget build(BuildContext context) {
    final hub = context.watch<CampaignHubController>();
    final title = _isNew ? 'Add candidate' : 'Edit candidate';

    if (hub.status != CampaignHubStatus.loaded) {
      return Scaffold(
        appBar: AppBar(title: Text(title)),
        body: hub.status == CampaignHubStatus.error
            ? Center(child: Text(hub.error ?? 'Unable to load.'))
            : const Center(child: CircularProgressIndicator()),
      );
    }

    if (!hub.capabilities.canManageCandidates) {
      return Scaffold(
        appBar: AppBar(title: Text(title)),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              hub.capabilities.reason ??
                  "You don't have permission to manage candidates.",
              key: const Key('editor-not-allowed'),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    final existing = _isNew ? null : hub.candidateById(widget.candidateId!);
    if (!_isNew && existing == null) {
      return Scaffold(
        appBar: AppBar(title: Text(title)),
        body: const Center(child: Text('This candidate is no longer listed.')),
      );
    }
    if (existing != null && !_prefilled) _prefill(existing);

    final dateLabel = _electionDate == null
        ? 'Not set'
        : MaterialLocalizations.of(context).formatMediumDate(_electionDate!);

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          if (existing != null)
            IconButton(
              key: const Key('delete-candidate'),
              tooltip: 'Remove candidate',
              icon: const Icon(Icons.delete_outline),
              onPressed: _saving ? null : () => _delete(existing),
            ),
        ],
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                'Public campaign information only. Do not add demographic '
                'or identity details.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 16),
              TextFormField(
                key: const Key('field-name'),
                controller: _name,
                decoration: const InputDecoration(labelText: 'Name *'),
                textInputAction: TextInputAction.next,
                validator: (v) =>
                    (v ?? '').trim().isEmpty ? 'Enter a name.' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                key: const Key('field-office'),
                controller: _office,
                decoration: const InputDecoration(
                  labelText: 'Office sought *',
                  hintText: 'Kentucky State Senate, District 6',
                ),
                textInputAction: TextInputAction.next,
                validator: (v) =>
                    (v ?? '').trim().isEmpty ? 'Enter the office.' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _electionName,
                decoration: const InputDecoration(
                  labelText: 'Election',
                  hintText: '2026 general election',
                ),
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 4),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Election date'),
                subtitle: Text(dateLabel),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_electionDate != null)
                      IconButton(
                        tooltip: 'Clear date',
                        icon: const Icon(Icons.clear),
                        onPressed: () => setState(() => _electionDate = null),
                      ),
                    IconButton(
                      tooltip: 'Pick date',
                      icon: const Icon(Icons.event),
                      onPressed: _pickDate,
                    ),
                  ],
                ),
              ),
              DropdownButtonFormField<CandidateRaceStatus>(
                key: const Key('field-status'),
                initialValue: _status,
                decoration: const InputDecoration(labelText: 'Race status'),
                items: [
                  for (final s in CandidateRaceStatus.values)
                    if (s != CandidateRaceStatus.unknown)
                      DropdownMenuItem(value: s, child: Text(s.label)),
                ],
                onChanged: (s) {
                  if (s != null) setState(() => _status = s);
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _bio,
                decoration: const InputDecoration(labelText: 'Short bio'),
                maxLines: 4,
                maxLength: 600,
              ),
              TextFormField(
                key: const Key('field-van-id'),
                controller: _vanId,
                decoration: const InputDecoration(
                  labelText: 'Alumni Directory VAN ID',
                  helperText: 'Links the card to their Directory profile.',
                ),
                keyboardType: TextInputType.number,
                validator: (v) {
                  final text = (v ?? '').trim();
                  if (text.isEmpty) return null;
                  final id = int.tryParse(text);
                  return id == null || id <= 0 ? 'Enter a number.' : null;
                },
              ),
              const SizedBox(height: 12),
              for (final (key, label, controller) in [
                ('field-campaign-url', 'Campaign page', _campaignUrl),
                ('field-donate-url', 'Donate link', _donateUrl),
                ('field-volunteer-url', 'Volunteer link', _volunteerUrl),
                ('field-info-url', 'Ballotpedia or info page', _infoUrl),
              ]) ...[
                TextFormField(
                  key: Key(key),
                  controller: controller,
                  decoration: InputDecoration(
                    labelText: label,
                    hintText: 'https://',
                  ),
                  keyboardType: TextInputType.url,
                  validator: _validateLink,
                ),
                const SizedBox(height: 12),
              ],
              if (_error != null) ...[
                Text(
                  _error!,
                  key: const Key('editor-error'),
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
                const SizedBox(height: 12),
              ],
              FilledButton(
                key: const Key('save-candidate'),
                onPressed: _saving ? null : _save,
                child: Text(_saving ? 'Saving…' : 'Save'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
