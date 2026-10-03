/// The `flair` profile field carries the member's pronouns (first line) and
/// a private-profile flag. Older accounts may have extra lines from a feature
/// that no longer exists; they are ignored.
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

  static String? buildFlair({
    required String pronouns,
    required bool isPrivateProfile,
  }) {
    final lines = <String>[
      if (pronouns.trim().isNotEmpty) pronouns.trim(),
      if (isPrivateProfile) _privateProfileFlag,
    ];
    if (lines.isEmpty) return null;
    return lines.join('\n');
  }
}
