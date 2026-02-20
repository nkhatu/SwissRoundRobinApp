// ---------------------------------------------------------------------------
// srr_app/lib/src/auth/srr_auth_service.dart
// ---------------------------------------------------------------------------
//
// Purpose:
// - Orchestrates all supported authentication flows (email, Google, Apple).
// Architecture:
// - Delegates provider-specific logic to helper classes.
// - Handles shared bootstrap and transformation responsibilities.
// Author: Neil Khatu
// Copyright (c) The Khatu Family Trust
//
import 'package:catu_framework/catu_framework.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../models/srr_models.dart';
import '../repositories/srr_auth_repository.dart';
import 'apple_auth_helper.dart';
import 'auth_exceptions.dart';
import 'auth_util.dart';
import 'email_auth_helper.dart';
import 'google_auth_helper.dart';

class SrrAuthService implements AuthService {
  SrrAuthService(
    this._authRepository, {
    EmailAuthHelper? emailAuthHelper,
    GoogleAuthHelper? googleAuthHelper,
    AppleAuthHelper? appleAuthHelper,
  }) : _emailHelper = emailAuthHelper ?? EmailAuthHelper(),
       _googleHelper =
           googleAuthHelper ??
           GoogleAuthHelper(
             googleIosClientId: _googleIosClientId,
             googleWebClientId: _googleWebClientId,
           ),
       _appleHelper =
           appleAuthHelper ??
           AppleAuthHelper(
             appleClientId: _appleClientId,
             appleServiceId: _appleServiceId,
             androidRedirectUri: _appleAndroidRedirectUri,
           );

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

  final EmailAuthHelper _emailHelper;
  final GoogleAuthHelper _googleHelper;
  final AppleAuthHelper _appleHelper;
  final SrrAuthRepository _authRepository;

  SrrUser? get currentAccount => _authRepository.currentUserSnapshot;

  @override
  Future<AuthUser?> currentUser() async {
    final user = await _authRepository.currentUser();
    if (user == null) return null;
    return _toAuthUser(user);
  }

  @override
  Future<AuthUser> signIn({
    required String email,
    required String password,
  }) async {
    await _emailHelper.signIn(email: email, password: password);
    final normalized = normalizedEmail(email);
    final user = await _authRepository.bootstrapFirebaseAuthUser(
      handleHint: handleHintFromEmail(normalized),
    );
    return _toAuthUser(user);
  }

  @override
  Future<AuthUser> register({
    required String email,
    required String password,
    required String displayName,
  }) async {
    await _emailHelper.register(
      email: email,
      password: password,
      displayName: displayName,
    );
    final normalized = normalizedEmail(email);
    final user = await _authRepository.bootstrapFirebaseAuthUser(
      displayName: displayName,
      handleHint: handleHintFromEmail(normalized),
      role: 'player',
    );
    return _toAuthUser(user);
  }

  Future<AuthUser> upsertProfile({
    required String firstName,
    required String lastName,
    required String role,
  }) async {
    final user = await _authRepository.upsertProfile(
      firstName: firstName,
      lastName: lastName,
      role: role,
    );
    return _toAuthUser(user);
  }

  @override
  Future<void> signOut() async {
    await _authRepository.logout();
    await _emailHelper.signOut();
    try {
      await _googleHelper.signOut();
    } catch (_) {
      // Google sign-out not critical if there was no session.
    }
  }

  @override
  Future<AuthUser> signInWithGoogle() async {
    try {
      final credential = await _googleHelper.signIn();
      final user = await _authRepository.bootstrapFirebaseAuthUser(
        displayName: credential.user?.displayName,
        handleHint: handleHintFromEmail(credential.user?.email),
        role: 'player',
      );
      return _toAuthUser(user);
    } on FirebaseAuthException catch (error) {
      if (error.code == 'popup-closed-by-user' ||
          error.code == 'cancelled-popup-request') {
        throw const SocialAuthCanceledException('Google');
      }
      rethrow;
    } on GoogleSignInException catch (error) {
      if (error.code == GoogleSignInExceptionCode.canceled ||
          error.code == GoogleSignInExceptionCode.interrupted) {
        throw const SocialAuthCanceledException('Google');
      }
      throw Exception(
        'Google sign-in failed (${error.code.name}): ${error.description ?? 'Unknown error'}.',
      );
    }
  }

  @override
  Future<AuthUser> signInWithApple() async {
    try {
      final credential = await _appleHelper.signIn();
      final user = await _authRepository.bootstrapFirebaseAuthUser(
        displayName: credential.user?.displayName,
        handleHint: handleHintFromEmail(credential.user?.email),
        role: 'player',
      );
      return _toAuthUser(user);
    } on FirebaseAuthException catch (error) {
      if (error.code == 'popup-closed-by-user' ||
          error.code == 'cancelled-popup-request' ||
          error.code == 'canceled' ||
          error.code == 'web-context-cancelled') {
        throw const SocialAuthCanceledException('Apple');
      }
      rethrow;
    } on SignInWithAppleAuthorizationException catch (error) {
      if (error.code == AuthorizationErrorCode.canceled) {
        throw const SocialAuthCanceledException('Apple');
      }
      rethrow;
    }
  }

  AuthUser _toAuthUser(SrrUser user) {
    return AuthUser(
      id: user.id.toString(),
      email: user.email,
      displayName: user.displayName,
      isAdmin: user.role == 'admin',
    );
  }
}
