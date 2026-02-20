// ---------------------------------------------------------------------------
// srr_app/lib/src/auth/google_auth_helper.dart
// ---------------------------------------------------------------------------
//
// Purpose:
// - Handles Google sign-in flows for web and native targets.
// Architecture:
// - Encapsulates GoogleSignIn and provider setup to keep SrrAuthService lightweight.
// Author: The Khatu Family Trust
// Copyright (c) The Khatu Family Trust
//
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

class GoogleAuthHelper {
  GoogleAuthHelper({
    FirebaseAuth? firebaseAuth,
    GoogleSignIn? googleSignIn,
    String? googleIosClientId,
    String? googleWebClientId,
  }) : _auth = firebaseAuth ?? FirebaseAuth.instance,
       _googleSignIn = googleSignIn ?? GoogleSignIn.instance,
       _googleIosClientId = googleIosClientId ?? '',
       _googleWebClientId = googleWebClientId ?? '';

  final FirebaseAuth _auth;
  final GoogleSignIn _googleSignIn;
  final String _googleIosClientId;
  final String _googleWebClientId;
  Future<void>? _googleInitFuture;
  bool _googleInitialized = false;

  Future<UserCredential> signIn() async {
    if (kIsWeb) {
      return _signInWithWebPopup();
    }
    return _signInNative();
  }

  Future<UserCredential> _signInWithWebPopup() async {
    final provider = GoogleAuthProvider();
    provider.setCustomParameters({'prompt': 'select_account'});
    return _auth.signInWithPopup(provider);
  }

  Future<UserCredential> _signInNative() async {
    await _ensureGoogleInitialized();
    final account = await _googleSignIn.authenticate();
    final auth = account.authentication;
    final idToken = auth.idToken?.trim();
    if (idToken == null || idToken.isEmpty) {
      throw Exception('Google did not return credentials for sign-in.');
    }
    final credential = GoogleAuthProvider.credential(idToken: idToken);
    return _auth.signInWithCredential(credential);
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
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
      if (_googleIosClientId.isNotEmpty) return _googleIosClientId;
    }
    return null;
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _googleSignIn.disconnect();
  }
}
