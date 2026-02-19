// ---------------------------------------------------------------------------
// srr_app/lib/src/auth/srr_auth_service.dart
// ---------------------------------------------------------------------------
// 
// Purpose:
// - Wraps Firebase authentication operations for email, Google, and Apple sign-in.
// Architecture:
// - Auth service layer encapsulating provider-specific identity flows.
// - Keeps authentication side effects out of presentation and routing modules.
// Author: Neil Khatu
// Copyright (c) The Khatu Family Trust
// 
import 'dart:convert';
import 'dart:math';

import 'package:catu_framework/catu_framework.dart';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../api/srr_api_client.dart';
import '../models/srr_models.dart';

class SrrAuthService implements AuthService {
  SrrAuthService(this._apiClient);

  static const _googleIosClientId = String.fromEnvironment(
    'GOOGLE_IOS_CLIENT_ID',
    defaultValue: '',
  );
  static const _googleWebClientId = String.fromEnvironment(
    'GOOGLE_WEB_CLIENT_ID',
    defaultValue: '',
  );

  static const _appleClientId = String.fromEnvironment(
    'APPLE_CLIENT_ID',
    defaultValue: '',
  );
  static const _appleServiceId = String.fromEnvironment(
    'APPLE_SERVICE_ID',
    defaultValue: 'com.example.carrom',
  );
  static const _appleAndroidRedirectUri = String.fromEnvironment(
    'APPLE_REDIRECT_URI',
    defaultValue: 'https://example.com/api/callbacks/sign_in_with_apple',
  );

  final SrrApiClient _apiClient;
  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;

  Future<void>? _googleInitFuture;
  bool _googleInitialized = false;

  SrrUser? get currentAccount => _apiClient.currentUserSnapshot;

  static String _generateNonce([int length = 32]) {
    const charset =
        '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List.generate(length, (_) => charset[random.nextInt(charset.length)])
        .join();
  }

  static String _sha256ofString(String input) {
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  @override
  Future<AuthUser?> currentUser() async {
    final user = await _apiClient.currentUser();
    if (user == null) return null;
    return _toAuthUser(user);
  }

  @override
  Future<AuthUser> signIn({
    required String email,
    required String password,
  }) async {
    final authEmail = _normalizedEmail(email);
    await FirebaseAuth.instance.signInWithEmailAndPassword(
      email: authEmail,
      password: password,
    );

    final user = await _apiClient.bootstrapFirebaseAuthUser(
      handleHint: _handleHintFromEmail(authEmail),
    );
    return _toAuthUser(user);
  }

  @override
  Future<AuthUser> register({
    required String email,
    required String password,
    required String displayName,
  }) async {
    final authEmail = _normalizedEmail(email);
    final credential = await FirebaseAuth.instance
        .createUserWithEmailAndPassword(email: authEmail, password: password);

    await credential.user?.updateDisplayName(displayName.trim());
    await credential.user?.reload();

    final user = await _apiClient.bootstrapFirebaseAuthUser(
      displayName: displayName,
      handleHint: _handleHintFromEmail(authEmail),
      role: 'player',
    );
    return _toAuthUser(user);
  }

  @override
  Future<void> signOut() async {
    await _apiClient.logout();
    await FirebaseAuth.instance.signOut();
    try {
      await _googleSignIn.signOut();
      await _googleSignIn.disconnect();
    } catch (_) {
      // No local Google session to clear.
    }
  }

  @override
  Future<AuthUser> signInWithGoogle() async {
    UserCredential credential;

    if (kIsWeb) {
      final provider = GoogleAuthProvider();
      provider.setCustomParameters({'prompt': 'select_account'});
      try {
        credential = await FirebaseAuth.instance.signInWithPopup(provider);
      } on FirebaseAuthException catch (error) {
        if (error.code == 'popup-closed-by-user' ||
            error.code == 'cancelled-popup-request') {
          throw const _SocialAuthCanceledException('Google');
        }
        rethrow;
      }
    } else {
      await _ensureGoogleInitialized();
      late final GoogleSignInAccount account;
      try {
        account = await _googleSignIn.authenticate();
      } on GoogleSignInException catch (error) {
        if (error.code == GoogleSignInExceptionCode.canceled ||
            error.code == GoogleSignInExceptionCode.interrupted) {
          throw const _SocialAuthCanceledException('Google');
        }
        throw Exception(
          'Google sign-in failed (${error.code.name}): ${error.description ?? 'Unknown error'}.',
        );
      }

      final auth = account.authentication;
      final idToken = auth.idToken?.trim();
      if (idToken == null || idToken.isEmpty) {
        throw Exception('Google did not return credentials for sign-in.');
      }
      final authCredential = GoogleAuthProvider.credential(
        idToken: idToken,
      );
      credential = await FirebaseAuth.instance.signInWithCredential(
        authCredential,
      );
    }

    final user = await _apiClient.bootstrapFirebaseAuthUser(
      displayName: credential.user?.displayName,
      handleHint: _handleHintFromEmail(credential.user?.email),
      role: 'player',
    );
    return _toAuthUser(user);
  }

  @override
  Future<AuthUser> signInWithApple() async {
    if (!kIsWeb && !(await SignInWithApple.isAvailable())) {
      throw Exception('Sign in with Apple is not available on this device.');
    }

    UserCredential credential;
    if (kIsWeb) {
      final provider = AppleAuthProvider()
        ..addScope('email')
        ..addScope('name');
      try {
        credential = await FirebaseAuth.instance.signInWithPopup(provider);
      } on FirebaseAuthException catch (error) {
        if (error.code == 'popup-closed-by-user' ||
            error.code == 'cancelled-popup-request') {
          throw const _SocialAuthCanceledException('Apple');
        }
        rethrow;
      }
    } else {
      if (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.macOS) {
        final provider = AppleAuthProvider()
          ..addScope('email')
          ..addScope('name');
        try {
          credential = await FirebaseAuth.instance.signInWithProvider(provider);
        } on FirebaseAuthException catch (error) {
          if (error.code == 'canceled' ||
              error.code == 'web-context-cancelled') {
            throw const _SocialAuthCanceledException('Apple');
          }
          rethrow;
        }
      } else {
        final needsWebOptions = defaultTargetPlatform == TargetPlatform.android;
        final appleClientId = _effectiveAppleClientId;
        if (needsWebOptions && appleClientId.isEmpty) {
          throw Exception(
            'Apple sign-in needs APPLE_CLIENT_ID (or APPLE_SERVICE_ID) for Android.',
          );
        }

        final rawNonce = _generateNonce();
        final nonce = _sha256ofString(rawNonce);

        late final AuthorizationCredentialAppleID appleCredential;
        try {
          appleCredential = await SignInWithApple.getAppleIDCredential(
            scopes: const [
              AppleIDAuthorizationScopes.email,
              AppleIDAuthorizationScopes.fullName,
            ],
            nonce: nonce,
            webAuthenticationOptions: needsWebOptions
                ? WebAuthenticationOptions(
                    clientId: appleClientId,
                    redirectUri: Uri.parse(_appleAndroidRedirectUri),
                  )
                : null,
          );
        } on SignInWithAppleAuthorizationException catch (error) {
          if (error.code == AuthorizationErrorCode.canceled) {
            throw const _SocialAuthCanceledException('Apple');
          }
          rethrow;
        }

        final idToken = appleCredential.identityToken?.trim() ?? '';
        if (idToken.isEmpty) {
          throw Exception(
            'Apple sign-in did not return a valid identity token.',
          );
        }

        final oauthCredential = OAuthProvider(
          'apple.com',
        ).credential(idToken: idToken, rawNonce: rawNonce);
        credential = await FirebaseAuth.instance.signInWithCredential(
          oauthCredential,
        );
      }
    }

    final user = await _apiClient.bootstrapFirebaseAuthUser(
      displayName: credential.user?.displayName,
      handleHint: _handleHintFromEmail(credential.user?.email),
      role: 'player',
    );
    return _toAuthUser(user);
  }

  AuthUser _toAuthUser(SrrUser user) {
    return AuthUser(
      id: user.id.toString(),
      email: user.email,
      displayName: user.displayName,
      isAdmin: user.role == 'admin',
    );
  }

  Future<void> _ensureGoogleInitialized() async {
    if (_googleInitialized) return;
    _googleInitFuture ??= _googleSignIn.initialize(
      clientId: _effectiveGoogleClientId,
    );
    await _googleInitFuture;
    _googleInitialized = true;
  }

  String? get _effectiveGoogleClientId {
    if (kIsWeb && _googleWebClientId.isNotEmpty) {
      return _googleWebClientId;
    }
    if (!kIsWeb &&
        defaultTargetPlatform == TargetPlatform.iOS &&
        _googleIosClientId.isNotEmpty) {
      return _googleIosClientId;
    }
    return null;
  }

  String get _effectiveAppleClientId {
    if (_appleClientId.trim().isNotEmpty) return _appleClientId.trim();
    if (_appleServiceId.trim().isNotEmpty) return _appleServiceId.trim();
    return '';
  }

  String _normalizedEmail(String input) {
    final email = input.trim().toLowerCase();
    final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    if (!emailRegex.hasMatch(email)) {
      throw Exception('Enter a valid email address.');
    }
    return email;
  }

  String? _handleHintFromEmail(String? email) {
    final raw = (email ?? '').trim().toLowerCase();
    if (raw.isEmpty || !raw.contains('@')) return null;
    final first = raw.split('@').first.trim();
    if (first.length < 3) return null;
    return first;
  }
}

class _SocialAuthCanceledException implements Exception {
  const _SocialAuthCanceledException(this.provider);

  final String provider;

  @override
  String toString() => '$provider sign-in canceled by user.';
}
