// ---------------------------------------------------------------------------
// srr_app/lib/src/repositories/srr_auth_repository.dart
// ---------------------------------------------------------------------------
//
// Purpose:
// - Abstracts auth-related HTTP calls while managing session state.
// Architecture:
// - Repository layer that fronts `AuthApiClient`, caches the active user, and
//   centralizes Firebase session bootstrap/logout logic for services.
// Author: Neil Khatu
// Copyright (c) The Khatu Family Trust
//
import 'package:firebase_auth/firebase_auth.dart';

import '../api/auth_api_client.dart';
import '../models/srr_models.dart';

class SrrAuthRepository {
  SrrAuthRepository(AuthApiClient authApi) : _authApi = authApi;

  final AuthApiClient _authApi;
  SrrUser? _currentUser;

  SrrUser? get currentUserSnapshot => _currentUser;

  Future<void> bootstrapSession() async {
    final firebaseUser = FirebaseAuth.instance.currentUser;
    if (firebaseUser == null) {
      _currentUser = null;
      return;
    }

    try {
      _currentUser = await _authApi.bootstrapFirebaseAuthUser();
    } catch (_) {
      _currentUser = null;
    }
  }

  Future<SrrUser?> currentUser() async {
    final firebaseUser = FirebaseAuth.instance.currentUser;
    if (firebaseUser == null) {
      _currentUser = null;
      return null;
    }
    if (_currentUser != null) {
      return _currentUser;
    }
    return fetchCurrentUser();
  }

  Future<SrrUser?> fetchCurrentUser() async {
    final user = await _authApi.fetchCurrentUser();
    _currentUser = user;
    return user;
  }

  Future<SrrUser> bootstrapFirebaseAuthUser({
    String? displayName,
    String? handleHint,
    String? role,
  }) async {
    final user = await _authApi.bootstrapFirebaseAuthUser(
      displayName: displayName,
      handleHint: handleHint,
      role: role,
    );
    _currentUser = user;
    return user;
  }

  Future<SrrUser> upsertProfile({
    required String firstName,
    required String lastName,
    required String role,
  }) async {
    final user = await _authApi.upsertProfile(
      firstName: firstName,
      lastName: lastName,
      role: role,
    );
    _currentUser = user;
    return user;
  }

  Future<void> logout() async {
    await _authApi.logout();
    _currentUser = null;
  }

  Future<void> seedDemo({bool force = false}) =>
      _authApi.seedDemo(force: force);
}
