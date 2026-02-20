// ---------------------------------------------------------------------------
// srr_app/lib/src/auth/email_auth_helper.dart
// ---------------------------------------------------------------------------
//
// Purpose:
// - Encapsulates email/password Firebase operations.
// Architecture:
// - Keeps normalization and sign-in/register logic isolated from SrrAuthService.
// Author: The Khatu Family Trust
// Copyright (c) The Khatu Family Trust
//
import 'package:firebase_auth/firebase_auth.dart';

import 'auth_util.dart';

class EmailAuthHelper {
  EmailAuthHelper({FirebaseAuth? firebaseAuth})
    : _auth = firebaseAuth ?? FirebaseAuth.instance;

  final FirebaseAuth _auth;

  Future<UserCredential> signIn({
    required String email,
    required String password,
  }) async {
    final normalized = normalizedEmail(email);
    return _auth.signInWithEmailAndPassword(
      email: normalized,
      password: password,
    );
  }

  Future<UserCredential> register({
    required String email,
    required String password,
    required String displayName,
  }) async {
    final normalized = normalizedEmail(email);
    final credential = await _auth.createUserWithEmailAndPassword(
      email: normalized,
      password: password,
    );
    await credential.user?.updateDisplayName(displayName.trim());
    await credential.user?.reload();
    return credential;
  }

  Future<void> signOut() => _auth.signOut();
}
