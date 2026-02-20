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
    id: json['id'] as int,
    email: (json['email'] as String?) ?? (json['handle'] as String),
    handle: json['handle'] as String,
    displayName: json['display_name'] as String,
    firstName: json['first_name'] as String?,
    lastName: json['last_name'] as String?,
    profileComplete: json['profile_complete'] as bool? ?? false,
    role: json['role'] as String,
  );

  final int id;
  final String email;
  final String handle;
  final String displayName;
  final String? firstName;
  final String? lastName;
  final bool profileComplete;
  final String role;

  bool get isPlayer => role == 'player';
  bool get isViewer => role == 'viewer';
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
      hasActiveTournament: json['has_active_tournament'] as bool? ?? false,
      tournament: tournamentJson is Map<String, dynamic>
          ? SrrTournamentRecord.fromJson(tournamentJson)
          : null,
    );
  }

  final bool hasActiveTournament;
  final SrrTournamentRecord? tournament;
}
