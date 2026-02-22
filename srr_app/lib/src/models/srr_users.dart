// ---------------------------------------------------------------------------
// srr_app/lib/src/models/srr_users.dart
// ---------------------------------------------------------------------------
//
// Purpose:
// - Declares the primary user models and their serialization helpers.
// Architecture:
// - Keeps auth-related structures in one place for easy reuse.
// Author: Neil Khatu
// Copyright (c) The Khatu Family Trust
//
import 'srr_tournament_models.dart';

String _srrAsString(Object? value, {String fallback = ''}) {
  if (value is String) return value;
  if (value is num || value is bool) return value.toString();
  return fallback;
}

int _srrAsInt(Object? value, {int fallback = 0}) {
  return switch (value) {
    int number => number,
    num number => number.toInt(),
    String text => int.tryParse(text.trim()) ?? fallback,
    _ => fallback,
  };
}

bool _srrAsBool(Object? value, {bool fallback = false}) {
  return switch (value) {
    bool flag => flag,
    num number => number != 0,
    String text => text.trim().toLowerCase() == 'true' || text.trim() == '1',
    _ => fallback,
  };
}

class SrrUser {
  const SrrUser({
    required this.id,
    required this.email,
    required this.handle,
    required this.displayName,
    required this.firstName,
    required this.lastName,
    required this.profileComplete,
    required this.role,
  });

  factory SrrUser.fromJson(Map<String, dynamic> json) => SrrUser(
    id: _srrAsInt(json['id']),
    email: (() {
      final email = _srrAsString(json['email']).trim();
      if (email.isNotEmpty) return email;
      final handle = _srrAsString(json['handle']).trim();
      if (handle.isNotEmpty) return handle;
      return '';
    })(),
    handle: (() {
      final handle = _srrAsString(json['handle']).trim();
      if (handle.isNotEmpty) return handle;
      final email = _srrAsString(json['email']).trim();
      if (email.isNotEmpty) return email;
      return 'user_${_srrAsInt(json['id'])}';
    })(),
    displayName: (() {
      final displayName = _srrAsString(json['display_name']).trim();
      if (displayName.isNotEmpty) return displayName;
      final email = _srrAsString(json['email']).trim();
      if (email.isNotEmpty) return email;
      return 'User ${_srrAsInt(json['id'])}';
    })(),
    firstName: (() {
      final value = _srrAsString(json['first_name']).trim();
      return value.isEmpty ? null : value;
    })(),
    lastName: (() {
      final value = _srrAsString(json['last_name']).trim();
      return value.isEmpty ? null : value;
    })(),
    profileComplete: _srrAsBool(json['profile_complete']),
    role: _srrAsString(json['role'], fallback: 'viewer'),
  );

  final int id;
  final String email;
  final String handle;
  final String displayName;
  final String? firstName;
  final String? lastName;
  final bool profileComplete;
  final String role;

  bool get isPlayer => role == 'player' || role == 'admin';
  bool get isViewer => role == 'viewer' || role == 'player' || role == 'admin';
  bool get isAdmin => role == 'admin';
}

class SrrActiveTournamentStatus {
  const SrrActiveTournamentStatus({
    required this.hasActiveTournament,
    required this.tournament,
  });

  factory SrrActiveTournamentStatus.fromJson(Map<String, dynamic> json) {
    final tournamentJson = json['tournament'];
    return SrrActiveTournamentStatus(
      hasActiveTournament: _srrAsBool(json['has_active_tournament']),
      tournament: tournamentJson is Map<String, dynamic>
          ? SrrTournamentRecord.fromJson(tournamentJson)
          : null,
    );
  }

  final bool hasActiveTournament;
  final SrrTournamentRecord? tournament;
}
