import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Menetrend+ — modern, letisztult design system (2025/26).
class AppTheme {
  // Brand
  static const Color primary = Color(0xFF0D9488); // teal-600
  static const Color primaryDark = Color(0xFF0F766E);
  static const Color secondary = Color(0xFF6366F1); // indigo
  static const Color accent = Color(0xFFF43F5E); // rose for delay
  static const Color success = Color(0xFF22C55E);
  static const Color warning = Color(0xFFF59E0B);

  // Provider outlines
  static const Color mavOutline = Color(0xFF2563EB); // blue
  static const Color volanOutline = Color(0xFFEAB308); // yellow

  // Aliases (régi kód kompatibilitás)
  static const Color mav = mavOutline;
  static const Color volan = Color(0xFF0F766E); // Volán brand teal-ish

  static const Color surfaceLight = Color(0xFFF4F7F8);
  static const Color surfaceDark = Color(0xFF0B1220);
  static const Color cardLight = Color(0xFFFFFFFF);
  static const Color cardDark = Color(0xFF141C2B);

  static ThemeData get light {
    final scheme = ColorScheme.fromSeed(
      seedColor: primary,
      brightness: Brightness.light,
      primary: primary,
      secondary: secondary,
      error: accent,
      surface: surfaceLight,
    ).copyWith(
      surfaceContainerHighest: const Color(0xFFE8EEF0),
      outline: const Color(0xFFD0D9DE),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: scheme,
      scaffoldBackgroundColor: surfaceLight,
      fontFamily: null, // system / platform default
      textTheme: _textTheme(Brightness.light),
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        backgroundColor: surfaceLight.withValues(alpha: 0.92),
        foregroundColor: const Color(0xFF0F172A),
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        titleTextStyle: const TextStyle(
          color: Color(0xFF0F172A),
          fontSize: 22,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.4,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: cardLight,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: Colors.black.withValues(alpha: 0.04)),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        clipBehavior: Clip.antiAlias,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        hintStyle: TextStyle(color: Colors.grey.shade500, fontWeight: FontWeight.w400),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.black.withValues(alpha: 0.06)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.black.withValues(alpha: 0.06)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: primary, width: 1.6),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 72,
        elevation: 0,
        backgroundColor: Colors.white.withValues(alpha: 0.94),
        indicatorColor: primary.withValues(alpha: 0.14),
        labelTextStyle: WidgetStateProperty.resolveWith((s) {
          final selected = s.contains(WidgetState.selected);
          return TextStyle(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            letterSpacing: -0.1,
            color: selected ? primaryDark : const Color(0xFF64748B),
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((s) {
          final selected = s.contains(WidgetState.selected);
          return IconThemeData(
            size: 24,
            color: selected ? primaryDark : const Color(0xFF94A3B8),
          );
        }),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        side: BorderSide.none,
        backgroundColor: const Color(0xFFEEF6F5),
        selectedColor: primary.withValues(alpha: 0.18),
        labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          elevation: 0,
          backgroundColor: primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryDark,
          side: BorderSide(color: primary.withValues(alpha: 0.35)),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        backgroundColor: const Color(0xFF1E293B),
      ),
      dividerTheme: DividerThemeData(
        color: Colors.black.withValues(alpha: 0.06),
        thickness: 1,
        space: 1,
      ),
      listTileTheme: ListTileThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),
    );
  }

  static ThemeData get dark {
    final scheme = ColorScheme.fromSeed(
      seedColor: primary,
      brightness: Brightness.dark,
      primary: const Color(0xFF2DD4BF),
      secondary: const Color(0xFF818CF8),
      error: const Color(0xFFFB7185),
      surface: surfaceDark,
    ).copyWith(
      surfaceContainerHighest: const Color(0xFF1A2332),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: surfaceDark,
      textTheme: _textTheme(Brightness.dark),
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: surfaceDark.withValues(alpha: 0.9),
        foregroundColor: Colors.white,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        titleTextStyle: const TextStyle(
          color: Colors.white,
          fontSize: 22,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.4,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: cardDark,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: cardDark,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFF2DD4BF), width: 1.6),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 72,
        elevation: 0,
        backgroundColor: const Color(0xFF0F172A),
        indicatorColor: const Color(0xFF2DD4BF).withValues(alpha: 0.18),
        labelTextStyle: WidgetStateProperty.resolveWith((s) {
          final selected = s.contains(WidgetState.selected);
          return TextStyle(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? const Color(0xFF2DD4BF) : const Color(0xFF94A3B8),
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((s) {
          final selected = s.contains(WidgetState.selected);
          return IconThemeData(
            size: 24,
            color: selected ? const Color(0xFF2DD4BF) : const Color(0xFF64748B),
          );
        }),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: const Color(0xFF2DD4BF),
        foregroundColor: const Color(0xFF0B1220),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
    );
  }

  static TextTheme _textTheme(Brightness b) {
    final base = b == Brightness.light
        ? const Color(0xFF0F172A)
        : const Color(0xFFF1F5F9);
    final muted = b == Brightness.light
        ? const Color(0xFF64748B)
        : const Color(0xFF94A3B8);
    return TextTheme(
      displaySmall: TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.8,
        color: base,
      ),
      headlineMedium: TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.4,
        color: base,
      ),
      titleLarge: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.2,
        color: base,
      ),
      titleMedium: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: base,
      ),
      bodyLarge: TextStyle(fontSize: 16, height: 1.35, color: base),
      bodyMedium: TextStyle(fontSize: 14, height: 1.4, color: base),
      bodySmall: TextStyle(fontSize: 12, height: 1.35, color: muted),
      labelLarge: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: base,
      ),
    );
  }
}
