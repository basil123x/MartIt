// app_colors.dart — Albadaa Veterinary Services Brand Colors
import 'package:flutter/material.dart';

class AppColors {
  // ── Primary (الأزرق الكحلي من الشعار)
  static const Color primary      = Color(0xFF1E3A8A);
  static const Color primaryDark  = Color(0xFF142760);
  static const Color primaryLight = Color(0xFF2D55C8);

  // ── Secondary (أزرق فاتح للتمييز)
  static const Color secondary      = Color(0xFF3B6FD4);
  static const Color secondaryDark  = Color(0xFF2952A3);
  static const Color secondaryLight = Color(0xFF6B97E8);

  // ── Accent (أزرق سماوي للتفاصيل)
  static const Color accent      = Color(0xFF4A90D9);
  static const Color accentDark  = Color(0xFF2E6BAF);
  static const Color accentLight = Color(0xFF7FB3E8);

  // ── Gradients
  static const LinearGradient brandGradient = LinearGradient(
    colors: [Color(0xFF2D55C8), Color(0xFF1E3A8A)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const LinearGradient bgGradient = LinearGradient(
    colors: [Color(0xFF1E3A8A), Color(0xFF142760)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
  // لا يوجد ذهبي في الشعار — استبدلناه بأزرق فاتح
  static const LinearGradient accentGradient = LinearGradient(
    colors: [Color(0xFF6B97E8), Color(0xFF3B6FD4)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // ── Neutral
  static const Color black     = Color(0xFF000000);
  static const Color white     = Color(0xFFFFFFFF);
  static const Color grey      = Color(0xFF9E9E9E);
  static const Color lightGrey = Color(0xFFF5F5F5);
  static const Color darkGrey  = Color(0xFF424242);

  // ── Background
  static const Color background     = Color(0xFFF0F4FB);  // أبيض مايل للأزرق الفاتح جداً
  static const Color surface        = Color(0xFFFFFFFF);
  static const Color cardBackground = Color(0xFFFFFFFF);

  // ── Text
  static const Color textPrimary   = Color(0xFF1E3A8A);   // كحلي داكن (نفس Primary)
  static const Color textSecondary = Color(0xFF4A6080);   // كحلي رمادي
  static const Color textHint      = Color(0xFFBDBDBD);

  // ── Status
  static const Color success = Color(0xFF4CAF50);
  static const Color error   = Color(0xFFF44336);
  static const Color warning = Color(0xFFFFA726);
  static const Color info    = Color(0xFF1E3A8A);

  // ── Veterinary App Specific
  static const Color priceColor    = Color(0xFF1E3A8A);   // أزرق للسعر
  static const Color discountColor = Color(0xFF3B6FD4);   // أزرق فاتح للخصم
  static const Color cartColor     = Color(0xFF1E3A8A);
  static const Color badgeColor    = Color(0xFF2D55C8);
}