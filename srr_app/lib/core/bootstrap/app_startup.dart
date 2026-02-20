// ---------------------------------------------------------------------------
// srr_app/lib/core/bootstrap/app_startup.dart
// ---------------------------------------------------------------------------
//
// Purpose:
// - Handles centralized startup orchestration, logging, and error capture.
// Architecture:
// - Mirrors the Khatu Art Gallery AppStartup pattern for predictable wiring.
// - Delegates to SrrAppBootstrapper while adding runtime log capturing and guards.
// Author: The Khatu Family Trust
// Copyright (c) The Khatu Family Trust
//
import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/widgets.dart';

import 'package:catu_framework/catu_framework.dart';

import '../logging/runtime_log_store.dart';
import 'srr_app_bootstrapper.dart';
import '../../src/di/srr_dependencies.dart';

class AppStartupResult {
  const AppStartupResult({required this.dependencies});

  final SrrDependencies dependencies;
}

class AppStartup {
  AppStartup({SrrAppBootstrapper? bootstrapper})
    : _bootstrapper = bootstrapper ?? const SrrAppBootstrapper();

  final SrrAppBootstrapper _bootstrapper;
  bool _runtimeLogCaptureInstalled = false;

  Future<AppStartupResult> initialize() async {
    WidgetsFlutterBinding.ensureInitialized();
    _installRuntimeLogCapture();

    final dependencies = await _bootstrapper.bootstrap();
    _installGlobalErrorHandlers(dependencies);
    _captureFlutterErrors();

    return AppStartupResult(dependencies: dependencies);
  }

  Future<void> recordFatalStartupError(Object error, StackTrace stack) async {
    RuntimeLogStore.instance.add(
      'Startup failed: $error',
      level: RuntimeLogLevel.error,
    );
    developer.log(
      'Startup fatal: $error',
      error: error,
      stackTrace: stack,
      level: 1000,
    );
    await _bootstrapper.recordFatal(error, stack);
  }

  void recordUnhandledZoneError(Object error, StackTrace stack) {
    RuntimeLogStore.instance.add(
      'Unhandled zone error: $error',
      level: RuntimeLogLevel.error,
    );
    developer.log(
      'Unhandled zone error',
      error: error,
      stackTrace: stack,
      level: 1000,
    );
    _bootstrapper.recordUnhandled(error, stack);
  }

  void _installRuntimeLogCapture() {
    if (_runtimeLogCaptureInstalled) return;
    _runtimeLogCaptureInstalled = true;

    final originalDebugPrint = debugPrint;
    debugPrint = (String? message, {int? wrapWidth}) {
      if (message != null) {
        RuntimeLogStore.instance.add(message, level: RuntimeLogLevel.info);
      }
      originalDebugPrint(message, wrapWidth: wrapWidth);
    };
  }

  void _captureFlutterErrors() {
    FlutterError.onError = (details) {
      RuntimeLogStore.instance.add(
        details.exceptionAsString(),
        level: RuntimeLogLevel.error,
      );
      FlutterError.presentError(details);
    };
  }

  void _installGlobalErrorHandlers(SrrDependencies dependencies) {
    // Keep analytics handlers available for later use.
    installCrashAnalyticsHandlers(dependencies.framework.analytics);
  }
}
