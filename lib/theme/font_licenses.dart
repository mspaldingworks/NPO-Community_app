import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// The bundled brand fonts are under the SIL Open Font License, which must
/// travel with the fonts. Registering the license texts lists them on the
/// standard licenses page (Settings → Open-source licenses).
void registerFontLicenses() {
  LicenseRegistry.addLicense(() async* {
    yield LicenseEntryWithLineBreaks(const [
      'Montserrat',
    ], await rootBundle.loadString('assets/fonts/Montserrat-OFL.txt'));
    yield LicenseEntryWithLineBreaks(const [
      'Open Sans',
    ], await rootBundle.loadString('assets/fonts/OpenSans-OFL.txt'));
  });
}
