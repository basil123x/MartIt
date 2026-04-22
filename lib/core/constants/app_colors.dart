// app_colors.dart — MartIt Brand Colors
import 'package:flutter/material.dart';

class AppColors {
  // ── Primary (Deep Purple من الخلفية)
  static const Color primary      = Color(0xFF2D2870);
  static const Color primaryDark   = Color(0xFF1E1A52);
  static const Color primaryLight  = Color(0xFF4A40A8);

  // ── Secondary (Orange Gradient من الـ M)
  static const Color secondary      = Color(0xFFF97316);
  static const Color secondaryDark  = Color(0xFFFF8C00);
  static const Color secondaryLight = Color(0xFFFFB347);

  // ── Gradient (نفس تدرج الـ M في الشعار)
  static const LinearGradient brandGradient = LinearGradient(
    colors: [Color(0xFFFFD580), Color(0xFFF97316)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const LinearGradient bgGradient = LinearGradient(
    colors: [Color(0xFF2D2870), Color(0xFF1E1A52)],
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
  static const Color background     = Color(0xFFFAFAFA);
  static const Color surface        = Color(0xFFFFFFFF);
  static const Color cardBackground = Color(0xFFFFFFFF);

  // ── Text
  static const Color textPrimary   = Color(0xFF212121);
  static const Color textSecondary = Color(0xFF757575);
  static const Color textHint      = Color(0xFFBDBDBD);

  // ── Status
  static const Color success = Color(0xFF4CAF50);
  static const Color error   = Color(0xFFF44336);
  static const Color warning = Color(0xFFFF9800);
  static const Color info    = Color(0xFF2196F3);

  // ── Shopping
  static const Color priceColor    = Color(0xFF4CAF50);
  static const Color discountColor = Color(0xFFF97316);
  static const Color cartColor     = Color(0xFFFFB347);
}