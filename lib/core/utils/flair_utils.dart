class FlairUtils {
  static const String _privateProfileFlag = 'tc:private_profile=true';

  static bool isProfilePrivate(String? flair) {
    if (flair == null) return false;
    final lines = flair.split('\n').map((l) => l.trim()).toList();
    return lines.any((l) => l == _privateProfileFlag);
  }

  static List<String> _userLines(String? flair) {
    if (flair == null) return const [];
    return flair
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty && !l.startsWith('tc:'))
        .toList();
  }

  static bool _looksLikePronouns(String line) {
    final trimmed = line.trim();
    if (trimmed.isEmpty) return false;
    if (trimmed.contains('/')) return true;
    return RegExp(r'[A-Za-z0-9]').hasMatch(trimmed);
  }

  static String? extractPronouns(String? flair) {
    final lines = _userLines(flair);
    if (lines.isEmpty) return null;
    final first = lines.first;
    if (!_looksLikePronouns(first)) return null;
    return first;
  }

  static String? extractMutualAidEmojis(String? flair) {
    final lines = _userLines(flair);
    if (lines.isEmpty) return null;

    if (lines.length == 1) {
      final only = lines.first;
      return _looksLikePronouns(only) ? null : only;
    }

    final first = lines.first;
    if (_looksLikePronouns(first)) {
      return lines[1].trim().isEmpty ? null : lines[1].trim();
    }
    return first.trim().isEmpty ? null : first.trim();
  }

  static String? buildFlair({
    required String pronouns,
    required String mutualAidEmojis,
    required bool isPrivateProfile,
  }) {
    final p = pronouns.trim();
    final e = mutualAidEmojis.trim();
    final lines = <String>[];

    if (p.isNotEmpty) {
      lines.add(p);
    }
    if (e.isNotEmpty) {
      lines.add(e);
    }
    if (isPrivateProfile) {
      lines.add(_privateProfileFlag);
    }

    if (lines.isEmpty) return null;
    return lines.join('\n');
  }
}
