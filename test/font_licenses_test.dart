import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:npo_community/theme/font_licenses.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('bundled brand fonts list their OFL license', () async {
    registerFontLicenses();
    final entries = await LicenseRegistry.licenses.toList();

    for (final font in ['Montserrat', 'Open Sans']) {
      final entry = entries.firstWhere(
        (e) => e.packages.contains(font),
        orElse: () => throw TestFailure('No license registered for $font'),
      );
      final text = entry.paragraphs.map((p) => p.text).join('\n');
      expect(text, contains('SIL OPEN FONT LICENSE Version 1.1'));
    }
  });
}
