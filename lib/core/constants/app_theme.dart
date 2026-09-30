import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

/// Extra MartIt tokens not covered cleanly by ColorScheme alone.
@immutable
class MartItColors extends ThemeExtension<MartItColors> {
  final Color iconPillBg;
  final Color fieldBg;
  final Color fieldBorder;
  final Color divider;
  final Color mutedText;
  final Color receivedBubble;
  final Color emptyIcon;
  final Color dangerBg;

  const MartItColors({
    required this.iconPillBg,
    required this.fieldBg,
    required this.fieldBorder,
    required this.divider,
    required this.mutedText,
    required this.receivedBubble,
    required this.emptyIcon,
    required this.dangerBg,
  });

  static const light = MartItColors(
    iconPillBg: AppColors.primaryContainer,
    fieldBg: AppColors.fieldBg,
    fieldBorder: AppColors.fieldBorder,
    divider: AppColors.dividerLight,
    mutedText: AppColors.textSecondary,
    receivedBubble: Color(0xFFF0EEFA),
    emptyIcon: Color(0xFFC9BFF5),
    dangerBg: AppColors.dangerBg,
  );

  static const dark = MartItColors(
    iconPillBg: AppColors.darkElevated,
    fieldBg: AppColors.darkSurface,
    fieldBorder: AppColors.darkBorder,
    divider: AppColors.darkDivider,
    mutedText: AppColors.darkTextSecondary,
    receivedBubble: AppColors.darkElevated,
    emptyIcon: Color(0xFF5A5A62),
    dangerBg: Color(0xFF3A1F1F),
  );

  @override
  MartItColors copyWith({
    Color? iconPillBg,
    Color? fieldBg,
    Color? fieldBorder,
    Color? divider,
    Color? mutedText,
    Color? receivedBubble,
    Color? emptyIcon,
    Color? dangerBg,
  }) {
    return MartItColors(
      iconPillBg: iconPillBg ?? this.iconPillBg,
      fieldBg: fieldBg ?? this.fieldBg,
      fieldBorder: fieldBorder ?? this.fieldBorder,
      divider: divider ?? this.divider,
      mutedText: mutedText ?? this.mutedText,
      receivedBubble: receivedBubble ?? this.receivedBubble,
      emptyIcon: emptyIcon ?? this.emptyIcon,
      dangerBg: dangerBg ?? this.dangerBg,
    );
  }

  @override
  MartItColors lerp(ThemeExtension<MartItColors>? other, double t) {
    if (other is! MartItColors) return this;
    return MartItColors(
      iconPillBg: Color.lerp(iconPillBg, other.iconPillBg, t)!,
      fieldBg: Color.lerp(fieldBg, other.fieldBg, t)!,
      fieldBorder: Color.lerp(fieldBorder, other.fieldBorder, t)!,
      divider: Color.lerp(divider, other.divider, t)!,
      mutedText: Color.lerp(mutedText, other.mutedText, t)!,
      receivedBubble: Color.lerp(receivedBubble, other.receivedBubble, t)!,
      emptyIcon: Color.lerp(emptyIcon, other.emptyIcon, t)!,
      dangerBg: Color.lerp(dangerBg, other.dangerBg, t)!,
    );
  }
}

extension MartItThemeX on BuildContext {
  MartItColors get martItColors =>
      Theme.of(this).extension<MartItColors>() ?? MartItColors.light;
}

class AppTheme {
  static ColorScheme get _lightScheme => const ColorScheme(
        brightness: Brightness.light,
        primary: AppColors.primary,
        onPrimary: Colors.white,
        primaryContainer: AppColors.primaryContainer,
        onPrimaryContainer: AppColors.primary,
        secondary: AppColors.primaryLight,
        onSecondary: Colors.white,
        secondaryContainer: AppColors.fieldBg,
        onSecondaryContainer: AppColors.textPrimary,
        surface: AppColors.surface,
        onSurface: AppColors.textPrimary,
        onSurfaceVariant: AppColors.textSecondary,
        surfaceContainerHighest: AppColors.fieldBg,
        error: AppColors.error,
        onError: Colors.white,
        outline: AppColors.fieldBorder,
        outlineVariant: AppColors.dividerLight,
      );

  static ColorScheme get _darkScheme => const ColorScheme(
        brightness: Brightness.dark,
        primary: AppColors.darkPrimary,
        onPrimary: AppColors.darkOnPrimary,
        primaryContainer: AppColors.darkElevated,
        onPrimaryContainer: AppColors.darkPrimary,
        secondary: AppColors.darkPrimary,
        onSecondary: AppColors.darkOnPrimary,
        secondaryContainer: AppColors.darkElevated,
        onSecondaryContainer: AppColors.darkText,
        surface: AppColors.darkSurface,
        onSurface: AppColors.darkText,
        onSurfaceVariant: AppColors.darkTextSecondary,
        surfaceContainerHighest: AppColors.darkElevated,
        error: AppColors.error,
        onError: Colors.white,
        outline: AppColors.darkBorder,
        outlineVariant: AppColors.darkDivider,
      );

  static ThemeData get lightTheme {
    final scheme = _lightScheme;
    final textTheme = _textTheme(scheme);
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.background,
      extensions: const [MartItColors.light],
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.background,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: scheme.primary),
        titleTextStyle: textTheme.titleLarge?.copyWith(
          color: scheme.onSurface,
          fontWeight: FontWeight.bold,
        ),
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
          statusBarBrightness: Brightness.light,
        ),
      ),
      cardTheme: CardThemeData(
        color: scheme.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant,
        thickness: 1,
        space: 1,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          disabledBackgroundColor: AppColors.fieldBorder,
          disabledForegroundColor: AppColors.textHint,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: scheme.primary,
          side: BorderSide(color: scheme.primary),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: scheme.primary),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: MartItColors.light.fieldBg,
        hintStyle: TextStyle(color: scheme.onSurfaceVariant),
        labelStyle: TextStyle(color: scheme.onSurfaceVariant),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.error),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          return Colors.white;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return scheme.primary;
          return AppColors.fieldBorder;
        }),
        trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
      ),
      listTileTheme: ListTileThemeData(
        textColor: scheme.onSurface,
        iconColor: scheme.primary,
      ),
      iconTheme: IconThemeData(color: scheme.onSurface, size: 24),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        elevation: 4,
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: scheme.surface,
        selectedItemColor: scheme.primary,
        unselectedItemColor: scheme.onSurfaceVariant,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.primary,
      ),
      textTheme: textTheme,
      dividerColor: scheme.outlineVariant,
    );
  }

  static ThemeData get darkTheme {
    final scheme = _darkScheme;
    final textTheme = _textTheme(scheme);
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.darkBackground,
      extensions: const [MartItColors.dark],
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.darkBackground,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: scheme.primary),
        titleTextStyle: textTheme.titleLarge?.copyWith(
          color: scheme.onSurface,
          fontWeight: FontWeight.bold,
        ),
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
        ),
      ),
      cardTheme: CardThemeData(
        color: scheme.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: scheme.outline),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant,
        thickness: 1,
        space: 1,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          disabledBackgroundColor: AppColors.darkElevated,
          disabledForegroundColor: AppColors.darkTextSecondary,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: scheme.primary,
          side: BorderSide(color: scheme.primary),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: scheme.primary),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: MartItColors.dark.fieldBg,
        hintStyle: TextStyle(color: scheme.onSurfaceVariant),
        labelStyle: TextStyle(color: scheme.onSurfaceVariant),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.error),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          return Colors.white;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return scheme.primary;
          return AppColors.darkElevated;
        }),
        trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
      ),
      listTileTheme: ListTileThemeData(
        textColor: scheme.onSurface,
        iconColor: scheme.primary,
      ),
      iconTheme: IconThemeData(color: scheme.onSurface, size: 24),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: AppColors.darkBackground,
        selectedItemColor: scheme.primary,
        unselectedItemColor: scheme.onSurfaceVariant,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.primary,
      ),
      textTheme: textTheme,
      dividerColor: scheme.outlineVariant,
    );
  }

  static TextTheme _textTheme(ColorScheme scheme) {
    return GoogleFonts.cairoTextTheme().copyWith(
      headlineLarge: GoogleFonts.cairo(
        fontSize: 32,
        fontWeight: FontWeight.bold,
        color: scheme.onSurface,
      ),
      headlineMedium: GoogleFonts.cairo(
        fontSize: 28,
        fontWeight: FontWeight.bold,
        color: scheme.onSurface,
      ),
      headlineSmall: GoogleFonts.cairo(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        color: scheme.onSurface,
      ),
      titleLarge: GoogleFonts.cairo(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: scheme.onSurface,
      ),
      titleMedium: GoogleFonts.cairo(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        color: scheme.onSurface,
      ),
      titleSmall: GoogleFonts.cairo(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: scheme.onSurface,
      ),
      bodyLarge: GoogleFonts.cairo(fontSize: 16, color: scheme.onSurface),
      bodyMedium: GoogleFonts.cairo(
        fontSize: 14,
        color: scheme.onSurfaceVariant,
      ),
      bodySmall: GoogleFonts.cairo(
        fontSize: 12,
        color: scheme.onSurfaceVariant,
      ),
    );
  }
}
