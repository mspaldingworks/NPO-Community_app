import 'package:flutter/material.dart';

class AppColors {
  static const Color primary = Color(0xFF3A2E7D);
  static const Color secondary = Color(0xFFF2C14E); 
  static const Color tertiary = Color(0xFFD95D79); 
  static const Color alertBackground = Color(0xFFFFE5EC);
  static const Color alertAccent = Color(0xFFD95D79);
  static const Color textBlack = Color(0xFF000000);
  static const Color textWhite = Color(0xFFFFFFFF);
}

class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      primaryColor: AppColors.primary,
      scaffoldBackgroundColor: Colors.white,
      fontFamily: 'Roboto', 

      colorScheme: const ColorScheme.light(
        primary: AppColors.primary,
        secondary: AppColors.secondary,
        tertiary: AppColors.tertiary,
        onPrimary: AppColors.textWhite,
        onSecondary: AppColors.textBlack, 
        onTertiary: AppColors.textWhite, 
        background: Colors.white,
        onBackground: AppColors.textBlack,
        surface: Colors.white,
        onSurface: AppColors.textBlack,
      ),

      appBarTheme: const AppBarTheme(
        color: AppColors.primary,
        elevation: 0,
        iconTheme: IconThemeData(color: AppColors.textWhite),
        titleTextStyle: TextStyle(
          color: AppColors.textWhite,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),

      buttonTheme: const ButtonThemeData(
        buttonColor: AppColors.primary,
        textTheme: ButtonTextTheme.primary,
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.textWhite,
        ),
      ),

      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.secondary,
        foregroundColor: AppColors.textBlack,
      ),

      textTheme: const TextTheme(
        bodyLarge: TextStyle(color: AppColors.textBlack),
        bodyMedium: TextStyle(color: AppColors.textBlack),
        titleLarge: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold),
        headlineSmall: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold),
        titleMedium: TextStyle(color: AppColors.textBlack, fontWeight: FontWeight.bold),
      ),

      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: AppColors.primary, width: 2.0),
        ),
      ),

      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.primary,
        indicatorColor: Colors.transparent, // Remove indicator highlight
        iconTheme: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.selected)) {
            return const IconThemeData(
              color: AppColors.textWhite,
              size: 48, // 100% larger than default (24)
              shadows: [
                Shadow(color: Colors.black, blurRadius: 15.0, offset: Offset(0, 2)),
              ],
            );
          }
          return const IconThemeData(color: AppColors.textWhite, size: 24);
        }),
        labelTextStyle: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.selected)) {
            return const TextStyle(color: AppColors.textWhite, fontWeight: FontWeight.bold);
          }
          return const TextStyle(color: AppColors.textWhite);
        }),
      ),

      tabBarTheme: TabBarThemeData(
        indicator: const UnderlineTabIndicator(
          borderSide: BorderSide(color: AppColors.secondary, width: 3.0),
        ),
        labelColor: AppColors.textWhite,
        unselectedLabelColor: Colors.white.withOpacity(0.7),
        labelStyle: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 16,
        ),
        unselectedLabelStyle: const TextStyle(
          fontWeight: FontWeight.normal,
          fontSize: 16,
        ),
      ),
    );
  }
}
