import 'package:flutter/material.dart';

class AppTheme {
  static const Color primaryPurple = Color(0xFF6750A4);
  static const Color primaryPurpleDark = Color(0xFFD0BCFF);

  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    fontFamily: 'Inter',
    colorScheme: ColorScheme.fromSeed(
      seedColor: primaryPurple,
      brightness: Brightness.light,
    ),
    scaffoldBackgroundColor: const Color(0xFFFAFAF9),
    cardTheme: const CardThemeData(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(16)),
      ),
      color: Colors.white,
    ),
    appBarTheme: _appBarTheme(Brightness.light),
    elevatedButtonTheme: _elevatedButtonTheme(),
    inputDecorationTheme: _inputDecorationTheme(Brightness.light),
    scrollbarTheme: _scrollbarTheme(Brightness.light),
  );

  static ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    fontFamily: 'Inter',
    colorScheme: ColorScheme.fromSeed(
      seedColor: primaryPurple,
      brightness: Brightness.dark,
    ),
    scaffoldBackgroundColor: const Color(0xFF0F0F0F),
    cardTheme: const CardThemeData(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(16)),
      ),
      color: Color(0xFF1A1A1A),
    ),
    appBarTheme: _appBarTheme(Brightness.dark),
    elevatedButtonTheme: _elevatedButtonTheme(),
    inputDecorationTheme: _inputDecorationTheme(Brightness.dark),
    scrollbarTheme: _scrollbarTheme(Brightness.dark),
  );

  static AppBarTheme _appBarTheme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    return AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      centerTitle: true,
      iconTheme: IconThemeData(
        color: isDark ? primaryPurpleDark : primaryPurple,
      ),
      titleTextStyle: TextStyle(
        color: isDark ? const Color(0xFFF9FAFB) : const Color(0xFF1F2937),
        fontSize: 18,
        fontWeight: FontWeight.w600,
        fontFamily: 'Inter',
      ),
    );
  }

  static ElevatedButtonThemeData _elevatedButtonTheme() {
    return ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryPurple,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    );
  }

  static InputDecorationTheme _inputDecorationTheme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final borderColor = isDark
        ? const Color(0xFF27272A)
        : const Color(0xFFE5E7EB);

    return InputDecorationTheme(
      filled: true,
      fillColor: isDark ? const Color(0xFF1A1A1A) : Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: borderColor),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: borderColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: primaryPurple, width: 2),
      ),
    );
  }

  static ScrollbarThemeData _scrollbarTheme(Brightness brightness) {
    return ScrollbarThemeData(
      thumbVisibility: MaterialStateProperty.all(false),
      thickness: MaterialStateProperty.all(6.0),
      radius: const Radius.circular(3.0),
      thumbColor: MaterialStateProperty.resolveWith((states) {
        if (states.contains(MaterialState.hovered) ||
            states.contains(MaterialState.dragged)) {
          return primaryPurple.withOpacity(0.5);
        }
        return primaryPurple.withOpacity(0.2);
      }),
    );
  }
}
