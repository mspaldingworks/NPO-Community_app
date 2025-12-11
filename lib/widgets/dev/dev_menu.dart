import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:transconnect/core/services/resource_service.dart';
import 'package:transconnect/models/resource.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:transconnect/core/constants/api_endpoints.dart';

class DevMenu extends StatefulWidget {
  final Widget child;
  
  const DevMenu({
    super.key,
    required this.child,
  });

  @override
  State<DevMenu> createState() => _DevMenuState();
}

class _DevMenuState extends State<DevMenu> {
  int _tapCount = 0;
  DateTime? _lastTap;
  bool _running = false;
  String? _lastResult;
  final ResourceService _resourceService = ResourceService();
  final TextEditingController _adminTokenController = TextEditingController();
  String? _overrideToken;

  @override
  void dispose() {
    _adminTokenController.dispose();
    super.dispose();
  }
  
  void _handleTap() {
    final now = DateTime.now();
    
    if (_lastTap != null && now.difference(_lastTap!) < const Duration(seconds: 2)) {
      _tapCount++;
    } else {
      _tapCount = 1;
    }

    _lastTap = now;
    
    // Show dev menu after 5 taps
    if (_tapCount >= 5) {
      _tapCount = 0;
      _showDevMenu();
    }
  }

  Future<List<Resource>> _fetchAllResourcesUsing({String? token}) async {
    if (token == null || token.isEmpty) {
      return _resourceService.fetchResources();
    }
    final uri = Uri.parse('${ApiEndpoints.host}/api/resources/');
    final response = await http.get(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Token $token',
      },
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to fetch resources: ${response.statusCode}');
    }
    final body = response.body.isNotEmpty ? jsonDecode(response.body) : [];
    if (body is List) {
      return body
          .map((e) => Resource.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    throw Exception('Unexpected resources response');
  }

  Future<void> _updateResourceWithToken(Resource resource, {String? token}) async {
    if (token == null || token.isEmpty) {
      await _resourceService.updateResource(resource);
      return;
    }
    final uri = Uri.parse('${ApiEndpoints.host}/api/resources/${resource.id}/');
    final payload = {
      'tags': resource.tags,
    };
    final response = await http.patch(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Token $token',
      },
      body: jsonEncode(payload),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to update resource ${resource.id}: ${response.statusCode} ${response.body}');
    }
  }

  Future<void> _bulkAssignResourceTags() async {
    if (_running) return;
    setState(() {
      _running = true;
      _lastResult = null;
    });
    int updated = 0;
    int scanned = 0;
    int errors = 0;
    try {
      _overrideToken = _adminTokenController.text.trim().isNotEmpty
          ? _adminTokenController.text.trim()
          : null;
      final resources = await _fetchAllResourcesUsing(token: _overrideToken);
      for (final r in resources) {
        scanned++;
        final computed = _computeTags(r).toSet();
        final current = r.tags.toSet();
        final List<String> merged = <String>{...current, ...computed}.toList();
        if (merged.toSet().length != current.length || !current.containsAll(computed)) {
          final updatedResource = Resource(
            id: r.id,
            user: r.user,
            name: r.name,
            description: r.description,
            type: r.type,
            url: r.url,
            provider: r.provider,
            pubDate: r.pubDate,
            public: r.public,
            tags: merged,
          );
          try {
            await _updateResourceWithToken(updatedResource, token: _overrideToken);
            updated++;
          } catch (_) {
            errors++;
          }
        }
      }
      setState(() {
        _lastResult = 'Scanned $scanned; updated $updated; errors $errors';
      });
    } catch (e) {
      setState(() {
        _lastResult = 'Bulk tagging failed: $e';
      });
    } finally {
      setState(() {
        _running = false;
      });
      if (mounted) {
        _showDevMenu();
      }
    }
  }

  List<String> _computeTags(Resource r) {
    final allowed = <String>{
      'Advocacy',
      'Employment',
      'Financial Assistance',
      'Hotline',
      'Legal',
      'Medical',
      'Mental Health',
      'Service',
      'Support Group',
      'Youth',
      'test',
    };

    final out = <String>{};
    final type = (r.type ?? '').toLowerCase();
    final text = [r.name, r.description, r.provider, r.url]
        .whereType<String>()
        .join(' ')
        .toLowerCase();

    if (type.contains('advocacy')) {
      out.add('Advocacy');
    }
    if (type.contains('community')) {
      if (text.contains('support') || text.contains('group')) {
        out.add('Support Group');
      } else {
        out.add('Service');
      }
    }
    if (type.contains('youth')) {
      out.add('Youth');
    }
    if (type.contains('medical') || type.contains('clinic') || type.contains('telehealth')) {
      out.add('Medical');
    }
    if (type.contains('mental')) {
      out.add('Mental Health');
    }
    if (type.contains('legal') || type.contains('law')) {
      out.add('Legal');
    }
    if (type.contains('hotline')) {
      out.add('Hotline');
    }

    if (text.contains('youth') || text.contains('young') || text.contains('teen')) {
      out.add('Youth');
    }
    if (text.contains('counsel') || text.contains('therapy') || text.contains('psychi') || text.contains('mental')) {
      out.add('Mental Health');
    }
    if (text.contains('clinic') || text.contains('health') || text.contains('hiv') || text.contains('sti') || text.contains('hormone') || text.contains('pharmacy')) {
      out.add('Medical');
    }
    if (text.contains('hotline') || text.contains('crisis')) {
      out.add('Hotline');
    }
    if (text.contains('support')) {
      out.add('Support Group');
    }
    if (text.contains('employ') || text.contains('job') || text.contains('workforce')) {
      out.add('Employment');
    }
    if (text.contains('grant') || text.contains('fund') || text.contains('assistance') || text.contains('aid') || text.contains('microgrant')) {
      out.add('Financial Assistance');
    }
    if (text.contains('legal') || text.contains('attorney') || text.contains('lawyer') || text.contains('name change')) {
      out.add('Legal');
    }
    if (text.contains('service') || text.contains('services')) {
      out.add('Service');
    }

    return out.where((t) => allowed.contains(t)).toList();
  }
  
  void _showDevMenu() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Developer Menu'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Development tools and test screens'),
            if (_lastResult != null) Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Text(_lastResult!),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _adminTokenController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Admin override token (optional)',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: _running ? null : () async {
              Navigator.pop(context);
              await _bulkAssignResourceTags();
            },
            child: _running ? const Text('Working...') : const Text('Bulk tag resources'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
        actionsOverflowButtonSpacing: 8,
        actionsOverflowDirection: VerticalDirection.down,
        actionsAlignment: MainAxisAlignment.spaceEvenly,
        buttonPadding: const EdgeInsets.all(16),
        actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: _handleTap,
      onLongPress: _showDevMenu,
      child: widget.child,
    );
  }
}
