// ---------------------------------------------------------------------------
// srr_app/lib/src/api/srr_dashboard_api.dart
// ---------------------------------------------------------------------------
//
// Purpose:
// - Contains the live, rounds, and standings APIs powering dashboards.
// Architecture:
// - Builds typed responses from transport calls while keeping UI threads lean.
// Author: Neil Khatu
// Copyright (c) The Khatu Family Trust
//
import '../models/srr_models.dart';
import 'api_exceptions.dart';
import 'srr_api_transport.dart';

class SrrDashboardBundle {
  const SrrDashboardBundle({
    required this.liveSnapshot,
    required this.roundPoints,
    required this.roundStandings,
  });

  final SrrLiveSnapshot liveSnapshot;
  final List<SrrRoundPoints> roundPoints;
  final List<SrrRoundStandings> roundStandings;
}

class SrrDashboardApi {
  SrrDashboardApi(this._transport);

  final SrrApiTransport _transport;

  Future<List<SrrRound>> fetchRounds({int? tournamentId}) async {
    final response = await _transport.send(
      'GET',
      _withTournamentQuery('/rounds', tournamentId),
      auth: false,
    );
    final body = decodeObjectList(response.body);
    return body.map(SrrRound.fromJson).toList(growable: false);
  }

  Future<SrrMatch> confirmScore({
    required int matchId,
    int? score1,
    int? score2,
    Map<String, dynamic>? carrom,
  }) async {
    if (score1 == null && score2 == null && carrom == null) {
      throw const ApiException(
        'Provide score1/score2 or a carrom payload with board results.',
      );
    }
    if ((score1 == null) != (score2 == null)) {
      throw const ApiException('score1 and score2 must be supplied together.');
    }

    final body = <String, dynamic>{};
    if (score1 != null) {
      body['score1'] = score1;
    }
    if (score2 != null) {
      body['score2'] = score2;
    }
    if (carrom != null) {
      body.addAll(carrom);
    }

    final response = await _transport.send(
      'POST',
      '/matches/$matchId/confirm',
      auth: true,
      body: body,
    );
    return SrrMatch.fromJson(decodeObject(response.body));
  }

  Future<List<SrrStandingRow>> fetchStandings({
    int? round,
    int? tournamentId,
  }) async {
    var path = round == null ? '/standings' : '/standings?round=$round';
    path = _withTournamentQuery(path, tournamentId);
    final response = await _transport.send('GET', path);
    final body = decodeObjectList(response.body);
    return body.map(SrrStandingRow.fromJson).toList(growable: false);
  }

  Future<List<SrrRoundPoints>> fetchRoundPoints({int? tournamentId}) async {
    final response = await _transport.send(
      'GET',
      _withTournamentQuery('/round-points', tournamentId),
    );
    final body = decodeObjectList(response.body);
    return body.map(SrrRoundPoints.fromJson).toList(growable: false);
  }

  Future<List<SrrRoundStandings>> fetchRoundStandings({
    int? tournamentId,
  }) async {
    final response = await _transport.send(
      'GET',
      _withTournamentQuery('/standings/by-round', tournamentId),
    );
    final body = decodeObjectList(response.body);
    return body.map(SrrRoundStandings.fromJson).toList(growable: false);
  }

  Future<SrrLiveSnapshot> fetchLiveSnapshot({int? tournamentId}) async {
    final response = await _transport.send(
      'GET',
      _withTournamentQuery('/live', tournamentId),
    );
    return SrrLiveSnapshot.fromJson(decodeObject(response.body));
  }

  Future<SrrDashboardBundle> fetchDashboardBundle({int? tournamentId}) async {
    final results = await Future.wait<dynamic>([
      fetchLiveSnapshot(tournamentId: tournamentId),
      fetchRoundPoints(tournamentId: tournamentId),
      fetchRoundStandings(tournamentId: tournamentId),
    ]);
    return SrrDashboardBundle(
      liveSnapshot: results[0] as SrrLiveSnapshot,
      roundPoints: results[1] as List<SrrRoundPoints>,
      roundStandings: results[2] as List<SrrRoundStandings>,
    );
  }

  String _withTournamentQuery(String path, int? tournamentId) {
    if (tournamentId == null) return path;
    final delimiter = path.contains('?') ? '&' : '?';
    return '$path${delimiter}tournament_id=$tournamentId';
  }
}
