// ---------------------------------------------------------------------------
// srr_app/lib/src/api/srr_player_api.dart
// ---------------------------------------------------------------------------
//
// Purpose:
// - Consolidates player-focused endpoints such as uploads and listings.
// Architecture:
// - Reuses the shared transport for authentication and payload handling.
// Author: Neil Khatu
// Copyright (c) The Khatu Family Trust
//
import '../models/srr_models.dart';
import 'srr_api_transport.dart';

class SrrPlayerApi {
  SrrPlayerApi(this._transport);

  final SrrApiTransport _transport;

  Future<List<SrrPlayerLite>> fetchTournamentPlayers(int tournamentId) async {
    final response = await _transport.send(
      'GET',
      '/tournaments/$tournamentId/players',
      auth: true,
    );
    final body = decodeObjectList(response.body);
    return body.map(SrrPlayerLite.fromJson).toList(growable: false);
  }

  Future<SrrTournamentPlayersUploadResult> uploadTournamentPlayers({
    required int tournamentId,
    required List<SrrTournamentSetupPlayerInput> players,
  }) async {
    final response = await _transport.send(
      'POST',
      '/tournaments/$tournamentId/players/upload',
      auth: true,
      body: <String, dynamic>{
        'players': players
            .map((entry) => entry.toJson())
            .toList(growable: false),
      },
    );
    return SrrTournamentPlayersUploadResult.fromJson(
      decodeObject(response.body),
    );
  }

  Future<SrrTournamentPlayersDeleteResult> deleteTournamentPlayers(
    int tournamentId,
  ) async {
    final response = await _transport.send(
      'DELETE',
      '/tournaments/$tournamentId/players',
      auth: true,
    );
    return SrrTournamentPlayersDeleteResult.fromJson(decodeObject(response.body));
  }

  Future<List<SrrPlayerLite>> fetchPlayers() async {
    final response = await _transport.send('GET', '/players');
    final body = decodeObjectList(response.body);
    return body.map(SrrPlayerLite.fromJson).toList(growable: false);
  }
}
