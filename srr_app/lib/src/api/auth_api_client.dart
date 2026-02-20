// ---------------------------------------------------------------------------
// srr_app/lib/src/api/auth_api_client.dart
// ---------------------------------------------------------------------------
//
// Purpose:
// - Handles auth/profile calls using the shared transport.
// Architecture:
// - Keeps user-specific endpoints alone so they can be reused by `SrrApiClient`.
// Author: The Khatu Family Trust
// Copyright (c) The Khatu Family Trust
//
import '../models/srr_models.dart';
import 'srr_api_transport.dart';

class AuthApiClient {
  AuthApiClient(this._transport);

  final SrrApiTransport _transport;

  Future<SrrUser?> fetchCurrentUser() async {
    final response = await _transport.send('GET', '/auth/me', auth: true);
    return SrrUser.fromJson(decodeObject(response.body));
  }

  Future<SrrUser> bootstrapFirebaseAuthUser({
    String? displayName,
    String? handleHint,
    String? role,
  }) async {
    final response = await _transport.send(
      'POST',
      '/auth/firebase',
      auth: true,
      body: <String, dynamic>{
        if (displayName != null && displayName.trim().isNotEmpty)
          'display_name': displayName.trim(),
        if (handleHint != null && handleHint.trim().isNotEmpty)
          'handle_hint': handleHint.trim(),
        if (role != null && role.trim().isNotEmpty) 'role': role.trim(),
      },
    );
    return SrrUser.fromJson(decodeObject(response.body));
  }

  Future<SrrUser> upsertProfile({
    required String firstName,
    required String lastName,
    required String role,
  }) async {
    final response = await _transport.send(
      'POST',
      '/auth/profile',
      auth: true,
      body: <String, dynamic>{
        'first_name': firstName.trim(),
        'last_name': lastName.trim(),
        'role': role.trim().toLowerCase(),
      },
    );
    return SrrUser.fromJson(decodeObject(response.body));
  }

  Future<void> logout() async {
    await _transport.send('POST', '/auth/logout', auth: true);
  }

  Future<void> seedDemo({bool force = false}) async {
    await _transport.send('POST', '/setup/seed?force=$force');
  }
}
