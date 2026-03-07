import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// All visual styling lives here.
// Both light and dark themes are generated from the same accent color.

class AppTheme {
  // preset accent colors shown in settings
  static const List<Color> presetAccents = [
    Color(0xFF4ADE80), // green (namenu+ brand)
    Color(0xFF60A5FA), // blue
    Color(0xFFF87171), // red
    Color(0xFFFB923C), // orange
    Color(0xFFF472B6), // pink
    Color(0xFFA78BFA), // purple
    Color(0xFF22D3EE), // cyan
  ];

  static ThemeData dark(Color accent) {
    const bg      = Color(0xFF0A0A0A);
    const bg1     = Color(0xFF111111);
    const bg2     = Color(0xFF161616);
    const bg3     = Color(0xFF1C1C1C);
    const border  = Color(0xFF242424);
    const textPrimary   = Color(0xFFD8D8D8);
    const textSecondary = Color(0xFF888888);

    final cs = ColorScheme.dark(
      primary:   accent,
      secondary: accent,
      surface:   bg1,
      onPrimary: Colors.black,
      onSurface: textPrimary,
    );

    return _build(cs, accent, bg, bg1, bg2, bg3, border, textPrimary, textSecondary, true);
  }

  static ThemeData light(Color accent) {
    const bg      = Color(0xFFF8F8F8);
    const bg1     = Color(0xFFFFFFFF);
    const bg2     = Color(0xFFF2F2F2);
    const bg3     = Color(0xFFE8E8E8);
    const border  = Color(0xFFE0E0E0);
    const textPrimary   = Color(0xFF1A1A1A);
    const textSecondary = Color(0xFF666666);

    final cs = ColorScheme.light(
      primary:   accent,
      secondary: accent,
      surface:   bg1,
      onPrimary: Colors.white,
      onSurface: textPrimary,
    );

    return _build(cs, accent, bg, bg1, bg2, bg3, border, textPrimary, textSecondary, false);
  }

  static ThemeData _build(
    ColorScheme cs,
    Color accent,
    Color bg, Color bg1, Color bg2, Color bg3, Color border,
    Color textPrimary, Color textSecondary,
    bool isDark,
  ) {
    final base = GoogleFonts.interTextTheme(
      ThemeData(brightness: isDark ? Brightness.dark : Brightness.light).textTheme,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: cs,
      scaffoldBackgroundColor: bg,
      textTheme: base.copyWith(
        // big titles
        headlineLarge: base.headlineLarge?.copyWith(
          color: textPrimary, fontWeight: FontWeight.w700, fontSize: 24,
        ),
        // restaurant names etc
        titleLarge: base.titleLarge?.copyWith(
          color: textPrimary, fontWeight: FontWeight.w600, fontSize: 16,
        ),
        titleMedium: base.titleMedium?.copyWith(
          color: textPrimary, fontWeight: FontWeight.w500, fontSize: 14,
        ),
        // dish names
        bodyLarge: base.bodyLarge?.copyWith(
          color: textPrimary, fontSize: 14,
        ),
        // descriptions
        bodyMedium: base.bodyMedium?.copyWith(
          color: textSecondary, fontSize: 13,
        ),
        bodySmall: base.bodySmall?.copyWith(
          color: textSecondary, fontSize: 11,
        ),
      ),

      // app bar
      appBarTheme: AppBarTheme(
        backgroundColor: bg1,
        foregroundColor: textPrimary,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.inter(
          color: textPrimary,
          fontWeight: FontWeight.w700,
          fontSize: 18,
        ),
        surfaceTintColor: Colors.transparent,
      ),

      // bottom nav bar
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: bg1,
        indicatorColor: accent.withAlpha(30),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return IconThemeData(color: accent, size: 22);
          }
          return IconThemeData(color: textSecondary, size: 22);
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return GoogleFonts.inter(
              color: accent, fontWeight: FontWeight.w600, fontSize: 11,
            );
          }
          return GoogleFonts.inter(
            color: textSecondary, fontWeight: FontWeight.w400, fontSize: 11,
          );
        }),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),

      // cards
      cardTheme: CardThemeData(
        color: bg1,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: border, width: 1),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      ),

      // input fields (search bar)
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: bg2,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: accent, width: 1.5),
        ),
        hintStyle: GoogleFonts.inter(color: textSecondary, fontSize: 14),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),

      // chips (allergen filters, day tabs)
      chipTheme: ChipThemeData(
        backgroundColor: bg2,
        selectedColor: accent.withAlpha(30),
        labelStyle: GoogleFonts.inter(fontSize: 12, color: textSecondary),
        secondaryLabelStyle: GoogleFonts.inter(fontSize: 12, color: accent),
        side: BorderSide(color: border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      ),

      // dividers
      dividerTheme: DividerThemeData(color: border, thickness: 1, space: 1),

      // switches (dark mode toggle)
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.selected) ? accent : textSecondary),
        trackColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.selected) ? accent.withAlpha(80) : bg3),
      ),
    );
  }
}

// Extension to easily access custom colors from any widget:
// context.appColors.bg2 etc.
extension AppColors on BuildContext {
  bool get isDark => Theme.of(this).brightness == Brightness.dark;

  Color get accentColor => Theme.of(this).colorScheme.primary;

  Color get bgColor => isDark ? const Color(0xFF0A0A0A) : const Color(0xFFF8F8F8);
  Color get bg1     => isDark ? const Color(0xFF111111) : const Color(0xFFFFFFFF);
  Color get bg2     => isDark ? const Color(0xFF161616) : const Color(0xFFF2F2F2);
  Color get bg3     => isDark ? const Color(0xFF1C1C1C) : const Color(0xFFE8E8E8);
  Color get border  => isDark ? const Color(0xFF242424) : const Color(0xFFE0E0E0);
  Color get textPrimary   => isDark ? const Color(0xFFD8D8D8) : const Color(0xFF1A1A1A);
  Color get textSecondary => isDark ? const Color(0xFF888888) : const Color(0xFF666666);
}