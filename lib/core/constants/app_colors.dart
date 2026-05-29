// app_colors.dart — Albadaa Aquatic Brand Colors
import 'package:flutter/material.dart';

class AppColors {
  // ── Primary (الأزرق الليلي من الشعار)
  static const Color primary = Color(0xFF0D1B2E);
  static const Color primaryDark = Color(0xFF080F1A);
  static const Color primaryLight = Color(0xFF162840);

  // ── Secondary (أزرق متوسط للتباين)
  static const Color secondary = Color(0xFF1A3550);
  static const Color secondaryDark = Color(0xFF102236);
  static const Color secondaryLight = Color(0xFF254A6A);

  // ── Accent (ذهبي الشعار — اللون المميز)
  static const Color accent = Color(0xFFD4A017);
  static const Color accentDark = Color(0xFFA07810);
  static const Color accentLight = Color(0xFFF0C842);

  // ── Gradients
  static const LinearGradient brandGradient = LinearGradient(
    colors: [Color(0xFF1A3550), Color(0xFF0D1B2E)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const LinearGradient bgGradient = LinearGradient(
    colors: [Color(0xFF0D1B2E), Color(0xFF080F1A)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
  static const LinearGradient accentGradient = LinearGradient(
    colors: [Color(0xFFF0C842), Color(0xFFD4A017)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // ── Neutral
  static const Color black = Color(0xFF000000);
  static const Color white = Color(0xFFFFFFFF);
  static const Color grey = Color(0xFF9E9E9E);
  static const Color lightGrey = Color(0xFFF5F5F5);
  static const Color darkGrey = Color(0xFF424242);

  // ── Background
  static const Color background = Color(0xFF0D1B2E); // كحلي ليلي (نفس الشعار)
  static const Color surface = Color(0xFF162840);
  static const Color cardBackground = Color(0xFF1A3550);

  // ── Text
  static const Color textPrimary = Color(0xFFF0C842); // ذهبي للعناوين
  static const Color textSecondary = Color(0xFFB8CCE0); // أبيض مائل للأزرق
  static const Color textHint = Color(0xFF5A7A9A);

  // ── Status
  static const Color success = Color(0xFF4CAF50);
  static const Color error = Color(0xFFF44336);
  static const Color warning = Color(0xFFFFA726);
  static const Color info = Color(0xFF4A90D9);

  // ── App Specific
  static const Color priceColor = Color(0xFFD4A017); // ذهبي للسعر
  static const Color discountColor = Color(0xFFF0C842); // ذهبي فاتح للخصم
  static const Color cartColor = Color(0xFFD4A017);
  static const Color badgeColor = Color(0xFFF0C842);
}
