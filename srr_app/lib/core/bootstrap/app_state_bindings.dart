// ---------------------------------------------------------------------------
// srr_app/lib/core/bootstrap/app_state_bindings.dart
// ---------------------------------------------------------------------------
//
// Purpose:
// - Binds runtime controllers/services after startup and before the widget tree.
// Architecture:
// - Keeps startup side effects (theme syncing, preference hydration) out of widgets.
// Author: The Khatu Family Trust
// Copyright (c) The Khatu Family Trust
//
import '../../src/di/srr_dependencies.dart';

class AppStateBindings {
  AppStateBindings({required this.dependencies});

  final SrrDependencies dependencies;
  bool _bound = false;

  void bind() {
    if (_bound) return;
    _bound = true;
    dependencies.userPreferencesCoordinator.start();
  }

  void dispose() {
    if (!_bound) return;
    _bound = false;
    dependencies.userPreferencesCoordinator.dispose();
  }
}
