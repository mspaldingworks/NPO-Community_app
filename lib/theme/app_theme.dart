import 'package:flutter/material.dart';

class AppColors {
  static const Color primary = Color(0xFF173D33);
  static const Color secondary = Color(0xFFD9B857);
  static const Color tertiary = Color(0xFFC25432);
  static const Color alertBackground = Color(0xFFF8E8E2);
  static const Color alertAccent = Color(0xFFB33A2B);
  static const Color textBlack = Color(0xFF1B211D);
  static const Color textWhite = Color(0xFFFFFFFF);
  static const Color canvas = Color(0xFFF4F6F2);
  static const Color border = Color(0xFFDDE2DC);
}

class AppTheme {
  static ThemeData get lightTheme {
    final colorScheme =
        ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          brightness: Brightness.light,
        ).copyWith(
          primary: AppColors.primary,
          secondary: AppColors.secondary,
          tertiary: AppColors.tertiary,
          onPrimary: AppColors.textWhite,
          onSecondary: AppColors.textBlack,
          surface: Colors.white,
          onSurface: AppColors.textBlack,
        );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.canvas,
      fontFamily: 'Avenir Next',
      fontFamilyFallback: const ['Avenir', 'Helvetica Neue'],

      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.canvas,
        foregroundColor: AppColors.textBlack,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: AppColors.textBlack,
          fontFamily: 'Avenir Next',
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.textWhite,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        ),
      ),

      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.secondary,
        foregroundColor: AppColors.textBlack,
      ),

      textTheme: const TextTheme(
        bodyLarge: TextStyle(color: AppColors.textBlack),
        bodyMedium: TextStyle(color: AppColors.textBlack),
        headlineMedium: TextStyle(
          color: AppColors.textBlack,
          fontSize: 27,
          fontWeight: FontWeight.w700,
        ),
        headlineSmall: TextStyle(
          color: AppColors.textBlack,
          fontWeight: FontWeight.w700,
        ),
        titleLarge: TextStyle(
          color: AppColors.textBlack,
          fontWeight: FontWeight.w700,
        ),
        titleMedium: TextStyle(
          color: AppColors.textBlack,
          fontWeight: FontWeight.w700,
        ),
      ),

      inputDecorationTheme: const InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderSide: BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: AppColors.primary, width: 2.0),
        ),
      ),

      navigationBarTheme: NavigationBarThemeData(
        height: 72,
        backgroundColor: Colors.white,
        indicatorColor: const Color(0xFFE1F0D5),
        elevation: 3,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: AppColors.primary, size: 24);
          }
          return const IconThemeData(color: Color(0xFF69716B), size: 22);
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(
              color: AppColors.primary,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            );
          }
          return const TextStyle(color: Color(0xFF69716B), fontSize: 11);
        }),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          ),
        ),
      ),
    );
  }
}
