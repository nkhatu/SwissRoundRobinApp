// ---------------------------------------------------------------------------
// srr_app/lib/src/theme/srr_user_preferences_coordinator.dart
// ---------------------------------------------------------------------------
//
// Purpose:
// - Synchronizes theme and display-preference controllers with active app user.
// Architecture:
// - Application coordination service that listens to app-state user changes.
// - Routes user-context side effects into dedicated preference controllers.
// Author: Neil Khatu
// Copyright (c) The Khatu Family Trust
//
import 'dart:async';

import 'package:catu_framework/catu_framework.dart';

import 'srr_display_preferences_controller.dart';
import 'srr_theme_controller.dart';

class SrrUserPreferencesCoordinator {
  SrrUserPreferencesCoordinator({
    required AppState appState,
    required SrrThemeController themeController,
    required SrrDisplayPreferencesController displayPreferencesController,
  }) : _appState = appState,
       _themeController = themeController,
       _displayPreferencesController = displayPreferencesController;

  final AppState _appState;
  final SrrThemeController _themeController;
  final SrrDisplayPreferencesController _displayPreferencesController;

  bool _started = false;
  String? _lastUserId;

  void start() {
    if (_started) return;
    _started = true;
    _appState.addListener(_sync);
    _sync();
  }

  void dispose() {
    if (!_started) return;
    _appState.removeListener(_sync);
    _started = false;
  }

  void _sync() {
    final userId = _appState.user?.id;
    if (_lastUserId == userId) return;
    _lastUserId = userId;
    unawaited(_themeController.load(userId: userId));
    unawaited(_displayPreferencesController.load(userId: userId));
  }
}
