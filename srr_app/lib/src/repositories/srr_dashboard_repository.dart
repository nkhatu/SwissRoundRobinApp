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
import '../api/srr_api_client.dart';
import '../models/srr_models.dart';

class SrrDashboardRepository {
  const SrrDashboardRepository(this._apiClient);

  final SrrApiClient _apiClient;

  Future<SrrDashboardBundle> fetchDashboardBundle({int? tournamentId}) {
    return _apiClient.fetchDashboardBundle(tournamentId: tournamentId);
  }

  Future<SrrMatch> confirmMatchScore({
    required int matchId,
    int? score1,
    int? score2,
    Map<String, dynamic>? carrom,
  }) {
    return _apiClient.confirmScore(
      matchId: matchId,
      score1: score1,
      score2: score2,
      carrom: carrom,
    );
  }
}
