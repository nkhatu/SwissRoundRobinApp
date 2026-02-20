// ---------------------------------------------------------------------------
// srr_app/lib/src/auth/apple_auth_helper.dart
// ---------------------------------------------------------------------------
//
// Purpose:
// - Handles Apple sign-in for web, iOS, macOS, and Android with web fallback.
// Architecture:
// - Centralizes nonce generation plus platform branching logic.
// Author: The Khatu Family Trust
// Copyright (c) The Khatu Family Trust
//
import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

class AppleAuthHelper {
  AppleAuthHelper({
    FirebaseAuth? firebaseAuth,
    String? appleClientId,
    String? appleServiceId,
    String? androidRedirectUri,
  }) : _auth = firebaseAuth ?? FirebaseAuth.instance,
       _appleClientId = appleClientId ?? '',
       _appleServiceId = appleServiceId ?? 'com.example.carrom',
       _androidRedirectUri =
           androidRedirectUri ??
           'https://example.com/api/callbacks/sign_in_with_apple';

  final FirebaseAuth _auth;
  final String _appleClientId;
  final String _appleServiceId;
  final String _androidRedirectUri;

  Future<UserCredential> signIn() async {
    if (kIsWeb) {
      return _signInWeb();
    }
    if (defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS) {
      return _signInNativeAppleProvider();
    }
    return _signInAndroid();
  }

  Future<UserCredential> _signInWeb() async {
    final provider = AppleAuthProvider()
      ..addScope('email')
      ..addScope('name');
    return _auth.signInWithPopup(provider);
  }

  Future<UserCredential> _signInNativeAppleProvider() async {
    final provider = AppleAuthProvider()
      ..addScope('email')
      ..addScope('name');
    return _auth.signInWithProvider(provider);
  }

  Future<UserCredential> _signInAndroid() async {
    final needsWebOptions =
        defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.windows;
    final appleClientId = _effectiveAppleClientId;
    if (needsWebOptions && appleClientId.isEmpty) {
      throw Exception(
        'Apple sign-in needs APPLE_CLIENT_ID (or APPLE_SERVICE_ID) for Android.',
      );
    }

    final rawNonce = _generateNonce();
    final nonce = _sha256(rawNonce);

    final appleCredential = await SignInWithApple.getAppleIDCredential(
      scopes: const [
        AppleIDAuthorizationScopes.email,
        AppleIDAuthorizationScopes.fullName,
      ],
      nonce: nonce,
      webAuthenticationOptions: needsWebOptions
          ? WebAuthenticationOptions(
              clientId: appleClientId,
              redirectUri: Uri.parse(_androidRedirectUri),
            )
          : null,
    );

    final idToken = appleCredential.identityToken?.trim() ?? '';
    if (idToken.isEmpty) {
      throw Exception('Apple sign-in did not return a valid identity token.');
    }

    final credential = OAuthProvider(
      'apple.com',
    ).credential(idToken: idToken, rawNonce: rawNonce);
    return _auth.signInWithCredential(credential);
  }

  String get _effectiveAppleClientId {
    if (_appleClientId.trim().isNotEmpty) return _appleClientId.trim();
    if (_appleServiceId.trim().isNotEmpty) return _appleServiceId.trim();
    return '';
  }

  String _generateNonce([int length = 32]) {
    const charset =
        '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List.generate(
      length,
      (_) => charset[random.nextInt(charset.length)],
    ).join();
  }

  String _sha256(String input) {
    final bytes = utf8.encode(input);
    return sha256.convert(bytes).toString();
  }
}
