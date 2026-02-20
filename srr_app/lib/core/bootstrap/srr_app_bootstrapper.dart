// ---------------------------------------------------------------------------
// srr_app/lib/core/bootstrap/srr_app_bootstrapper.dart
// ---------------------------------------------------------------------------
//
// Purpose:
// - Orchestrates startup initialization and dependency graph construction.
// Architecture:
// - Bootstrap coordinator that composes Firebase initialization and DI bootstrap.
// - Keeps startup flow deterministic while keeping main.dart lean.
// Author: Neil Khatu
// Copyright (c) The Khatu Family Trust
//
import '../../src/config/srr_runtime_env.dart';
import '../../src/di/srr_dependencies.dart';
import 'srr_firebase_initializer.dart';

class SrrAppBootstrapper {
  const SrrAppBootstrapper({SrrFirebaseInitializer? firebaseInitializer})
    : _firebaseInitializer =
          firebaseInitializer ?? const SrrFirebaseInitializer();

  final SrrFirebaseInitializer _firebaseInitializer;

  Future<SrrDependencies> bootstrap() async {
    await _firebaseInitializer.initialize();
    return SrrDependencies.bootstrap(apiBaseUrl: SrrRuntimeEnv.apiBaseUrl);
  }

  Future<void> recordFatal(Object error, StackTrace stack) =>
      Future<void>.value();

  void recordUnhandled(Object error, StackTrace stack) {}
}
