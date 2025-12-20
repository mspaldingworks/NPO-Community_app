import 'package:flutter/widgets.dart';

class TourAnchorRegistry {
  TourAnchorRegistry._();

  static final TourAnchorRegistry instance = TourAnchorRegistry._();

  final Map<String, List<GlobalKey>> _keysByName = <String, List<GlobalKey>>{};

  void register(String name, GlobalKey key) {
    final list = _keysByName.putIfAbsent(name, () => <GlobalKey>[]);
    if (!list.contains(key)) {
      list.add(key);
    }
  }

  void unregister(String name, GlobalKey key) {
    final list = _keysByName[name];
    if (list == null) return;
    list.remove(key);
    if (list.isEmpty) {
      _keysByName.remove(name);
    }
  }

  GlobalKey? _firstMounted(Iterable<GlobalKey> keys) {
    final list = keys is List<GlobalKey> ? keys : keys.toList(growable: false);
    for (var i = list.length - 1; i >= 0; i--) {
      final key = list[i];
      if (key.currentContext != null) {
        return key;
      }
    }
    return null;
  }

  GlobalKey? resolveKey(String targetElementName) {
    final directList = _keysByName[targetElementName];
    if (directList != null) {
      final direct = _firstMounted(directList);
      if (direct != null) return direct;
    }

    if (!targetElementName.contains('X')) return null;

    final escaped = RegExp.escape(targetElementName);
    final pattern = '^' + escaped.replaceAll('X', r'\d+') + r'$';
    final re = RegExp(pattern);

    for (final entry in _keysByName.entries) {
      if (!re.hasMatch(entry.key)) continue;
      final mounted = _firstMounted(entry.value);
      if (mounted != null) return mounted;
    }
    return null;
  }
}
