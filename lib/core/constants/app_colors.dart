// app_colors.dart — MartIt Brand Colors
import 'package:flutter/material.dart';

class AppColors {
  // ── Primary (Blue من الشعار)
  static const Color primary      = Color.fromARGB(255, 13, 72, 161);
  static const Color primaryDark  = Color.fromARGB(255, 11, 59, 131);
  static const Color primaryLight = Color(0xFF5568C8);

  // ── Secondary (Orange من الـ M)
  static const Color secondary      = Color(0xFFD4863C);
  static const Color secondaryDark  = Color(0xFFB8702A);
  static const Color secondaryLight = Color(0xFFE8A05A);

  // ── Gradient
  static const LinearGradient brandGradient = LinearGradient(
    colors: [Color(0xFFE8A05A), Color(0xFFD4863C)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const LinearGradient bgGradient = LinearGradient(
    colors: [Color(0xFF3346B0), Color(0xFF2438A0)],
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
  static const Color discountColor = Color(0xFFD4863C);
  static const Color cartColor     = Color(0xFFE8A05A);
}