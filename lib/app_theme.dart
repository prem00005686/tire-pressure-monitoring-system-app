import 'package:flutter/material.dart';

class AppTheme {
  static ThemeMode currentThemeMode = ThemeMode.dark;
  static bool get isLight => currentThemeMode == ThemeMode.light;

  static const Color _backgroundDark = Color(0xFF0C1322);
  static const Color _surfaceDark = Color(0xFF191F2F);
  static const Color _surfaceHighDark = Color(0xFF232A3A);
  static const Color _primaryDark = Color(0xFFADC6FF);
  static const Color _onPrimaryDark = Color(0xFF002E6A);
  static const Color _secondaryDark = Color(0xFFFFB690);
  static const Color _onBackgroundDark = Color(0xFFDCE2F7);
  static const Color _onSurfaceVariantDark = Color(0xFFC2C6D6);
  static const Color _outlineDark = Color(0xFF8C909F);
  static const Color _outlineVariantDark = Color(0xFF424754);

  static const Color _backgroundLight = Color(0xFFF6F8FF);
  static const Color _surfaceLight = Color(0xFFFFFFFF);
  static const Color _surfaceHighLight = Color(0xFFF1F5FB);
  static const Color _primaryLight = Color(0xFF2E4DE3);
  static const Color _onPrimaryLight = Colors.white;
  static const Color _secondaryLight = Color(0xFF5468FF);
  static const Color _onBackgroundLight = Color(0xFF101828);
  static const Color _onSurfaceVariantLight = Color(0xFF64748B);
  static const Color _outlineLight = Color(0xFFCBD2E1);
  static const Color _outlineVariantLight = Color(0xFFE2E8F0);

  static Color get background => isLight ? _backgroundLight : _backgroundDark;
  static Color get surface => isLight ? _surfaceLight : _surfaceDark;
  static Color get surfaceHigh => isLight ? _surfaceHighLight : _surfaceHighDark;
  static Color get primary => isLight ? _primaryLight : _primaryDark;
  static Color get onPrimary => isLight ? _onPrimaryLight : _onPrimaryDark;
  static Color get secondary => isLight ? _secondaryLight : _secondaryDark;
  static Color get onBackground => isLight ? _onBackgroundLight : _onBackgroundDark;
  static Color get onSurfaceVariant => isLight ? _onSurfaceVariantLight : _onSurfaceVariantDark;
  static Color get outline => isLight ? _outlineLight : _outlineDark;
  static Color get outlineVariant => isLight ? _outlineVariantLight : _outlineVariantDark;
  static const Color error = Color(0xFFFFB4AB);
  static const Color primaryDark = Color(0xFF2B54B4);
  static const Color success = Color(0xFF2E7D32);
  static const Color successContainer = Color(0xFFE8F5E9);
  static const Color warning = Color(0xFFFFA726);
  static const Color warningContainer = Color(0xFFFFF4E5);
  static const Color danger = Color(0xFFC62828);
  static const Color dangerContainer = Color(0xFFFFEBEE);

  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: background,
      primaryColor: primary,
      colorScheme: ColorScheme.dark(
        primary: primary,
        onPrimary: onPrimary,
        secondary: secondary,
        background: background,
        surface: surface,
        onBackground: onBackground,
        onSurface: onBackground,
        onSurfaceVariant: onSurfaceVariant,
        error: error,
        outline: outline,
        outlineVariant: outlineVariant,
      ),
      fontFamily: 'Inter',
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: primary),
        titleTextStyle: TextStyle(
          color: primary,
          fontSize: 24,
          fontWeight: FontWeight.w600,
        ),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: outlineVariant, width: 1),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: background,
        labelStyle: TextStyle(
          color: onSurfaceVariant,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
        hintStyle: TextStyle(color: outline.withValues(alpha: 0.5)),
        prefixIconColor: outline,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: primary),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: error),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: onPrimary,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          padding: const EdgeInsets.symmetric(vertical: 16),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  static ThemeData get lightTheme {
    return ThemeData(
      brightness: Brightness.light,
      scaffoldBackgroundColor: const Color(0xFFF6F8FF),
      primaryColor: const Color(0xFF2E4DE3),
      colorScheme: const ColorScheme.light(
        primary: Color(0xFF2E4DE3),
        onPrimary: Colors.white,
        secondary: Color(0xFF5468FF),
        background: Color(0xFFF6F8FF),
        surface: Colors.white,
        onBackground: Color(0xFF101828),
        onSurface: Color(0xFF101828),
        onSurfaceVariant: Color(0xFF5E6C8A),
        error: Color(0xFFBA1A1A),
        outline: Color(0xFFCBD2E1),
        outlineVariant: Color(0xFFE2E8F0),
      ),
      fontFamily: 'Inter',
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFFF6F8FF),
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: Color(0xFF2E4DE3)),
        titleTextStyle: TextStyle(
          color: Color(0xFF2E4DE3),
          fontSize: 24,
          fontWeight: FontWeight.w600,
        ),
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Color(0xFFE2E8F0), width: 1),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFF6F8FF),
        labelStyle: const TextStyle(
          color: Color(0xFF5E6C8A),
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
        hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
        prefixIconColor: const Color(0xFF94A3B8),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFF2E4DE3)),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFBA1A1A)),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF2E4DE3),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          padding: const EdgeInsets.symmetric(vertical: 16),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}
