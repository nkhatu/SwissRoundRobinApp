// ---------------------------------------------------------------------------
// srr_app/lib/src/config/srr_runtime_env.dart
// ---------------------------------------------------------------------------
//
// Purpose:
// - Defines runtime environment values used for API and Firebase initialization.
// Architecture:
// - Configuration layer exposing typed runtime settings from --dart-define.
// - Keeps startup environment parsing out of the app entrypoint and UI code.
// Author: Neil Khatu
// Copyright (c) The Khatu Family Trust
//
class SrrRuntimeEnv {
  const SrrRuntimeEnv._();

  static const apiBaseUrl = String.fromEnvironment(
    'SRR_API_URL',
    defaultValue: 'https://example.com/api',
  );

  static const _firebaseWebApiKey = String.fromEnvironment(
    'FIREBASE_WEB_API_KEY',
  );
  static const _firebaseWebAppId = String.fromEnvironment(
    'FIREBASE_WEB_APP_ID',
  );
  static const _firebaseWebMessagingSenderId = String.fromEnvironment(
    'FIREBASE_WEB_MESSAGING_SENDER_ID',
  );
  static const _firebaseWebProjectId = String.fromEnvironment(
    'FIREBASE_WEB_PROJECT_ID',
  );
  static const _firebaseWebAuthDomain = String.fromEnvironment(
    'FIREBASE_WEB_AUTH_DOMAIN',
  );
  static const _firebaseWebStorageBucket = String.fromEnvironment(
    'FIREBASE_WEB_STORAGE_BUCKET',
  );
  static const _firebaseWebMeasurementId = String.fromEnvironment(
    'FIREBASE_WEB_MEASUREMENT_ID',
  );

  static SrrFirebaseWebRuntimeConfig get firebaseWeb =>
      SrrFirebaseWebRuntimeConfig(
        apiKey: _firebaseWebApiKey,
        appId: _firebaseWebAppId,
        messagingSenderId: _firebaseWebMessagingSenderId,
        projectId: _firebaseWebProjectId,
        authDomain: _firebaseWebAuthDomain.isNotEmpty
            ? _firebaseWebAuthDomain
            : '$_firebaseWebProjectId.firebaseapp.com',
        storageBucket: _firebaseWebStorageBucket,
        measurementId: _firebaseWebMeasurementId,
      );
}

class SrrFirebaseWebRuntimeConfig {
  const SrrFirebaseWebRuntimeConfig({
    required this.apiKey,
    required this.appId,
    required this.messagingSenderId,
    required this.projectId,
    required this.authDomain,
    required this.storageBucket,
    required this.measurementId,
  });

  final String apiKey;
  final String appId;
  final String messagingSenderId;
  final String projectId;
  final String authDomain;
  final String storageBucket;
  final String measurementId;

  bool get isConfigured =>
      apiKey.isNotEmpty &&
      appId.isNotEmpty &&
      messagingSenderId.isNotEmpty &&
      projectId.isNotEmpty;
}
