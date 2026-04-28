// app_colors.dart — Golden Eagle Stores Brand Colors
import 'package:flutter/material.dart';

class AppColors {
  // ── Primary (الأزرق الرئيسي من الـ Navbar والـ Header)
  static const Color primary      = Color(0xFF1A6BB5);
  static const Color primaryDark  = Color(0xFF0D4A8A);
  static const Color primaryLight = Color(0xFF3D8FD1);

  // ── Secondary (الذهبي/البرتقالي من الـ Active Tabs والـ Highlights)
  static const Color secondary      = Color(0xFFF5A623);
  static const Color secondaryDark  = Color(0xFFD4880A);
  static const Color secondaryLight = Color(0xFFFFBF4D);

  // ── Accent (أزرق فاتح للتفاصيل والـ Hover)
  static const Color accent      = Color(0xFF2196F3);
  static const Color accentDark  = Color(0xFF1565C0);
  static const Color accentLight = Color(0xFF64B5F6);

  // ── Gradients
  static const LinearGradient brandGradient = LinearGradient(
    colors: [Color(0xFF3D8FD1), Color(0xFF1A6BB5)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const LinearGradient bgGradient = LinearGradient(
    colors: [Color(0xFF1A6BB5), Color(0xFF0D4A8A)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
  static const LinearGradient goldGradient = LinearGradient(
    colors: [Color(0xFFFFBF4D), Color(0xFFF5A623)],
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
  static const Color background     = Color(0xFFF0F4FA);  // بلاتيني فاتح مايل للأزرق
  static const Color surface        = Color(0xFFFFFFFF);
  static const Color cardBackground = Color(0xFFFFFFFF);

  // ── Text
  static const Color textPrimary   = Color(0xFF1A2A3A);   // كحلي داكن
  static const Color textSecondary = Color(0xFF4A6080);   // كحلي رمادي
  static const Color textHint      = Color(0xFFBDBDBD);

  // ── Status
  static const Color success = Color(0xFF4CAF50);
  static const Color error   = Color(0xFFF44336);
  static const Color warning = Color(0xFFF5A623);         // نفس الذهبي
  static const Color info    = Color(0xFF1A6BB5);         // نفس الأزرق

  // ── Shopping
  static const Color priceColor    = Color(0xFF1A6BB5);   // أزرق للسعر
  static const Color discountColor = Color(0xFFF5A623);   // ذهبي للخصم
  static const Color cartColor     = Color(0xFFF5A623);   // ذهبي للكارت (زي الموقع)
  static const Color badgeColor    = Color(0xFFF5A623);   // ذهبي للـ Badge (زي الـ 0 في الكارت)
}