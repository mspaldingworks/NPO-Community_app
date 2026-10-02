import 'package:flutter/material.dart';

/// Emerge Kentucky brand palette.
///
/// Every value is taken verbatim from the live ky.emergeamerica.org theme CSS
/// (wp-content/themes/emergeamerica/style-child.css) or the state logo PNG, so
/// the app and the website read as one brand. See docs/design-system.md for
/// the selector each token came from.
class AppColors {
  /// Emerge teal — default link and heading color on the website.
  static const Color primary = Color(0xFF197278);

  /// Dark teal — page titles (.c-photo-header__title) and button hover states.
  static const Color primaryDark = Color(0xFF095256);

  /// The wordmark teal in the EMERGE KENTUCKY logo.
  static const Color logoTeal = Color(0xFF266670);

  /// Light cyan — the logo's drop shadow and border.
  static const Color accentCyan = Color(0xFF73CCD8);

  /// Green — the Contribute/donate button (.c-nav__donate-btn) and the
  /// three-dot section divider (.c-quote__dots).
  static const Color green = Color(0xFF5EB445);

  /// Periwinkle — the Sign Up button (.button--purple).
  static const Color periwinkle = Color(0xFF5071CE);

  /// Navy — periwinkle button hover (.button--purple:hover).
  static const Color navy = Color(0xFF29335C);

  /// Orange CTA (.button--orange).
  static const Color orange = Color(0xFFFE9D35);

  /// Crimson — news link hover / pagination accent (style-extra.css).
  static const Color crimson = Color(0xFFBA4B52);

  static const Color textBlack = Color(0xFF414141); // website body text
  static const Color textMuted = Color(0xFF7F7F81); // muted button/label text
  static const Color textWhite = Color(0xFFFFFFFF);
  static const Color canvas = Color(0xFFF6F6F6); // website section background
  static const Color border = Color(0xFFD9DBDB);

  // Names kept from the previous palette so existing screens keep compiling;
  // remapped onto the Emerge brand.
  static const Color secondary = green;
  static const Color tertiary = crimson;
  static const Color alertBackground = Color(0xFFF9ECED);
  static const Color alertAccent = Color(0xFFD40000);
}

/// Typography note: the website sets headings, buttons, and nav items in
/// Montserrat (600/700, buttons uppercase) and body copy in Open Sans — both
/// bundled under assets/fonts and declared in pubspec.yaml.
class AppTheme {
  static ThemeData get lightTheme {
    final colorScheme =
        ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          brightness: Brightness.light,
        ).copyWith(
          primary: AppColors.primary,
          secondary: AppColors.green,
          tertiary: AppColors.crimson,
          onPrimary: AppColors.textWhite,
          onSecondary: AppColors.textWhite,
          primaryContainer: const Color(0xFFDCF2F5),
          onPrimaryContainer: AppColors.primaryDark,
          surface: Colors.white,
          onSurface: AppColors.textBlack,
        );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.canvas,
      fontFamily: 'OpenSans',
      fontFamilyFallback: const ['Helvetica Neue', 'Helvetica', 'Arial'],
      dividerColor: AppColors.border,

      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: AppColors.primaryDark,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: AppColors.primaryDark,
          fontFamily: 'Montserrat',
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),

      // Website buttons are flat, square-cornered, uppercase Montserrat 600.
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.textWhite,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: const RoundedRectangleBorder(),
          textStyle: const TextStyle(
            fontFamily: 'Montserrat',
            fontSize: 14,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.textWhite,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: const RoundedRectangleBorder(),
          textStyle: const TextStyle(
            fontFamily: 'Montserrat',
            fontSize: 14,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          side: const BorderSide(color: AppColors.primary),
          shape: const RoundedRectangleBorder(),
          textStyle: const TextStyle(
            fontFamily: 'Montserrat',
            fontSize: 14,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          textStyle: const TextStyle(
            fontFamily: 'Montserrat',
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.green,
        foregroundColor: AppColors.textWhite,
      ),

      textTheme: const TextTheme(
        // .c-photo-header__title: Montserrat 600, dark teal
        headlineLarge: TextStyle(
          color: AppColors.primaryDark,
          fontFamily: 'Montserrat',
          fontSize: 32,
          fontWeight: FontWeight.w700,
          height: 1.2,
        ),
        headlineMedium: TextStyle(
          color: AppColors.primaryDark,
          fontFamily: 'Montserrat',
          fontSize: 26,
          fontWeight: FontWeight.w600,
          height: 1.25,
        ),
        headlineSmall: TextStyle(
          color: AppColors.primary,
          fontFamily: 'Montserrat',
          fontSize: 22,
          fontWeight: FontWeight.w600,
        ),
        titleLarge: TextStyle(
          color: AppColors.primaryDark,
          fontFamily: 'Montserrat',
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
        titleMedium: TextStyle(
          color: AppColors.textBlack,
          fontFamily: 'Montserrat',
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
        titleSmall: TextStyle(
          color: AppColors.textBlack,
          fontFamily: 'Montserrat',
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        bodyLarge: TextStyle(color: AppColors.textBlack, height: 1.5),
        bodyMedium: TextStyle(color: AppColors.textBlack, height: 1.5),
        labelLarge: TextStyle(
          fontFamily: 'Montserrat',
          fontSize: 14,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),

      inputDecorationTheme: const InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide: BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide: BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide: BorderSide(color: AppColors.primary, width: 2.0),
        ),
      ),

      chipTheme: const ChipThemeData(
        labelStyle: TextStyle(
          fontFamily: 'Montserrat',
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
        selectedColor: Color(0xFFDCF2F5),
        checkmarkColor: AppColors.primaryDark,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(4)),
          side: BorderSide(color: AppColors.border),
        ),
      ),

      navigationBarTheme: NavigationBarThemeData(
        height: 72,
        backgroundColor: Colors.white,
        indicatorColor: const Color(0xFFDCF2F5),
        elevation: 3,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: AppColors.primaryDark, size: 24);
          }
          return const IconThemeData(color: AppColors.textMuted, size: 22);
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(
              color: AppColors.primaryDark,
              fontFamily: 'Montserrat',
              fontSize: 11,
              fontWeight: FontWeight.w700,
            );
          }
          return const TextStyle(
            color: AppColors.textMuted,
            fontFamily: 'Montserrat',
            fontSize: 11,
          );
        }),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          ),
        ),
      ),
    );
  }
}
