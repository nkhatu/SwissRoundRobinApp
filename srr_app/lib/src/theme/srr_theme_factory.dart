// ---------------------------------------------------------------------------
// srr_app/lib/src/theme/srr_theme_factory.dart
// ---------------------------------------------------------------------------
//
// Purpose:
// - Builds the complete ThemeData for each supported SRR theme variant.
// Architecture:
// - Theme composition service used by the app shell through DI.
// - Encapsulates typography, component themes, and color scheme selection.
// Author: Neil Khatu
// Copyright (c) The Khatu Family Trust
//
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'srr_split_action_button_theme.dart';
import 'srr_theme_controller.dart';

class SrrThemeFactory {
  const SrrThemeFactory();

  ThemeData build(SrrThemeVariant variant) {
    final colorScheme = _colorSchemeForVariant(variant);
    final brightness = colorScheme.brightness;
    final isDark = brightness == Brightness.dark;

    final baseText = GoogleFonts.plusJakartaSansTextTheme(
      ThemeData(brightness: brightness, useMaterial3: true).textTheme,
    );
    final headlineFont = GoogleFonts.dmSerifDisplayTextTheme(baseText);

    final textTheme = baseText.copyWith(
      displayLarge: headlineFont.displayLarge?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: 0.3,
      ),
      displayMedium: headlineFont.displayMedium?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: 0.2,
      ),
      headlineLarge: headlineFont.headlineLarge?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: 0.2,
      ),
      headlineMedium: headlineFont.headlineMedium?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: 0.2,
      ),
      titleLarge: baseText.titleLarge?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: 0.15,
      ),
      titleMedium: baseText.titleMedium?.copyWith(
        fontWeight: FontWeight.w600,
        letterSpacing: 0.1,
      ),
      bodyLarge: baseText.bodyLarge?.copyWith(height: 1.35),
      bodyMedium: baseText.bodyMedium?.copyWith(height: 1.35),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: colorScheme.surface,
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          color: colorScheme.onPrimary,
          fontWeight: FontWeight.w700,
          fontSize: 22,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: isDark ? 0 : 1,
        color: colorScheme.surfaceContainerLow,
        shadowColor: colorScheme.shadow.withValues(alpha: isDark ? 0.0 : 0.15),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        margin: EdgeInsets.zero,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          textStyle: textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
          minimumSize: const Size(0, 40),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: colorScheme.primary,
          textStyle: textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
          side: BorderSide(color: colorScheme.outline),
          minimumSize: const Size(0, 40),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colorScheme.surfaceContainerHigh,
        labelStyle: textTheme.bodyMedium?.copyWith(
          color: colorScheme.onSurfaceVariant,
        ),
        hintStyle: textTheme.bodyMedium?.copyWith(
          color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: colorScheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: colorScheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: colorScheme.primary, width: 1.4),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: colorScheme.error),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: colorScheme.secondaryContainer,
        selectedColor: colorScheme.primaryContainer,
        secondarySelectedColor: colorScheme.primaryContainer,
        labelStyle: textTheme.labelMedium?.copyWith(
          color: colorScheme.onSecondaryContainer,
          fontWeight: FontWeight.w600,
        ),
        side: BorderSide(color: colorScheme.outlineVariant),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: colorScheme.inverseSurface,
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: colorScheme.onInverseSurface,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        behavior: SnackBarBehavior.floating,
      ),
      dividerColor: colorScheme.outlineVariant,
      extensions: <ThemeExtension<dynamic>>[
        SrrSplitActionButtonTheme.fromColorScheme(colorScheme),
      ],
    );
  }

  ColorScheme _colorSchemeForVariant(SrrThemeVariant variant) {
    switch (variant) {
      case SrrThemeVariant.purple:
        return ColorScheme.fromSeed(
          seedColor: const Color(0xFF6E44FF),
          brightness: Brightness.light,
        ).copyWith(
          primary: const Color(0xFF5D35D6),
          secondary: const Color(0xFF9B59B6),
          tertiary: const Color(0xFF385FA9),
          surface: const Color(0xFFF8F5FF),
        );
      case SrrThemeVariant.orange:
        return ColorScheme.fromSeed(
          seedColor: const Color(0xFFE67E22),
          brightness: Brightness.light,
        ).copyWith(
          primary: const Color(0xFFD05A12),
          secondary: const Color(0xFF8F5B2A),
          tertiary: const Color(0xFF3A7288),
          surface: const Color(0xFFFFF8EF),
        );
      case SrrThemeVariant.pista:
        return ColorScheme.fromSeed(
          seedColor: const Color(0xFF7BAF45),
          brightness: Brightness.light,
        ).copyWith(
          primary: const Color(0xFF4A8A2E),
          secondary: const Color(0xFF2E7A64),
          tertiary: const Color(0xFF6D5B9C),
          surface: const Color(0xFFF6FAF0),
        );
      case SrrThemeVariant.dark:
        return ColorScheme.fromSeed(
          seedColor: const Color(0xFF4EB89A),
          brightness: Brightness.dark,
        ).copyWith(
          primary: const Color(0xFF73DCC0),
          secondary: const Color(0xFFFFB290),
          tertiary: const Color(0xFF9AB9FF),
          surface: const Color(0xFF0F1317),
        );
      case SrrThemeVariant.contrast:
        return const ColorScheme(
          brightness: Brightness.light,
          primary: Color(0xFF111111),
          onPrimary: Color(0xFFFFFFFF),
          secondary: Color(0xFF003DA5),
          onSecondary: Color(0xFFFFFFFF),
          tertiary: Color(0xFFC63D00),
          onTertiary: Color(0xFFFFFFFF),
          error: Color(0xFF8A0000),
          onError: Color(0xFFFFFFFF),
          surface: Color(0xFFFFFFFF),
          onSurface: Color(0xFF111111),
          surfaceContainerLowest: Color(0xFFFFFFFF),
          surfaceContainerLow: Color(0xFFF2F2F2),
          surfaceContainer: Color(0xFFE8E8E8),
          surfaceContainerHigh: Color(0xFFDDDDDD),
          surfaceContainerHighest: Color(0xFFD1D1D1),
          onSurfaceVariant: Color(0xFF1A1A1A),
          outline: Color(0xFF2E2E2E),
          outlineVariant: Color(0xFF616161),
        );
      case SrrThemeVariant.blue:
        return ColorScheme.fromSeed(
          seedColor: const Color(0xFF2F80ED),
          brightness: Brightness.light,
        ).copyWith(
          primary: const Color(0xFF235FBE),
          secondary: const Color(0xFF3A7C96),
          tertiary: const Color(0xFF7452A2),
          surface: const Color(0xFFF1F6FF),
        );
      case SrrThemeVariant.turquoise:
        return ColorScheme.fromSeed(
          seedColor: const Color(0xFF12A39C),
          brightness: Brightness.light,
        ).copyWith(
          primary: const Color(0xFF0F817A),
          secondary: const Color(0xFF2F768A),
          tertiary: const Color(0xFF4666A5),
          surface: const Color(0xFFEFFAF8),
        );
    }
  }
}
