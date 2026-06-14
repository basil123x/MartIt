import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

extension AppThemeContext on BuildContext {
  bool get isDarkMode => Theme.of(this).brightness == Brightness.dark;

  Color get appBackground => Theme.of(this).scaffoldBackgroundColor;

  Color get appSurface => Theme.of(this).colorScheme.surface;

  Color get appSurfaceVariant => Theme.of(this).colorScheme.surfaceContainerHighest;

  Color get appTextPrimary => Theme.of(this).colorScheme.onSurface;

  Color get appTextSecondary => isDarkMode
      ? AppColors.darkTextSecondary
      : AppColors.textSecondary;

  Color get appBorder =>
      isDarkMode ? AppColors.darkBorder : Colors.black.withOpacity(0.08);

  Color get appCardBorder =>
      isDarkMode ? AppColors.darkBorder : Colors.grey.shade200;

  List<Color> get surfaceGradientColors => isDarkMode
      ? [AppColors.darkSurface, AppColors.darkElevated]
      : [
          const Color(0xFFD4D4F0),
          const Color(0xFFC8D4F5),
          const Color(0xFFB4D4F0),
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
        colors: [AppColors.darkSurface, AppColors.darkElevated],
      );
    }
    return LinearGradient(
      begin: begin,
      end: end,
      colors: [
        const Color(0xFFD4D4F0),
        const Color(0xFFC8D4F5),
        const Color(0xFFB4D4F0),
      ],
    );
  }
}
