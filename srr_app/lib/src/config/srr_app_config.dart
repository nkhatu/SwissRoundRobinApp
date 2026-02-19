// ---------------------------------------------------------------------------
// srr_app/lib/src/config/srr_app_config.dart
// ---------------------------------------------------------------------------
// 
// Purpose:
// - Defines app-level constants such as branding, support email, and copyright text.
// Architecture:
// - Configuration module centralizing immutable app metadata values.
// - Reduces duplication by exposing shared constants to UI and framework layers.
// Author: Neil Khatu
// Copyright (c) The Khatu Family Trust
// 
class SrrAppConfig {
  const SrrAppConfig._();

  static const appName = 'Carrom';
  static const appVersion = '1.0.0';
  static const appBuild = '1';
  static const supportEmail = 'support@example.com';
  static const copyrightNotice =
      'Copyright @ (2017 : 2026) The Khatu Family Trust';
}
