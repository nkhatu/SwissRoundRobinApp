// ---------------------------------------------------------------------------
// srr_app/lib/src/repositories/srr_player_repository.dart
// ---------------------------------------------------------------------------
//
// Purpose:
// - Provides player-facing repository operations backed by API client calls.
// Architecture:
// - Repository abstraction that isolates player data access from UI components.
// - Returns typed domain models for upload and tournament pages.
// Author: Neil Khatu
// Copyright (c) The Khatu Family Trust
//
import '../api/srr_player_api.dart';
import '../models/srr_models.dart';

class SrrPlayerRepository {
  const SrrPlayerRepository(this._playerApi);

  final SrrPlayerApi _playerApi;

  Future<List<SrrPlayerLite>> fetchTournamentPlayers(int tournamentId) {
    return _playerApi.fetchTournamentPlayers(tournamentId);
  }

  Future<SrrTournamentPlayersUploadResult> uploadTournamentPlayers({
    required int tournamentId,
    required List<SrrTournamentSetupPlayerInput> players,
  }) {
    return _playerApi.uploadTournamentPlayers(
      tournamentId: tournamentId,
      players: players,
    );
  }

  Future<SrrTournamentPlayersDeleteResult> deleteTournamentPlayers(
    int tournamentId,
  ) {
    return _playerApi.deleteTournamentPlayers(tournamentId);
  }
}
