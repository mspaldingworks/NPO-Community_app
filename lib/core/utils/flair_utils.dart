/// The `flair` profile field carries the private-profile flag. Older
/// accounts may have extra lines from features that no longer exist (the
/// pronouns picker was retired 2026-10-06); they are ignored and dropped on
/// the next save.
class FlairUtils {
  static const String _privateProfileFlag = 'tc:private_profile=true';

  static bool isProfilePrivate(String? flair) {
    if (flair == null) return false;
    final lines = flair.split('\n').map((l) => l.trim()).toList();
    return lines.any((l) => l == _privateProfileFlag);
  }

  static String? buildFlair({required bool isPrivateProfile}) {
    return isPrivateProfile ? _privateProfileFlag : null;
  }
}
