// app_colors.dart — GlobalFarm Brand Colors
import 'package:flutter/material.dart';

class AppColors {
  // ── Primary (الأخضر الزيتوني من الدائرة)
  static const Color primary      = Color(0xFF5C6B2E);
  static const Color primaryDark  = Color(0xFF3E4A1E);
  static const Color primaryLight = Color(0xFF7A9040);

  // ── Secondary (البني الداكن من حرف G)
  static const Color secondary      = Color(0xFF4A3728);
  static const Color secondaryDark  = Color(0xFF2E2018);
  static const Color secondaryLight = Color(0xFF6B5040);

  // ── Accent (الأزرق الرمادي من حرف F)
  static const Color accent      = Color(0xFF2E5B7A);
  static const Color accentDark  = Color(0xFF1C3D55);
  static const Color accentLight = Color(0xFF4A7A9B);

  // ── Gradients
  static const LinearGradient brandGradient = LinearGradient(
    colors: [Color(0xFF7A9040), Color(0xFF5C6B2E)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const LinearGradient bgGradient = LinearGradient(
    colors: [Color(0xFF5C6B2E), Color(0xFF3E4A1E)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  // ── Neutral
  static const Color black     = Color(0xFF000000);
  static const Color white     = Color(0xFFFFFFFF);
  static const Color grey      = Color(0xFF9E9E9E);
  static const Color lightGrey = Color(0xFFF5F5F5);
  static const Color darkGrey  = Color(0xFF424242);

  // ── Background
  static const Color background     = Color(0xFFF8F6F2);
  static const Color surface        = Color(0xFFFFFFFF);
  static const Color cardBackground = Color(0xFFFFFFFF);

  // ── Text
  static const Color textPrimary   = Color(0xFF2E2018);
  static const Color textSecondary = Color(0xFF6B5040);
  static const Color textHint      = Color(0xFFBDBDBD);

  // ── Status
  static const Color success = Color(0xFF5C6B2E);
  static const Color error   = Color(0xFFF44336);
  static const Color warning = Color(0xFF4A3728);
  static const Color info    = Color(0xFF2E5B7A);

  // ── Shopping
  static const Color priceColor    = Color(0xFF5C6B2E);
  static const Color discountColor = Color(0xFF4A3728);
  static const Color cartColor     = Color(0xFF2E5B7A);
}