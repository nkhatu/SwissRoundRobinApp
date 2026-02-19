// ---------------------------------------------------------------------------
// srr_app/lib/src/repositories/srr_tournament_repository.dart
// ---------------------------------------------------------------------------
// 
// Purpose:
// - Provides tournament repository operations for setup, seeding, players, and rankings.
// Architecture:
// - Repository abstraction isolating tournament data access from presentation code.
// - Wraps API client endpoints into typed operations used by admin workflows.
// Author: Neil Khatu
// Copyright (c) The Khatu Family Trust
// 
import '../api/srr_api_client.dart';
import '../models/srr_models.dart';

class SrrTournamentRepository {
  const SrrTournamentRepository(this._apiClient);

  final SrrApiClient _apiClient;

  Future<List<SrrTournamentRecord>> fetchTournaments() {
    return _apiClient.fetchTournaments();
  }

  Future<SrrTournamentRecord> fetchTournament(int tournamentId) {
    return _apiClient.fetchTournament(tournamentId);
  }

  Future<SrrTournamentRecord> createTournament({
    required String tournamentName,
    SrrTournamentMetadata? metadata,
    String status = 'setup',
  }) {
    return _apiClient.createTournament(
      tournamentName: tournamentName,
      metadata: metadata,
      status: status,
    );
  }

  Future<SrrTournamentRecord> replicateTournament({
    required int tournamentId,
    required String tournamentName,
  }) {
    return _apiClient.replicateTournament(
      tournamentId: tournamentId,
      tournamentName: tournamentName,
    );
  }

  Future<SrrTournamentRecord> updateTournament({
    required int tournamentId,
    required String tournamentName,
    required String status,
    required SrrTournamentMetadata metadata,
  }) {
    return _apiClient.updateTournament(
      tournamentId: tournamentId,
      tournamentName: tournamentName,
      status: status,
      metadata: metadata,
    );
  }

  Future<SrrTournamentRecord> updateTournamentWorkflowStep({
    required int tournamentId,
    required String stepKey,
    required String status,
  }) {
    return _apiClient.updateTournamentWorkflowStep(
      tournamentId: tournamentId,
      stepKey: stepKey,
      status: status,
    );
  }

  Future<List<SrrNationalRankingOption>> fetchNationalRankingOptions() {
    return _apiClient.fetchNationalRankingOptions();
  }

  Future<List<SrrNationalRankingRecord>> fetchNationalRankingRows({
    required int rankingYear,
    required String rankingDescription,
  }) {
    return _apiClient.fetchNationalRankingRows(
      rankingYear: rankingYear,
      rankingDescription: rankingDescription,
    );
  }

  Future<SrrNationalRankingUploadResult> uploadNationalRankings({
    required List<SrrNationalRankingInput> rows,
    required String rankingDescription,
  }) {
    return _apiClient.uploadNationalRankings(
      rows: rows,
      rankingDescription: rankingDescription,
    );
  }

  Future<SrrNationalRankingDeleteResult> deleteNationalRankingList({
    required int rankingYear,
    required String rankingDescription,
  }) {
    return _apiClient.deleteNationalRankingList(
      rankingYear: rankingYear,
      rankingDescription: rankingDescription,
    );
  }

  Future<SrrTournamentRecord> selectTournamentRanking({
    required int tournamentId,
    required int rankingYear,
    required String rankingDescription,
  }) {
    return _apiClient.selectTournamentRanking(
      tournamentId: tournamentId,
      rankingYear: rankingYear,
      rankingDescription: rankingDescription,
    );
  }

  Future<void> deleteTournament(int tournamentId) {
    return _apiClient.deleteTournament(tournamentId);
  }

  Future<SrrTournamentSeedingSnapshot> fetchTournamentSeeding({
    required int tournamentId,
  }) {
    return _apiClient.fetchTournamentSeeding(tournamentId: tournamentId);
  }

  Future<SrrTournamentSeedingSnapshot> generateTournamentSeeding({
    required int tournamentId,
  }) {
    return _apiClient.generateTournamentSeeding(tournamentId: tournamentId);
  }

  Future<SrrTournamentSeedingSnapshot> reorderTournamentSeeding({
    required int tournamentId,
    required List<int> orderedPlayerIds,
  }) {
    return _apiClient.reorderTournamentSeeding(
      tournamentId: tournamentId,
      orderedPlayerIds: orderedPlayerIds,
    );
  }

  Future<SrrTournamentSeedingDeleteResult> deleteTournamentSeeding({
    required int tournamentId,
  }) {
    return _apiClient.deleteTournamentSeeding(tournamentId: tournamentId);
  }
}
