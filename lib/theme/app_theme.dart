import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

class AppTheme {
  static ThemeData get dark => _buildTheme(Brightness.dark);
  static ThemeData get light => _buildTheme(Brightness.light);

  /// Build theme with a custom accent/primary color (from the user's color picker).
  static ThemeData buildWithAccent(Brightness brightness, Color accentColor) =>
      _buildTheme(brightness, primaryOverride: accentColor);

  static ThemeData _buildTheme(Brightness brightness,
      {Color? primaryOverride}) {
    final isDark = brightness == Brightness.dark;
    final bg = isDark ? darkBackground : lightBackground;
    final surface = isDark ? darkSurface : lightSurface;
    final primary = primaryOverride ?? (isDark ? darkPrimary : lightPrimary);
    final secondary = isDark ? darkSecondary : lightSecondary;
    final textPrimary = isDark ? darkTextPrimary : lightTextPrimary;
    final textSecondary = isDark ? darkTextSecondary : lightTextSecondary;

    final colorScheme = ColorScheme(
      brightness: brightness,
      primary: primary,
      onPrimary: Colors.white,
      secondary: secondary,
      onSecondary: Colors.white,
      error: statusOverdue,
      onError: Colors.white,
      surface: surface,
      onSurface: textPrimary,
      surfaceContainerHighest: isDark ? darkCard : lightCard,
    );

    final textTheme = GoogleFonts.nunitoTextTheme(
      TextTheme(
        displayLarge:
            TextStyle(color: textPrimary, fontWeight: FontWeight.w800),
        displayMedium:
            TextStyle(color: textPrimary, fontWeight: FontWeight.w700),
        displaySmall:
            TextStyle(color: textPrimary, fontWeight: FontWeight.w700),
        headlineLarge:
            TextStyle(color: textPrimary, fontWeight: FontWeight.w700),
        headlineMedium:
            TextStyle(color: textPrimary, fontWeight: FontWeight.w600),
        headlineSmall:
            TextStyle(color: textPrimary, fontWeight: FontWeight.w600),
        titleLarge: TextStyle(color: textPrimary, fontWeight: FontWeight.w700),
        titleMedium: TextStyle(color: textPrimary, fontWeight: FontWeight.w600),
        titleSmall: TextStyle(color: textPrimary, fontWeight: FontWeight.w500),
        bodyLarge: TextStyle(color: textPrimary),
        bodyMedium: TextStyle(color: textSecondary),
        bodySmall: TextStyle(color: textSecondary, fontSize: 12),
        labelLarge: TextStyle(color: textPrimary, fontWeight: FontWeight.w600),
        labelMedium:
            TextStyle(color: textSecondary, fontWeight: FontWeight.w500),
        labelSmall: TextStyle(color: textSecondary, fontSize: 11),
      ),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: bg,
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: bg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        // Status bar icons adapt to theme: white on dark, dark on light.
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
          statusBarBrightness:
              isDark ? Brightness.dark : Brightness.light, // iOS
          systemNavigationBarColor: Colors.transparent,
          systemNavigationBarIconBrightness:
              isDark ? Brightness.light : Brightness.dark,
          systemNavigationBarDividerColor: Colors.transparent,
        ),
        titleTextStyle: GoogleFonts.nunito(
          color: textPrimary,
          fontSize: 22,
          fontWeight: FontWeight.w700,
        ),
        iconTheme: IconThemeData(color: textPrimary),
      ),
      cardTheme: CardThemeData(
        color: isDark ? darkCard : lightCard,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        margin: EdgeInsets.zero,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surface,
        indicatorColor: primary.withValues(alpha: 0.18),
        labelTextStyle: WidgetStateProperty.all(
          GoogleFonts.nunito(
              fontSize: 12, fontWeight: FontWeight.w600, color: textSecondary),
        ),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return IconThemeData(color: primary, size: 24);
          }
          return IconThemeData(color: textSecondary, size: 24);
        }),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? darkCard : lightCard,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        hintStyle: TextStyle(color: textSecondary, fontSize: 14),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: isDark ? darkCard : lightCard,
        labelStyle:
            GoogleFonts.nunito(fontSize: 13, fontWeight: FontWeight.w600),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        side: BorderSide.none,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          elevation: 0,
          textStyle:
              GoogleFonts.nunito(fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primary,
          side: BorderSide(color: primary, width: 1.5),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          textStyle:
              GoogleFonts.nunito(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected) ? primary : textSecondary),
        trackColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.selected)
                ? primary.withValues(alpha: 0.35)
                : textSecondary.withValues(alpha: 0.2)),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: primary,
        thumbColor: primary,
        inactiveTrackColor: textSecondary.withValues(alpha: 0.3),
      ),
      dividerTheme: DividerThemeData(
        color: textSecondary.withValues(alpha: 0.15),
        thickness: 1,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        showDragHandle: true,
      ),
    );
  }
}
