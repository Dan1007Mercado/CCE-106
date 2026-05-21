import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../constants/app_sizes.dart';

class AppTheme {
  static const Duration motionDuration = Duration(milliseconds: 240);
  static const Duration motionReverseDuration = Duration(milliseconds: 200);
  static const Curve motionCurve = Curves.easeInOutCubic;

  static ThemeData get lightTheme => _buildTheme(Brightness.light);

  static ThemeData get darkTheme => _buildTheme(Brightness.dark);

  static Color resolveOnColor(Color background) {
    const lightText = Color(0xFFF8FAFC);
    const darkText = Color(0xFF0F172A);

    final lightContrast = _contrastRatio(background, lightText);
    final darkContrast = _contrastRatio(background, darkText);
    return lightContrast >= darkContrast ? lightText : darkText;
  }

  static ThemeData _buildTheme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final baseColorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: brightness,
    );

    final backgroundColor = isDark
        ? const Color(0xFF09141A)
        : AppColors.background;
    final surfaceColor = isDark ? const Color(0xFF16232A) : Colors.white;
    final surfaceContainerColor = isDark
        ? const Color(0xFF1C2B35)
        : const Color(0xFFF9F6F1);
    final borderColor = isDark ? const Color(0xFF33505D) : AppColors.border;
    final avatarBackground = isDark
        ? const Color(0xFF3B82F6)
        : const Color(0xFF2563EB);

    final colorScheme = baseColorScheme.copyWith(
      primary: AppColors.primary,
      onPrimary: resolveOnColor(AppColors.primary),
      secondary: AppColors.accent,
      onSecondary: resolveOnColor(AppColors.accent),
      tertiary: avatarBackground,
      onTertiary: resolveOnColor(avatarBackground),
      surface: surfaceColor,
      onSurface: resolveOnColor(surfaceColor),
      surfaceContainerHighest: surfaceContainerColor,
      outline: borderColor,
      outlineVariant: borderColor.withValues(alpha: isDark ? 0.92 : 1),
      error: AppColors.error,
      onError: resolveOnColor(AppColors.error),
    );

    final textPrimary = colorScheme.onSurface;
    final textSecondary = isDark
        ? const Color(0xFFB9C7D1)
        : AppColors.textSecondary;
    final tokens = AppThemeTokens(
      pageGradientStart: isDark
          ? const Color(0xFF102129)
          : const Color(0xFFEAF6F2),
      pageGradientEnd: backgroundColor,
      primarySoft: _softFill(
        AppColors.primary,
        surfaceColor,
        isDark ? 0.26 : 0.10,
      ),
      accentSoft: _softFill(
        AppColors.accent,
        surfaceColor,
        isDark ? 0.24 : 0.18,
      ),
      successSoft: _softFill(
        AppColors.success,
        surfaceColor,
        isDark ? 0.24 : 0.16,
      ),
      warningSoft: _softFill(
        AppColors.accent,
        surfaceColor,
        isDark ? 0.30 : 0.20,
      ),
      subtleSurface: _softFill(
        colorScheme.primary,
        surfaceColor,
        isDark ? 0.18 : 0.08,
      ),
      avatarBackground: avatarBackground,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: backgroundColor,
      canvasColor: backgroundColor,
      splashFactory: InkRipple.splashFactory,
      visualDensity: VisualDensity.standard,
      extensions: [tokens],
      appBarTheme: AppBarTheme(
        backgroundColor: backgroundColor,
        foregroundColor: textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: CardThemeData(
        color: surfaceColor,
        elevation: 0,
        margin: EdgeInsets.zero,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusLg),
          side: BorderSide(color: borderColor),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceColor,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 18,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusMd),
          borderSide: BorderSide(color: borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusMd),
          borderSide: BorderSide(color: borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusMd),
          borderSide: BorderSide(color: colorScheme.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusMd),
          borderSide: BorderSide(color: colorScheme.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusMd),
          borderSide: BorderSide(color: colorScheme.error, width: 1.5),
        ),
        labelStyle: TextStyle(color: textSecondary),
        hintStyle: TextStyle(color: textSecondary),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          minimumSize: const Size.fromHeight(AppSizes.buttonHeight),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSizes.radiusMd),
          ),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          animationDuration: motionDuration,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: colorScheme.primary,
          side: BorderSide(color: borderColor),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSizes.radiusMd),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
          animationDuration: motionDuration,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: colorScheme.primary,
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
          animationDuration: motionDuration,
        ),
      ),
      tabBarTheme: TabBarThemeData(
        dividerColor: Colors.transparent,
        indicatorSize: TabBarIndicatorSize.tab,
        labelColor: colorScheme.onPrimary,
        unselectedLabelColor: textSecondary,
        overlayColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.pressed)) {
            return colorScheme.primary.withValues(alpha: 0.10);
          }
          return null;
        }),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: tokens.subtleSurface,
        selectedColor: colorScheme.primary,
        secondarySelectedColor: colorScheme.primary,
        side: BorderSide(color: borderColor),
        labelStyle: TextStyle(color: resolveOnColor(tokens.subtleSurface)),
        secondaryLabelStyle: TextStyle(color: colorScheme.onPrimary),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isDark
            ? const Color(0xFF20323B)
            : AppColors.textPrimary,
        contentTextStyle: TextStyle(
          color: resolveOnColor(
            isDark ? const Color(0xFF20323B) : AppColors.textPrimary,
          ),
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surfaceColor,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surfaceColor,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusLg),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      dividerColor: borderColor,
      dividerTheme: DividerThemeData(color: borderColor, thickness: 1),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: colorScheme.primary,
      ),
      listTileTheme: ListTileThemeData(
        iconColor: textSecondary,
        textColor: textPrimary,
      ),
      textTheme: ThemeData(
        brightness: brightness,
      ).textTheme.apply(bodyColor: textPrimary, displayColor: textPrimary),
    );
  }

  static Color _softFill(Color tint, Color base, double opacity) {
    return Color.alphaBlend(tint.withValues(alpha: opacity), base);
  }

  static double _contrastRatio(Color first, Color second) {
    final firstLuminance = first.computeLuminance();
    final secondLuminance = second.computeLuminance();
    final lighter = math.max(firstLuminance, secondLuminance);
    final darker = math.min(firstLuminance, secondLuminance);
    return (lighter + 0.05) / (darker + 0.05);
  }
}

@immutable
class AppThemeTokens extends ThemeExtension<AppThemeTokens> {
  const AppThemeTokens({
    required this.pageGradientStart,
    required this.pageGradientEnd,
    required this.primarySoft,
    required this.accentSoft,
    required this.successSoft,
    required this.warningSoft,
    required this.subtleSurface,
    required this.avatarBackground,
  });

  final Color pageGradientStart;
  final Color pageGradientEnd;
  final Color primarySoft;
  final Color accentSoft;
  final Color successSoft;
  final Color warningSoft;
  final Color subtleSurface;
  final Color avatarBackground;

  @override
  AppThemeTokens copyWith({
    Color? pageGradientStart,
    Color? pageGradientEnd,
    Color? primarySoft,
    Color? accentSoft,
    Color? successSoft,
    Color? warningSoft,
    Color? subtleSurface,
    Color? avatarBackground,
  }) {
    return AppThemeTokens(
      pageGradientStart: pageGradientStart ?? this.pageGradientStart,
      pageGradientEnd: pageGradientEnd ?? this.pageGradientEnd,
      primarySoft: primarySoft ?? this.primarySoft,
      accentSoft: accentSoft ?? this.accentSoft,
      successSoft: successSoft ?? this.successSoft,
      warningSoft: warningSoft ?? this.warningSoft,
      subtleSurface: subtleSurface ?? this.subtleSurface,
      avatarBackground: avatarBackground ?? this.avatarBackground,
    );
  }

  @override
  AppThemeTokens lerp(ThemeExtension<AppThemeTokens>? other, double t) {
    if (other is! AppThemeTokens) {
      return this;
    }

    return AppThemeTokens(
      pageGradientStart: Color.lerp(
        pageGradientStart,
        other.pageGradientStart,
        t,
      )!,
      pageGradientEnd: Color.lerp(pageGradientEnd, other.pageGradientEnd, t)!,
      primarySoft: Color.lerp(primarySoft, other.primarySoft, t)!,
      accentSoft: Color.lerp(accentSoft, other.accentSoft, t)!,
      successSoft: Color.lerp(successSoft, other.successSoft, t)!,
      warningSoft: Color.lerp(warningSoft, other.warningSoft, t)!,
      subtleSurface: Color.lerp(subtleSurface, other.subtleSurface, t)!,
      avatarBackground: Color.lerp(
        avatarBackground,
        other.avatarBackground,
        t,
      )!,
    );
  }
}

extension AppThemeDataX on ThemeData {
  AppThemeTokens get tokens => extension<AppThemeTokens>()!;
}
