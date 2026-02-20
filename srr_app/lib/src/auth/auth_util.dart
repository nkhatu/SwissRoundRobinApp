// ---------------------------------------------------------------------------
// srr_app/lib/src/auth/auth_util.dart
// ---------------------------------------------------------------------------
//
// Purpose:
// - Provides shared helpers used across authentication flows.
// Architecture:
// - Utility functions that deal with email normalization and handle hints.
// Author: The Khatu Family Trust
// Copyright (c) The Khatu Family Trust
//
String normalizedEmail(String input) {
  final email = input.trim().toLowerCase();
  final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
  if (!emailRegex.hasMatch(email)) {
    throw Exception('Enter a valid email address.');
  }
  return email;
}

String? handleHintFromEmail(String? email) {
  final raw = (email ?? '').trim().toLowerCase();
  if (raw.isEmpty || !raw.contains('@')) return null;
  final first = raw.split('@').first.trim();
  if (first.length < 3) return null;
  return first;
}
