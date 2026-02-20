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
import '../api/srr_tournament_api.dart';
import '../models/srr_models.dart';

class SrrTournamentRepository {
  const SrrTournamentRepository(this._tournamentApi);

  final SrrTournamentApi _tournamentApi;

  Future<List<SrrTournamentRecord>> fetchTournaments() {
    return _tournamentApi.fetchTournaments();
  }

  Future<SrrActiveTournamentStatus> fetchActiveTournamentStatus() {
    return _tournamentApi.fetchActiveTournamentStatus();
  }

  Future<SrrTournamentRecord> fetchTournament(int tournamentId) {
    return _tournamentApi.fetchTournament(tournamentId);
  }

  Future<SrrTournamentRecord> createTournament({
    required String tournamentName,
    SrrTournamentMetadata? metadata,
    String status = 'setup',
  }) {
    return _tournamentApi.createTournament(
      tournamentName: tournamentName,
      metadata: metadata,
      status: status,
    );
  }

  Future<SrrTournamentRecord> replicateTournament({
    required int tournamentId,
    required String tournamentName,
  }) {
    return _tournamentApi.replicateTournament(
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
    return _tournamentApi.updateTournament(
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
    return _tournamentApi.updateTournamentWorkflowStep(
      tournamentId: tournamentId,
      stepKey: stepKey,
      status: status,
    );
  }

  Future<List<SrrNationalRankingOption>> fetchNationalRankingOptions() {
    return _tournamentApi.fetchNationalRankingOptions();
  }

  Future<List<SrrNationalRankingRecord>> fetchNationalRankingRows({
    required int rankingYear,
    required String rankingDescription,
  }) {
    return _tournamentApi.fetchNationalRankingRows(
      rankingYear: rankingYear,
      rankingDescription: rankingDescription,
    );
  }

  Future<SrrNationalRankingUploadResult> uploadNationalRankings({
    required List<SrrNationalRankingInput> rows,
    required String rankingDescription,
  }) {
    return _tournamentApi.uploadNationalRankings(
      rows: rows,
      rankingDescription: rankingDescription,
    );
  }

  Future<SrrNationalRankingDeleteResult> deleteNationalRankingList({
    required int rankingYear,
    required String rankingDescription,
  }) {
    return _tournamentApi.deleteNationalRankingList(
      rankingYear: rankingYear,
      rankingDescription: rankingDescription,
    );
  }

  Future<SrrTournamentRecord> selectTournamentRanking({
    required int tournamentId,
    required int rankingYear,
    required String rankingDescription,
  }) {
    return _tournamentApi.selectTournamentRanking(
      tournamentId: tournamentId,
      rankingYear: rankingYear,
      rankingDescription: rankingDescription,
    );
  }

  Future<void> deleteTournament(int tournamentId) {
    return _tournamentApi.deleteTournament(tournamentId);
  }

  Future<SrrTournamentSeedingSnapshot> fetchTournamentSeeding({
    required int tournamentId,
  }) {
    return _tournamentApi.fetchTournamentSeeding(tournamentId: tournamentId);
  }

  Future<SrrTournamentSeedingSnapshot> generateTournamentSeeding({
    required int tournamentId,
  }) {
    return _tournamentApi.generateTournamentSeeding(tournamentId: tournamentId);
  }

  Future<SrrTournamentSeedingSnapshot> reorderTournamentSeeding({
    required int tournamentId,
    required List<int> orderedPlayerIds,
  }) {
    return _tournamentApi.reorderTournamentSeeding(
      tournamentId: tournamentId,
      orderedPlayerIds: orderedPlayerIds,
    );
  }

  Future<SrrTournamentSeedingDeleteResult> deleteTournamentSeeding({
    required int tournamentId,
  }) {
    return _tournamentApi.deleteTournamentSeeding(tournamentId: tournamentId);
  }

  Future<SrrTournamentGroupsSnapshot> fetchTournamentGroups({
    required int tournamentId,
  }) {
    return _tournamentApi.fetchTournamentGroups(tournamentId: tournamentId);
  }

  Future<SrrTournamentGroupsSnapshot> generateTournamentGroups({
    required int tournamentId,
    required String method,
  }) {
    return _tournamentApi.generateTournamentGroups(
      tournamentId: tournamentId,
      method: method,
    );
  }

  Future<SrrTournamentGroupsDeleteResult> deleteTournamentGroups({
    required int tournamentId,
  }) {
    return _tournamentApi.deleteTournamentGroups(tournamentId: tournamentId);
  }

  Future<SrrMatchupGenerateResult> generateTournamentGroupMatchups({
    required int tournamentId,
    required int groupNumber,
    required String roundOneMethod,
  }) {
    return _tournamentApi.generateTournamentGroupMatchups(
      tournamentId: tournamentId,
      groupNumber: groupNumber,
      roundOneMethod: roundOneMethod,
    );
  }

  Future<SrrMatchupDeleteResult> deleteCurrentTournamentGroupMatchups({
    required int tournamentId,
    required int groupNumber,
  }) {
    return _tournamentApi.deleteCurrentTournamentGroupMatchups(
      tournamentId: tournamentId,
      groupNumber: groupNumber,
    );
  }
}
