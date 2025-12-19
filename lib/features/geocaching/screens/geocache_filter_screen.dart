import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:transconnect/core/services/auth_service.dart';
import 'package:transconnect/features/geocaching/models/geocache_enums.dart';
import 'package:transconnect/features/geocaching/models/geocache_query.dart';
import 'package:transconnect/features/geocaching/utils/geocaching_admin.dart';

class GeocacheFilterScreen extends StatefulWidget {
  final GeocacheQuery initial;

  const GeocacheFilterScreen({super.key, required this.initial});

  @override
  State<GeocacheFilterScreen> createState() => _GeocacheFilterScreenState();
}

class _GeocacheFilterScreenState extends State<GeocacheFilterScreen> {
  late double _radiusMeters;
  late CacheStatus _status;
  late TextEditingController _textCtrl;

  @override
  void initState() {
    super.initState();

    _radiusMeters = widget.initial.radiusMeters;

    _status = widget.initial.status;

    _textCtrl = TextEditingController(text: widget.initial.text ?? '');
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    super.dispose();
  }

  GeocacheQuery _buildQuery() {
    final text = _textCtrl.text.trim();

    return widget.initial.copyWith(
      radiusMeters: _radiusMeters,
      status: _status,
      text: text.isEmpty ? null : text,
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthService>(context, listen: true);
    final isAdmin = isGeocachingAdmin(auth.currentUser);
    final radiusKm = _radiusMeters / 1000.0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Filters'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(_buildQuery());
            },
            child: const Text('Apply'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Radius: ${radiusKm.toStringAsFixed(radiusKm < 10 ? 1 : 0)} km',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          Slider(
            value: _radiusMeters.clamp(1000, 50000),
            min: 1000,
            max: 50000,
            divisions: 49,
            label: '${radiusKm.toStringAsFixed(0)} km',
            onChanged: (v) => setState(() => _radiusMeters = v),
          ),
          const SizedBox(height: 16),

          if (isAdmin) ...[
            DropdownButtonFormField<CacheStatus>(
              value: _status,
              decoration: const InputDecoration(
                labelText: 'Status',
                border: OutlineInputBorder(),
              ),
              items: CacheStatus.values
                  .map((s) => DropdownMenuItem(value: s, child: Text(s.name)))
                  .toList(),
              onChanged: (v) {
                if (v == null) return;
                setState(() => _status = v);
              },
            ),
            const SizedBox(height: 16),
          ],

          TextField(
            controller: _textCtrl,
            decoration: const InputDecoration(
              labelText: 'Search title',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),

          OutlinedButton(
            onPressed: () {
              setState(() {
                _radiusMeters = widget.initial.radiusMeters;
                _status = CacheStatus.active;
                _textCtrl.text = '';
              });
            },
            child: const Text('Reset'),
          ),
        ],
      ),
    );
  }
}
