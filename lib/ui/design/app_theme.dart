import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:zentflow/models/app_theme_mode.dart';
import 'package:zentflow/ui/design/app_colors.dart';

class AppTheme {
  static ThemeData fromMode(AppThemeMode mode) {
    final brightness = mode == AppThemeMode.light ? Brightness.light : Brightness.dark;
    final bg = switch (mode) {
      AppThemeMode.light => AppColors.backgroundLight,
      AppThemeMode.dark => AppColors.backgroundDark,
      AppThemeMode.amoled => AppColors.backgroundAmoled,
    };
    final fg = switch (mode) {
      AppThemeMode.light => AppColors.foregroundLight,
      AppThemeMode.dark => AppColors.foregroundDark,
      AppThemeMode.amoled => AppColors.foregroundAmoled,
    };
    final mutedFg = switch (mode) {
      AppThemeMode.light => AppColors.mutedForegroundLight,
      AppThemeMode.dark => AppColors.mutedForegroundDark,
      AppThemeMode.amoled => AppColors.mutedForegroundAmoled,
    };

    final base = GoogleFonts.nunitoSansTextTheme();
    return ThemeData(
      brightness: brightness,
      useMaterial3: true,
      scaffoldBackgroundColor: bg,
      textTheme: base.copyWith(
        titleLarge: GoogleFonts.nunitoSans(color: fg, fontWeight: FontWeight.w700),
        bodyMedium: base.bodyMedium?.copyWith(color: fg, fontWeight: FontWeight.w500),
        bodySmall: base.bodySmall?.copyWith(color: mutedFg, fontWeight: FontWeight.w500),
      ),
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        brightness: brightness,
        primary: AppColors.primary,
        secondary: AppColors.secondary,
        error: AppColors.destructive,
        surface: bg,
        onSurface: fg,
      ),
    );
  }
}

