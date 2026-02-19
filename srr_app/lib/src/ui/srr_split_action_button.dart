// ---------------------------------------------------------------------------
// srr_app/lib/src/ui/srr_split_action_button.dart
// ---------------------------------------------------------------------------
// 
// Purpose:
// - Implements the split-action themed button variant used across SRR pages.
// Architecture:
// - Reusable UI control encapsulating button visuals, icon layout, and interaction behavior.
// - Separates design-system button behavior from page-level business logic.
// Author: Neil Khatu
// Copyright (c) The Khatu Family Trust
// 
import 'package:flutter/material.dart';

import '../theme/srr_split_action_button_theme.dart';

enum SrrSplitActionButtonVariant { filled, outlined }

class SrrSplitActionButton extends StatelessWidget {
  const SrrSplitActionButton({
    super.key,
    required this.label,
    this.onPressed,
    this.variant = SrrSplitActionButtonVariant.filled,
    this.leadingIcon,
    this.trailingIcon = Icons.arrow_forward_ios_rounded,
    this.height = 52,
    this.maxLines = 1,
    this.labelTextAlign = TextAlign.center,
  });

  final String label;
  final VoidCallback? onPressed;
  final SrrSplitActionButtonVariant variant;
  final IconData? leadingIcon;
  final IconData trailingIcon;
  final double height;
  final int maxLines;
  final TextAlign labelTextAlign;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final injected =
        theme.extension<SrrSplitActionButtonTheme>() ??
        SrrSplitActionButtonTheme.fromColorScheme(scheme);
    final enabled = onPressed != null;
    final isFilled = variant == SrrSplitActionButtonVariant.filled;

    final backgroundColor = !enabled
        ? injected.disabledBackground
        : isFilled
        ? injected.filledBackground
        : injected.outlinedBackground;
    final foregroundColor = !enabled
        ? injected.disabledForeground
        : isFilled
        ? injected.filledForeground
        : injected.outlinedForeground;
    final borderColor = !enabled
        ? injected.disabledBorder
        : isFilled
        ? injected.filledBorder
        : injected.outlinedBorder;
    final dividerColor = !enabled
        ? injected.disabledDivider
        : isFilled
        ? injected.filledDivider
        : injected.outlinedDivider;
    final actionSegmentColor = !enabled
        ? injected.disabledActionBackground
        : isFilled
        ? Color.alphaBlend(
            Colors.black.withValues(alpha: injected.filledActionShadeOpacity),
            backgroundColor,
          )
        : Color.alphaBlend(
            injected.outlinedForeground.withValues(
              alpha: injected.outlinedActionTintOpacity,
            ),
            injected.outlinedBackground,
          );

    return SizedBox(
      height: height,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(injected.borderRadius),
          boxShadow: enabled && isFilled
              ? [
                  BoxShadow(
                    color: injected.shadowColor.withValues(
                      alpha: injected.filledShadowOpacity,
                    ),
                    blurRadius: injected.shadowBlur,
                    offset: Offset(0, injected.shadowOffsetY),
                  ),
                ]
              : const <BoxShadow>[],
        ),
        child: Material(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(injected.borderRadius),
          clipBehavior: Clip.antiAlias,
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(injected.borderRadius),
              border: Border.all(
                color: borderColor,
                width: injected.borderWidth,
              ),
              gradient: enabled && isFilled
                  ? LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color.alphaBlend(
                          Colors.white.withValues(
                            alpha: injected.filledGradientHighlightOpacity,
                          ),
                          backgroundColor,
                        ),
                        Color.alphaBlend(
                          Colors.black.withValues(
                            alpha: injected.filledGradientShadeOpacity,
                          ),
                          backgroundColor,
                        ),
                      ],
                    )
                  : null,
            ),
            child: InkWell(
              onTap: onPressed,
              child: Row(
                children: [
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: injected.labelHorizontalPadding,
                        vertical: injected.labelVerticalPadding,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (leadingIcon != null) ...[
                            Icon(leadingIcon, size: 18, color: foregroundColor),
                            const SizedBox(width: 7),
                          ],
                          Flexible(
                            child: Text(
                              label,
                              textAlign: labelTextAlign,
                              maxLines: maxLines,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.labelLarge?.copyWith(
                                color: foregroundColor,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.15,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Container(
                    width: injected.borderWidth,
                    height: height - injected.dividerHeightInset,
                    color: dividerColor,
                  ),
                  Container(
                    width: injected.actionSegmentWidth,
                    height: double.infinity,
                    color: actionSegmentColor,
                    child: Icon(
                      trailingIcon,
                      color: foregroundColor,
                      size: injected.iconSize,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
