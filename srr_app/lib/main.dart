// ---------------------------------------------------------------------------
// srr_app/lib/main.dart
// ---------------------------------------------------------------------------
//
// Purpose:
// - Mirrors the Khatu-style startup flow for consistent architecture.
// Architecture:
// - Entrypoint that runs `AppStartup`, binds shared state, and monitors sessions.
// Author: Neil Khatu
// Copyright (c) The Khatu Family Trust
//
import 'dart:async';

import 'package:flutter/widgets.dart';

import 'core/bootstrap/app_state_bindings.dart';
import 'core/bootstrap/app_startup.dart';
import 'core/security/session_watcher.dart';
import 'src/ui/app_bootstrap.dart';

Future<void> main() async {
  final startup = AppStartup();
  await runZonedGuarded(
    () async {
      final result = await startup.initialize();
      final bindings = AppStateBindings(dependencies: result.dependencies);
      bindings.bind();

      runApp(
        SessionWatcher(
          appState: result.dependencies.appState,
          child: AppBootstrap(dependencies: result.dependencies),
        ),
      );
    },
    (error, stack) {
      startup.recordUnhandledZoneError(error, stack);
    },
  );
}
