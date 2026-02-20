// ---------------------------------------------------------------------------
// srr_app/lib/src/repositories/srr_dashboard_repository.dart
// ---------------------------------------------------------------------------
//
// Purpose:
// - Provides dashboard and live standings data access operations.
// Architecture:
// - Repository abstraction for dashboard-focused API retrieval and model mapping.
// - Allows home/dashboard pages to consume typed data without transport concerns.
// Author: Neil Khatu
// Copyright (c) The Khatu Family Trust
//
import '../api/srr_dashboard_api.dart';
import '../models/srr_models.dart';

class SrrDashboardRepository {
  const SrrDashboardRepository(this._dashboardApi);

  final SrrDashboardApi _dashboardApi;

  Future<SrrDashboardBundle> fetchDashboardBundle({int? tournamentId}) {
    return _dashboardApi.fetchDashboardBundle(tournamentId: tournamentId);
  }

  Future<List<SrrRound>> fetchRounds({int? tournamentId}) {
    return _dashboardApi.fetchRounds(tournamentId: tournamentId);
  }

  Future<SrrMatch> confirmMatchScore({
    required int matchId,
    int? score1,
    int? score2,
    Map<String, dynamic>? carrom,
  }) {
    return _dashboardApi.confirmScore(
      matchId: matchId,
      score1: score1,
      score2: score2,
      carrom: carrom,
    );
  }
}
