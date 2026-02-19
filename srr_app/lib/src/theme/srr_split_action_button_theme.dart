// ---------------------------------------------------------------------------
// srr_app/lib/src/theme/srr_split_action_button_theme.dart
// ---------------------------------------------------------------------------
// 
// Purpose:
// - Defines theme extension values used by the SRR split action button component.
// Architecture:
// - Theme model module encapsulating button palette and style tokens.
// - Keeps reusable UI styling concerns separate from widget behavior code.
// Author: Neil Khatu
// Copyright (c) The Khatu Family Trust
// 
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

@immutable
class SrrSplitActionButtonTheme
    extends ThemeExtension<SrrSplitActionButtonTheme> {
  const SrrSplitActionButtonTheme({
    required this.borderRadius,
    required this.borderWidth,
    required this.actionSegmentWidth,
    required this.iconSize,
    required this.labelHorizontalPadding,
    required this.labelVerticalPadding,
    required this.dividerHeightInset,
    required this.shadowBlur,
    required this.shadowOffsetY,
    required this.filledShadowOpacity,
    required this.filledGradientHighlightOpacity,
    required this.filledGradientShadeOpacity,
    required this.filledActionShadeOpacity,
    required this.outlinedActionTintOpacity,
    required this.filledBackground,
    required this.filledForeground,
    required this.filledBorder,
    required this.filledDivider,
    required this.outlinedBackground,
    required this.outlinedForeground,
    required this.outlinedBorder,
    required this.outlinedDivider,
    required this.disabledBackground,
    required this.disabledForeground,
    required this.disabledBorder,
    required this.disabledDivider,
    required this.disabledActionBackground,
    required this.shadowColor,
  });

  factory SrrSplitActionButtonTheme.fromColorScheme(ColorScheme scheme) {
    return SrrSplitActionButtonTheme(
      borderRadius: 16,
      borderWidth: 1,
      actionSegmentWidth: 52,
      iconSize: 15,
      labelHorizontalPadding: 12,
      labelVerticalPadding: 8,
      dividerHeightInset: 18,
      shadowBlur: 14,
      shadowOffsetY: 5,
      filledShadowOpacity: 0.17,
      filledGradientHighlightOpacity: 0.08,
      filledGradientShadeOpacity: 0.06,
      filledActionShadeOpacity: 0.18,
      outlinedActionTintOpacity: 0.06,
      filledBackground: scheme.primary,
      filledForeground: scheme.onPrimary,
      filledBorder: scheme.onPrimary.withValues(alpha: 0.2),
      filledDivider: scheme.onPrimary.withValues(alpha: 0.45),
      outlinedBackground: scheme.surface,
      outlinedForeground: scheme.primary,
      outlinedBorder: scheme.primary.withValues(alpha: 0.65),
      outlinedDivider: scheme.primary.withValues(alpha: 0.35),
      disabledBackground: scheme.surfaceContainerHigh,
      disabledForeground: scheme.onSurfaceVariant,
      disabledBorder: scheme.outlineVariant,
      disabledDivider: scheme.outlineVariant,
      disabledActionBackground: scheme.surfaceContainer,
      shadowColor: Colors.black,
    );
  }

  final double borderRadius;
  final double borderWidth;
  final double actionSegmentWidth;
  final double iconSize;
  final double labelHorizontalPadding;
  final double labelVerticalPadding;
  final double dividerHeightInset;
  final double shadowBlur;
  final double shadowOffsetY;
  final double filledShadowOpacity;
  final double filledGradientHighlightOpacity;
  final double filledGradientShadeOpacity;
  final double filledActionShadeOpacity;
  final double outlinedActionTintOpacity;
  final Color filledBackground;
  final Color filledForeground;
  final Color filledBorder;
  final Color filledDivider;
  final Color outlinedBackground;
  final Color outlinedForeground;
  final Color outlinedBorder;
  final Color outlinedDivider;
  final Color disabledBackground;
  final Color disabledForeground;
  final Color disabledBorder;
  final Color disabledDivider;
  final Color disabledActionBackground;
  final Color shadowColor;

  @override
  SrrSplitActionButtonTheme copyWith({
    double? borderRadius,
    double? borderWidth,
    double? actionSegmentWidth,
    double? iconSize,
    double? labelHorizontalPadding,
    double? labelVerticalPadding,
    double? dividerHeightInset,
    double? shadowBlur,
    double? shadowOffsetY,
    double? filledShadowOpacity,
    double? filledGradientHighlightOpacity,
    double? filledGradientShadeOpacity,
    double? filledActionShadeOpacity,
    double? outlinedActionTintOpacity,
    Color? filledBackground,
    Color? filledForeground,
    Color? filledBorder,
    Color? filledDivider,
    Color? outlinedBackground,
    Color? outlinedForeground,
    Color? outlinedBorder,
    Color? outlinedDivider,
    Color? disabledBackground,
    Color? disabledForeground,
    Color? disabledBorder,
    Color? disabledDivider,
    Color? disabledActionBackground,
    Color? shadowColor,
  }) {
    return SrrSplitActionButtonTheme(
      borderRadius: borderRadius ?? this.borderRadius,
      borderWidth: borderWidth ?? this.borderWidth,
      actionSegmentWidth: actionSegmentWidth ?? this.actionSegmentWidth,
      iconSize: iconSize ?? this.iconSize,
      labelHorizontalPadding:
          labelHorizontalPadding ?? this.labelHorizontalPadding,
      labelVerticalPadding: labelVerticalPadding ?? this.labelVerticalPadding,
      dividerHeightInset: dividerHeightInset ?? this.dividerHeightInset,
      shadowBlur: shadowBlur ?? this.shadowBlur,
      shadowOffsetY: shadowOffsetY ?? this.shadowOffsetY,
      filledShadowOpacity: filledShadowOpacity ?? this.filledShadowOpacity,
      filledGradientHighlightOpacity:
          filledGradientHighlightOpacity ?? this.filledGradientHighlightOpacity,
      filledGradientShadeOpacity:
          filledGradientShadeOpacity ?? this.filledGradientShadeOpacity,
      filledActionShadeOpacity:
          filledActionShadeOpacity ?? this.filledActionShadeOpacity,
      outlinedActionTintOpacity:
          outlinedActionTintOpacity ?? this.outlinedActionTintOpacity,
      filledBackground: filledBackground ?? this.filledBackground,
      filledForeground: filledForeground ?? this.filledForeground,
      filledBorder: filledBorder ?? this.filledBorder,
      filledDivider: filledDivider ?? this.filledDivider,
      outlinedBackground: outlinedBackground ?? this.outlinedBackground,
      outlinedForeground: outlinedForeground ?? this.outlinedForeground,
      outlinedBorder: outlinedBorder ?? this.outlinedBorder,
      outlinedDivider: outlinedDivider ?? this.outlinedDivider,
      disabledBackground: disabledBackground ?? this.disabledBackground,
      disabledForeground: disabledForeground ?? this.disabledForeground,
      disabledBorder: disabledBorder ?? this.disabledBorder,
      disabledDivider: disabledDivider ?? this.disabledDivider,
      disabledActionBackground:
          disabledActionBackground ?? this.disabledActionBackground,
      shadowColor: shadowColor ?? this.shadowColor,
    );
  }

  @override
  SrrSplitActionButtonTheme lerp(
    covariant ThemeExtension<SrrSplitActionButtonTheme>? other,
    double t,
  ) {
    if (other is! SrrSplitActionButtonTheme) return this;
    return SrrSplitActionButtonTheme(
      borderRadius: lerpDouble(borderRadius, other.borderRadius, t)!,
      borderWidth: lerpDouble(borderWidth, other.borderWidth, t)!,
      actionSegmentWidth: lerpDouble(
        actionSegmentWidth,
        other.actionSegmentWidth,
        t,
      )!,
      iconSize: lerpDouble(iconSize, other.iconSize, t)!,
      labelHorizontalPadding: lerpDouble(
        labelHorizontalPadding,
        other.labelHorizontalPadding,
        t,
      )!,
      labelVerticalPadding: lerpDouble(
        labelVerticalPadding,
        other.labelVerticalPadding,
        t,
      )!,
      dividerHeightInset: lerpDouble(
        dividerHeightInset,
        other.dividerHeightInset,
        t,
      )!,
      shadowBlur: lerpDouble(shadowBlur, other.shadowBlur, t)!,
      shadowOffsetY: lerpDouble(shadowOffsetY, other.shadowOffsetY, t)!,
      filledShadowOpacity: lerpDouble(
        filledShadowOpacity,
        other.filledShadowOpacity,
        t,
      )!,
      filledGradientHighlightOpacity: lerpDouble(
        filledGradientHighlightOpacity,
        other.filledGradientHighlightOpacity,
        t,
      )!,
      filledGradientShadeOpacity: lerpDouble(
        filledGradientShadeOpacity,
        other.filledGradientShadeOpacity,
        t,
      )!,
      filledActionShadeOpacity: lerpDouble(
        filledActionShadeOpacity,
        other.filledActionShadeOpacity,
        t,
      )!,
      outlinedActionTintOpacity: lerpDouble(
        outlinedActionTintOpacity,
        other.outlinedActionTintOpacity,
        t,
      )!,
      filledBackground: Color.lerp(
        filledBackground,
        other.filledBackground,
        t,
      )!,
      filledForeground: Color.lerp(
        filledForeground,
        other.filledForeground,
        t,
      )!,
      filledBorder: Color.lerp(filledBorder, other.filledBorder, t)!,
      filledDivider: Color.lerp(filledDivider, other.filledDivider, t)!,
      outlinedBackground: Color.lerp(
        outlinedBackground,
        other.outlinedBackground,
        t,
      )!,
      outlinedForeground: Color.lerp(
        outlinedForeground,
        other.outlinedForeground,
        t,
      )!,
      outlinedBorder: Color.lerp(outlinedBorder, other.outlinedBorder, t)!,
      outlinedDivider: Color.lerp(outlinedDivider, other.outlinedDivider, t)!,
      disabledBackground: Color.lerp(
        disabledBackground,
        other.disabledBackground,
        t,
      )!,
      disabledForeground: Color.lerp(
        disabledForeground,
        other.disabledForeground,
        t,
      )!,
      disabledBorder: Color.lerp(disabledBorder, other.disabledBorder, t)!,
      disabledDivider: Color.lerp(disabledDivider, other.disabledDivider, t)!,
      disabledActionBackground: Color.lerp(
        disabledActionBackground,
        other.disabledActionBackground,
        t,
      )!,
      shadowColor: Color.lerp(shadowColor, other.shadowColor, t)!,
    );
  }
}
