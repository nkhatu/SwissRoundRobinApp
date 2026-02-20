// ---------------------------------------------------------------------------
// srr_app/lib/src/api/srr_tournament_api.dart
// ---------------------------------------------------------------------------
//
// Purpose:
// - Encapsulates all tournament-centric API interactions.
// Architecture:
// - Feature-focused client that speaks directly with tournament, ranking, and
//   grouping endpoints using the shared transport layer.
// Author: Neil Khatu
// Copyright (c) The Khatu Family Trust
//
import '../models/srr_models.dart';
import 'srr_api_transport.dart';

class SrrTournamentApi {
  SrrTournamentApi(this._transport);

  final SrrApiTransport _transport;

  Future<List<SrrTournamentRecord>> fetchTournaments() async {
    final response = await _transport.send('GET', '/tournaments', auth: true);
    final body = decodeObjectList(response.body);
    return body.map(SrrTournamentRecord.fromJson).toList(growable: false);
  }

  Future<SrrActiveTournamentStatus> fetchActiveTournamentStatus() async {
    final response = await _transport.send(
      'GET',
      '/tournaments/active',
      auth: true,
    );
    return SrrActiveTournamentStatus.fromJson(decodeObject(response.body));
  }

  Future<SrrTournamentRecord> fetchTournament(int tournamentId) async {
    final response = await _transport.send(
      'GET',
      '/tournaments/$tournamentId',
      auth: true,
    );
    return SrrTournamentRecord.fromJson(decodeObject(response.body));
  }

  Future<SrrTournamentRecord> createTournament({
    required String tournamentName,
    SrrTournamentMetadata? metadata,
    String status = 'setup',
  }) async {
    final response = await _transport.send(
      'POST',
      '/tournaments',
      auth: true,
      body: <String, dynamic>{
        'tournament_name': tournamentName.trim(),
        'status': status.trim().toLowerCase(),
        if (metadata != null) ...metadata.toJson(),
      },
    );
    return SrrTournamentRecord.fromJson(decodeObject(response.body));
  }

  Future<SrrTournamentRecord> replicateTournament({
    required int tournamentId,
    required String tournamentName,
  }) async {
    final response = await _transport.send(
      'POST',
      '/tournaments/$tournamentId/replicate',
      auth: true,
      body: <String, dynamic>{'tournament_name': tournamentName.trim()},
    );
    return SrrTournamentRecord.fromJson(decodeObject(response.body));
  }

  Future<SrrTournamentRecord> updateTournament({
    required int tournamentId,
    required String tournamentName,
    required String status,
    required SrrTournamentMetadata metadata,
  }) async {
    final response = await _transport.send(
      'PATCH',
      '/tournaments/$tournamentId',
      auth: true,
      body: <String, dynamic>{
        'tournament_name': tournamentName.trim(),
        'status': status.trim().toLowerCase(),
        ...metadata.toJson(),
      },
    );
    return SrrTournamentRecord.fromJson(decodeObject(response.body));
  }

  Future<SrrTournamentRecord> updateTournamentWorkflowStep({
    required int tournamentId,
    required String stepKey,
    required String status,
  }) async {
    final response = await _transport.send(
      'PATCH',
      '/tournaments/$tournamentId/workflow',
      auth: true,
      body: <String, dynamic>{
        'step_key': stepKey.trim(),
        'status': status.trim().toLowerCase(),
      },
    );
    return SrrTournamentRecord.fromJson(decodeObject(response.body));
  }

  Future<List<SrrNationalRankingOption>> fetchNationalRankingOptions() async {
    final response = await _transport.send('GET', '/rankings/years', auth: true);
    final body = decodeObject(response.body);
    final rankingRows =
        (body['rankings'] as List<dynamic>? ?? const <dynamic>[])
            .whereType<Map<String, dynamic>>()
            .map(SrrNationalRankingOption.fromJson)
            .toList(growable: false);
    if (rankingRows.isNotEmpty) {
      final deduped = <String, SrrNationalRankingOption>{};
      for (final row in rankingRows) {
        deduped.putIfAbsent(row.key, () => row);
      }
      final items = deduped.values.toList(growable: false);
      items.sort((a, b) {
        final byYear = b.rankingYear.compareTo(a.rankingYear);
        if (byYear != 0) return byYear;
        return a.rankingDescription.toLowerCase().compareTo(
          b.rankingDescription.toLowerCase(),
        );
      });
      return items;
    }

    final years =
        (body['years'] as List<dynamic>? ?? const <dynamic>[])
            .map((entry) => entry is num ? entry.toInt() : null)
            .whereType<int>()
            .toList(growable: false)
          ..sort((a, b) => b - a);
    return years
        .map(
          (year) => SrrNationalRankingOption(
            rankingYear: year,
            rankingDescription: 'Default',
          ),
        )
        .toList(growable: false);
  }

  Future<List<SrrNationalRankingRecord>> fetchNationalRankingRows({
    required int rankingYear,
    required String rankingDescription,
  }) async {
    final response = await _transport.send(
      'GET',
      '/rankings?ranking_year=$rankingYear&ranking_description=${Uri.encodeQueryComponent(rankingDescription.trim())}',
      auth: true,
    );
    final body = decodeObject(response.body);
    return (body['rows'] as List<dynamic>? ?? const <dynamic>[])
        .whereType<Map<String, dynamic>>()
        .map(SrrNationalRankingRecord.fromJson)
        .toList(growable: false);
  }

  Future<SrrNationalRankingUploadResult> uploadNationalRankings({
    required List<SrrNationalRankingInput> rows,
    required String rankingDescription,
  }) async {
    final response = await _transport.send(
      'POST',
      '/rankings/upload',
      auth: true,
      body: <String, dynamic>{
        'ranking_description': rankingDescription.trim(),
        'rows': rows.map((entry) => entry.toJson()).toList(growable: false),
      },
    );
    return SrrNationalRankingUploadResult.fromJson(decodeObject(response.body));
  }

  Future<SrrNationalRankingDeleteResult> deleteNationalRankingList({
    required int rankingYear,
    required String rankingDescription,
  }) async {
    final response = await _transport.send(
      'POST',
      '/rankings/delete',
      auth: true,
      body: <String, dynamic>{
        'ranking_year': rankingYear,
        'ranking_description': rankingDescription.trim(),
      },
    );
    return SrrNationalRankingDeleteResult.fromJson(decodeObject(response.body));
  }

  Future<SrrTournamentRecord> selectTournamentRanking({
    required int tournamentId,
    required int rankingYear,
    required String rankingDescription,
  }) async {
    final response = await _transport.send(
      'POST',
      '/tournaments/$tournamentId/ranking-selection',
      auth: true,
      body: <String, dynamic>{
        'ranking_year': rankingYear,
        'ranking_description': rankingDescription.trim(),
      },
    );
    return SrrTournamentRecord.fromJson(decodeObject(response.body));
  }

  Future<void> deleteTournament(int tournamentId) async {
    await _transport.send(
      'DELETE',
      '/tournaments/$tournamentId',
      auth: true,
    );
  }

  Future<SrrTournamentSeedingSnapshot> fetchTournamentSeeding({
    required int tournamentId,
  }) async {
    final response = await _transport.send(
      'GET',
      '/tournaments/$tournamentId/seeding',
      auth: true,
    );
    return SrrTournamentSeedingSnapshot.fromJson(decodeObject(response.body));
  }

  Future<SrrTournamentSeedingSnapshot> generateTournamentSeeding({
    required int tournamentId,
  }) async {
    final response = await _transport.send(
      'POST',
      '/tournaments/$tournamentId/seeding/generate',
      auth: true,
    );
    return SrrTournamentSeedingSnapshot.fromJson(decodeObject(response.body));
  }

  Future<SrrTournamentSeedingSnapshot> reorderTournamentSeeding({
    required int tournamentId,
    required List<int> orderedPlayerIds,
  }) async {
    final response = await _transport.send(
      'PATCH',
      '/tournaments/$tournamentId/seeding/order',
      auth: true,
      body: <String, dynamic>{'ordered_player_ids': orderedPlayerIds},
    );
    return SrrTournamentSeedingSnapshot.fromJson(decodeObject(response.body));
  }

  Future<SrrTournamentSeedingDeleteResult> deleteTournamentSeeding({
    required int tournamentId,
  }) async {
    final response = await _transport.send(
      'DELETE',
      '/tournaments/$tournamentId/seeding',
      auth: true,
    );
    return SrrTournamentSeedingDeleteResult.fromJson(
      decodeObject(response.body),
    );
  }

  Future<SrrTournamentGroupsSnapshot> fetchTournamentGroups({
    required int tournamentId,
  }) async {
    final response = await _transport.send(
      'GET',
      '/tournaments/$tournamentId/groups',
      auth: true,
    );
    return SrrTournamentGroupsSnapshot.fromJson(decodeObject(response.body));
  }

  Future<SrrTournamentGroupsSnapshot> generateTournamentGroups({
    required int tournamentId,
    required String method,
  }) async {
    final response = await _transport.send(
      'POST',
      '/tournaments/$tournamentId/groups/generate',
      auth: true,
      body: <String, dynamic>{'method': method.trim().toLowerCase()},
    );
    return SrrTournamentGroupsSnapshot.fromJson(decodeObject(response.body));
  }

  Future<SrrTournamentGroupsDeleteResult> deleteTournamentGroups({
    required int tournamentId,
  }) async {
    final response = await _transport.send(
      'DELETE',
      '/tournaments/$tournamentId/groups',
      auth: true,
    );
    return SrrTournamentGroupsDeleteResult.fromJson(
      decodeObject(response.body),
    );
  }

  Future<SrrMatchupGenerateResult> generateTournamentGroupMatchups({
    required int tournamentId,
    required int groupNumber,
    required String roundOneMethod,
  }) async {
    final response = await _transport.send(
      'POST',
      '/tournaments/$tournamentId/matchups/generate',
      auth: true,
      body: <String, dynamic>{
        'group_number': groupNumber,
        'round_one_method': roundOneMethod.trim().toLowerCase(),
      },
    );
    return SrrMatchupGenerateResult.fromJson(decodeObject(response.body));
  }

  Future<SrrMatchupDeleteResult> deleteCurrentTournamentGroupMatchups({
    required int tournamentId,
    required int groupNumber,
  }) async {
    final response = await _transport.send(
      'DELETE',
      '/tournaments/$tournamentId/matchups/current?group_number=$groupNumber',
      auth: true,
    );
    return SrrMatchupDeleteResult.fromJson(decodeObject(response.body));
  }

  Future<SrrTournamentSetupResult> setupTournament({
    required String tournamentName,
    required String defaultPassword,
    required SrrTournamentMetadata metadata,
    required List<SrrTournamentSetupPlayerInput> players,
  }) async {
    final response = await _transport.send(
      'POST',
      '/tournament/setup',
      auth: true,
      body: <String, dynamic>{
        'tournament_name': tournamentName.trim(),
        'default_password': defaultPassword.trim(),
        ...metadata.toJson(),
        'players': players
            .map((entry) => entry.toJson())
            .toList(growable: false),
      },
    );
    return SrrTournamentSetupResult.fromJson(decodeObject(response.body));
  }
}
