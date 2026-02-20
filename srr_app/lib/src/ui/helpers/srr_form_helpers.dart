// ---------------------------------------------------------------------------
// srr_app/lib/src/ui/helpers/srr_form_helpers.dart
// ---------------------------------------------------------------------------
//
// Purpose:
// - Houses small reusable form helpers (inline error banners, string utilities) that are consumed by multiple UI pieces.
// Architecture:
// - Stateless widgets + extensions that keep form cards thin and focused.
// Author: Neil Khatu
// Copyright (c) The Khatu Family Trust
//
import 'package:characters/characters.dart';
import 'package:flutter/material.dart';

class SrrInlineError extends StatelessWidget {
  const SrrInlineError({required this.message, super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: TextStyle(color: theme.colorScheme.onErrorContainer),
      ),
    );
  }
}

extension SrrStringCapitalization on String {
  String capitalize() {
    if (isEmpty) return this;
    final first = characters.first.toUpperCase();
    return '$first${substring(1)}';
  }
}
