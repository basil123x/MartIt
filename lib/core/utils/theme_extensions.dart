import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_theme.dart';

extension AppThemeContext on BuildContext {
  bool get isDarkMode => Theme.of(this).brightness == Brightness.dark;

  ColorScheme get appColors => Theme.of(this).colorScheme;

  MartItColors get martIt => martItColors;

  Color get appBackground => Theme.of(this).scaffoldBackgroundColor;

  Color get appSurface => Theme.of(this).colorScheme.surface;

  Color get appSurfaceVariant =>
      Theme.of(this).colorScheme.surfaceContainerHighest;

  Color get appTextPrimary => Theme.of(this).colorScheme.onSurface;

  Color get appTextSecondary =>
      Theme.of(this).colorScheme.onSurfaceVariant;

  Color get appPrimary => Theme.of(this).colorScheme.primary;

  Color get appOnPrimary => Theme.of(this).colorScheme.onPrimary;

  Color get appBorder => Theme.of(this).colorScheme.outline;

  Color get appCardBorder => Theme.of(this).colorScheme.outlineVariant;

  Color get appIconPillBg => martItColors.iconPillBg;

  Color get appDivider => martItColors.divider;

  List<Color> get surfaceGradientColors => isDarkMode
      ? [AppColors.darkBackground, AppColors.darkSurface]
      : [
          const Color(0xFFF5F3FF),
          const Color(0xFFEAE5FC),
          Colors.white,
        ];

  LinearGradient surfaceGradient({
    Alignment begin = Alignment.topLeft,
    Alignment end = Alignment.bottomRight,
  }) {
    return LinearGradient(
      begin: begin,
      end: end,
      colors: surfaceGradientColors,
    );
  }

  LinearGradient bottomBarGradient({
    Alignment begin = Alignment.topCenter,
    Alignment end = Alignment.bottomCenter,
  }) {
    if (isDarkMode) {
      return LinearGradient(
        begin: begin,
        end: end,
        colors: const [AppColors.darkBackground, AppColors.darkSurface],
      );
    }
    return const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        Color(0xFFF5F3FF),
        Color(0xFFEAE5FC),
        Colors.white,
      ],
    );
  }
}
