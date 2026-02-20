// ---------------------------------------------------------------------------
// srr_app/lib/src/auth/auth_exceptions.dart
// ---------------------------------------------------------------------------
//
// Purpose:
// - Shared authentication-specific exception types.
// Architecture:
// - Keeps provider cancellation errors centralized for reuse.
// Author: The Khatu Family Trust
// Copyright (c) The Khatu Family Trust
//
class SocialAuthCanceledException implements Exception {
  const SocialAuthCanceledException(this.provider);

  final String provider;

  @override
  String toString() => '$provider sign-in canceled by user.';
}
