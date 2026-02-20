// ---------------------------------------------------------------------------
// srr_app/lib/core/bootstrap/srr_firebase_initializer.dart
// ---------------------------------------------------------------------------
//
// Purpose:
// - Initializes Firebase for mobile and web runtimes before app startup.
// Architecture:
// - Infrastructure bootstrap service that isolates Firebase startup concerns.
// - Consumes runtime config values and produces a single initialization boundary.
// Author: Neil Khatu
// Copyright (c) The Khatu Family Trust
//
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../../src/config/srr_runtime_env.dart';

class SrrFirebaseInitializer {
  const SrrFirebaseInitializer();

  Future<void> initialize() async {
    if (!kIsWeb) {
      await Firebase.initializeApp();
      return;
    }

    final config = SrrRuntimeEnv.firebaseWeb;
    if (!config.isConfigured) {
      throw StateError(
        'Missing Firebase web config. Provide FIREBASE_WEB_API_KEY, '
        'FIREBASE_WEB_APP_ID, FIREBASE_WEB_MESSAGING_SENDER_ID, and '
        'FIREBASE_WEB_PROJECT_ID.',
      );
    }

    await Firebase.initializeApp(
      options: FirebaseOptions(
        apiKey: config.apiKey,
        appId: config.appId,
        messagingSenderId: config.messagingSenderId,
        projectId: config.projectId,
        authDomain: config.authDomain,
        storageBucket: config.storageBucket.isEmpty
            ? null
            : config.storageBucket,
        measurementId: config.measurementId.isEmpty
            ? null
            : config.measurementId,
      ),
    );
  }
}
