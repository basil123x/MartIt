// app_colors.dart — MartIt Brand Colors (light purple + dark neon-lime)
import 'package:flutter/material.dart';

class AppColors {
  // ── Light brand (purple)
  static const Color primary = Color(0xFF5C33EA);
  static const Color primaryDark = Color(0xFF4A28C4);
  static const Color primaryLight = Color(0xFF8B7AF0);
  static const Color primaryContainer = Color(0xFFEAE5FC);
  static const Color fieldBg = Color(0xFFF5F3FF);
  static const Color fieldBorder = Color(0xFFE0DBF5);
  static const Color dividerLight = Color(0xFFEDEAF7);

  // ── Legacy aliases kept for older call sites
  static const Color secondary = Color(0xFFD4863C);
  static const Color secondaryDark = Color(0xFFB8702A);
  static const Color secondaryLight = Color(0xFFE8A05A);

  static const LinearGradient brandGradient = LinearGradient(
    colors: [Color(0xFFE8A05A), Color(0xFFD4863C)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // ── Neutral
  static const Color black = Color(0xFF000000);
  static const Color white = Color(0xFFFFFFFF);
  static const Color grey = Color(0xFF9E9E9E);
  static const Color lightGrey = Color(0xFFF5F5F5);
  static const Color darkGrey = Color(0xFF424242);

  // ── Light surfaces / text
  static const Color background = Color(0xFFFFFFFF);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color cardBackground = Color(0xFFFFFFFF);
  static const Color textPrimary = Color(0xFF1A1333);
  static const Color textSecondary = Color(0xFF6B6B80);
  static const Color textHint = Color(0xFFA9A9B2);

  // ── Status
  static const Color success = Color(0xFF4CAF50);
  static const Color error = Color(0xFFE5484D);
  static const Color warning = Color(0xFFFF9800);
  static const Color info = Color(0xFF2196F3);
  static const Color dangerBg = Color(0xFFFDEAEA);

  // ── Shopping
  static const Color priceColor = Color(0xFF4CAF50);
  static const Color discountColor = Color(0xFFD4863C);
  static const Color cartColor = Color(0xFFE8A05A);

  // ── Dark Mode (black + neon-lime)
  static const Color darkBackground = Color(0xFF0E0E10);
  static const Color darkSurface = Color(0xFF1C1C1F);
  static const Color darkElevated = Color(0xFF2A2A2E);
  static const Color darkPrimary = Color(0xFFC6FF3D);
  static const Color darkOnPrimary = Color(0xFF0E0E10);
  static const Color darkText = Color(0xFFFFFFFF);
  static const Color darkTextSecondary = Color(0xFFA9A9B2);
  static const Color darkBorder = Color(0xFF2A2A2E);
  static const Color darkDivider = Color(0xFF2A2A2E);

  /// Theme-aware helpers — prefer Theme.of(context).colorScheme when possible.
  static Color textColor(BuildContext context) =>
      Theme.of(context).colorScheme.onSurface;

  static Color textSecondaryColor(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? darkTextSecondary
          : textSecondary;

  static Color brand(BuildContext context) =>
      Theme.of(context).colorScheme.primary;

  static Color iconPillBg(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? darkElevated
          : primaryContainer;

  static Color fieldFill(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? darkSurface
          : fieldBg;
}
