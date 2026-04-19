import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      brightness: Brightness.light,

      primaryColor: const Color(0xFF6B4EFF),
      scaffoldBackgroundColor: const Color(0xFFF8F9FA),
      colorScheme: ColorScheme.light(
        primary: const Color(0xFF6B4EFF),
        secondary: const Color(0xFF00C48C),
        surface: Colors.white,
      ),
      textTheme: GoogleFonts.poppinsTextTheme(ThemeData.light().textTheme),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.black),
      ),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      primaryColor: const Color(0xFF8875FF),
      scaffoldBackgroundColor: const Color(0xFF121212),
      colorScheme: ColorScheme.dark(
        primary: const Color(0xFF8875FF),
        secondary: const Color(0xFF00C48C),
        surface: const Color(0xFF1E1E1E),
      ),
      textTheme: GoogleFonts.poppinsTextTheme(ThemeData.dark().textTheme),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.white),
      ),
    );
  }

  static ThemeData applyLocaleFont(ThemeData theme, Locale locale) {
    if (locale.languageCode != 'ar') return theme;

    // .apply(fontFamily) silently skips styles that have an explicit fontFamily
    // (e.g. Poppins set via GoogleFonts.poppinsTextTheme).
    // We must copy every style individually to force Cairo on all of them.
    TextTheme _forceFont(TextTheme base) {
      TextStyle _cairo(TextStyle? s) =>
          (s ?? const TextStyle()).copyWith(fontFamily: 'Cairo');
      return base.copyWith(
        displayLarge: _cairo(base.displayLarge),
        displayMedium: _cairo(base.displayMedium),
        displaySmall: _cairo(base.displaySmall),
        headlineLarge: _cairo(base.headlineLarge),
        headlineMedium: _cairo(base.headlineMedium),
        headlineSmall: _cairo(base.headlineSmall),
        titleLarge: _cairo(base.titleLarge),
        titleMedium: _cairo(base.titleMedium),
        titleSmall: _cairo(base.titleSmall),
        bodyLarge: _cairo(base.bodyLarge),
        bodyMedium: _cairo(base.bodyMedium),
        bodySmall: _cairo(base.bodySmall),
        labelLarge: _cairo(base.labelLarge),
        labelMedium: _cairo(base.labelMedium),
        labelSmall: _cairo(base.labelSmall),
      );
    }

    return theme.copyWith(
      textTheme: _forceFont(theme.textTheme),
      primaryTextTheme: _forceFont(theme.primaryTextTheme),

    );
  }
}
