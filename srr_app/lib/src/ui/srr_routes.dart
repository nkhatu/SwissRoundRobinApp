// ---------------------------------------------------------------------------
// srr_app/lib/src/ui/srr_routes.dart
// ---------------------------------------------------------------------------
//
// Purpose:
// - Defines route constants used by SRR navigation flows.
// Architecture:
// - Routing contract module consumed across pages and menu handlers.
// - Keeps route naming centralized to reduce navigation drift.
// Author: Neil Khatu
// Copyright (c) The Khatu Family Trust
//
class SrrRoutes {
  const SrrRoutes._();

  static const genericUpload = '/upload';
  static const tournamentSetup = '/tournament/setup';
  static const tournamentSeeding = '/tournament/seeding';
  static const tournamentGroups = '/tournament/groups';
  static const roundMatchup = '/round/matchup';
  static const completeProfile = '/auth/complete-profile';
  static const currentNationalRanking = '/ranking/current';
}
