// ---------------------------------------------------------------------------
// srr_app/lib/src/api/srr_api_client.dart
// ---------------------------------------------------------------------------
//
// Purpose:
// - Handles authenticated HTTP calls to SRR backend APIs with typed parsing.
// Architecture:
// - Network boundary for request construction, auth token handling, and timeout policy.
// - Exposes domain-specific operations consumed by repositories and UI flows.
// Author: Neil Khatu
// Copyright (c) The Khatu Family Trust
//
import 'dart:async';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/srr_models.dart';

class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

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

class SrrApiClient extends ChangeNotifier {
  SrrApiClient({required String baseUrl})
    : _baseUri = Uri.parse(baseUrl.endsWith('/') ? baseUrl : '$baseUrl/');

  static const _defaultRequestTimeout = Duration(seconds: 30);
  static const _heavyRequestTimeout = Duration(seconds: 120);

  final Uri _baseUri;
  final http.Client _http = http.Client();

  SrrUser? _currentUser;

  String get baseUrl {
    final value = _baseUri.toString();
    if (value.endsWith('/')) return value.substring(0, value.length - 1);
    return value;
  }

  SrrUser? get currentUserSnapshot => _currentUser;

  Future<void> bootstrapSession() async {
    final firebaseUser = FirebaseAuth.instance.currentUser;
    if (firebaseUser == null) {
      _currentUser = null;
      notifyListeners();
      return;
    }

    try {
      _currentUser = await bootstrapFirebaseAuthUser();
    } on ApiException {
      _currentUser = null;
    } on FirebaseAuthException {
      _currentUser = null;
    }
    notifyListeners();
  }

  Future<SrrUser?> currentUser() async {
    if (await _resolveAuthToken() == null) return null;
    _currentUser ??= await fetchCurrentUser();
    return _currentUser;
  }

  Future<SrrUser> fetchCurrentUser() async {
    final response = await _send('GET', '/auth/me', auth: true);
    final body = decodeObject(response.body);
    final user = SrrUser.fromJson(body);
    _currentUser = user;
    return user;
  }

  Future<SrrUser> bootstrapFirebaseAuthUser({
    String? displayName,
    String? handleHint,
    String? role,
  }) async {
    final response = await _send(
      'POST',
      '/auth/firebase',
      auth: true,
      body: <String, dynamic>{
        if (displayName != null && displayName.trim().isNotEmpty)
          'display_name': displayName.trim(),
        if (handleHint != null && handleHint.trim().isNotEmpty)
          'handle_hint': handleHint.trim(),
        if (role != null && role.trim().isNotEmpty) 'role': role.trim(),
      },
    );
    final user = SrrUser.fromJson(decodeObject(response.body));
    _currentUser = user;
    notifyListeners();
    return user;
  }

  Future<SrrUser> upsertProfile({
    required String firstName,
    required String lastName,
    required String role,
  }) async {
    final response = await _send(
      'POST',
      '/auth/profile',
      auth: true,
      body: <String, dynamic>{
        'first_name': firstName.trim(),
        'last_name': lastName.trim(),
        'role': role.trim().toLowerCase(),
      },
    );
    final user = SrrUser.fromJson(decodeObject(response.body));
    _currentUser = user;
    notifyListeners();
    return user;
  }

  Future<void> logout() async {
    if (FirebaseAuth.instance.currentUser != null) {
      try {
        await _send('POST', '/auth/logout', auth: true);
      } on ApiException {
        // Local state cleanup still happens below.
      }
    }
    await _clearSession();
  }

  Future<void> seedDemo({bool force = false}) async {
    await _send('POST', '/setup/seed?force=$force');
  }

  Future<List<SrrTournamentRecord>> fetchTournaments() async {
    final response = await _send('GET', '/tournaments', auth: true);
    final body = decodeObjectList(response.body);
    return body.map(SrrTournamentRecord.fromJson).toList(growable: false);
  }

  Future<SrrActiveTournamentStatus> fetchActiveTournamentStatus() async {
    final response = await _send('GET', '/tournaments/active', auth: true);
    return SrrActiveTournamentStatus.fromJson(decodeObject(response.body));
  }

  Future<SrrTournamentRecord> fetchTournament(int tournamentId) async {
    final response = await _send(
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
    final response = await _send(
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
    final response = await _send(
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
    final response = await _send(
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
    final response = await _send(
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
    final response = await _send('GET', '/rankings/years', auth: true);
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
    final response = await _send(
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
    final response = await _send(
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
    final response = await _send(
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
    final response = await _send(
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
    await _send('DELETE', '/tournaments/$tournamentId', auth: true);
  }

  Future<SrrTournamentSeedingSnapshot> fetchTournamentSeeding({
    required int tournamentId,
  }) async {
    final response = await _send(
      'GET',
      '/tournaments/$tournamentId/seeding',
      auth: true,
    );
    return SrrTournamentSeedingSnapshot.fromJson(decodeObject(response.body));
  }

  Future<SrrTournamentSeedingSnapshot> generateTournamentSeeding({
    required int tournamentId,
  }) async {
    final response = await _send(
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
    final response = await _send(
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
    final response = await _send(
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
    final response = await _send(
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
    final response = await _send(
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
    final response = await _send(
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
    final response = await _send(
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
    final response = await _send(
      'DELETE',
      '/tournaments/$tournamentId/matchups/current?group_number=$groupNumber',
      auth: true,
    );
    return SrrMatchupDeleteResult.fromJson(decodeObject(response.body));
  }

  Future<List<SrrPlayerLite>> fetchTournamentPlayers(int tournamentId) async {
    final response = await _send(
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
    final response = await _send(
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
    final response = await _send(
      'DELETE',
      '/tournaments/$tournamentId/players',
      auth: true,
    );
    return SrrTournamentPlayersDeleteResult.fromJson(
      decodeObject(response.body),
    );
  }

  Future<List<SrrPlayerLite>> fetchPlayers() async {
    final response = await _send('GET', '/players');
    final body = decodeObjectList(response.body);
    return body.map(SrrPlayerLite.fromJson).toList(growable: false);
  }

  Future<SrrTournamentSetupResult> setupTournament({
    required String tournamentName,
    required String defaultPassword,
    required SrrTournamentMetadata metadata,
    required List<SrrTournamentSetupPlayerInput> players,
  }) async {
    final response = await _send(
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

  Future<List<SrrRound>> fetchRounds({int? tournamentId}) async {
    final response = await _send(
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

    final response = await _send(
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
    final response = await _send('GET', path);
    final body = decodeObjectList(response.body);
    return body.map(SrrStandingRow.fromJson).toList(growable: false);
  }

  Future<List<SrrRoundPoints>> fetchRoundPoints({int? tournamentId}) async {
    final response = await _send(
      'GET',
      _withTournamentQuery('/round-points', tournamentId),
    );
    final body = decodeObjectList(response.body);
    return body.map(SrrRoundPoints.fromJson).toList(growable: false);
  }

  Future<List<SrrRoundStandings>> fetchRoundStandings({
    int? tournamentId,
  }) async {
    final response = await _send(
      'GET',
      _withTournamentQuery('/standings/by-round', tournamentId),
    );
    final body = decodeObjectList(response.body);
    return body.map(SrrRoundStandings.fromJson).toList(growable: false);
  }

  Future<SrrLiveSnapshot> fetchLiveSnapshot({int? tournamentId}) async {
    final response = await _send(
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

  Future<void> _clearSession() async {
    _currentUser = null;
    notifyListeners();
  }

  Future<http.Response> _send(
    String method,
    String path, {
    bool auth = false,
    Map<String, dynamic>? body,
  }) async {
    final url = _baseUri.resolve(
      path.startsWith('/') ? path.substring(1) : path,
    );
    final requestTimeout = _timeoutForPath(path);
    final headers = <String, String>{
      'Accept': 'application/json',
      if (body != null) 'Content-Type': 'application/json',
    };

    if (auth) {
      final token = await _resolveAuthToken(forceRefresh: true);
      if (token == null) {
        throw const ApiException('You are not signed in.');
      }
      headers['Authorization'] = 'Bearer $token';
    } else {
      final token = await _resolveAuthToken();
      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
      }
    }

    late final http.Response response;
    try {
      switch (method) {
        case 'GET':
          response = await _http
              .get(url, headers: headers)
              .timeout(requestTimeout);
          break;
        case 'POST':
          response = await _http
              .post(
                url,
                headers: headers,
                body: body == null ? null : json.encode(body),
              )
              .timeout(requestTimeout);
          break;
        case 'PATCH':
          response = await _http
              .patch(
                url,
                headers: headers,
                body: body == null ? null : json.encode(body),
              )
              .timeout(requestTimeout);
          break;
        case 'DELETE':
          response = await _http
              .delete(url, headers: headers)
              .timeout(requestTimeout);
          break;
        default:
          throw ApiException('Unsupported HTTP method: $method');
      }
    } on TimeoutException {
      throw ApiException(
        'Request timed out after ${requestTimeout.inSeconds}s. API endpoint: '
        '$baseUrl.$_timeoutGuidance',
      );
    } on http.ClientException catch (error) {
      throw ApiException(
        'Network error: ${error.message}. API endpoint: $baseUrl',
      );
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return response;
    }

    if (response.statusCode == 401 && auth) {
      await _clearSession();
    }

    throw ApiException(
      _extractError(response),
      statusCode: response.statusCode,
    );
  }

  String _extractError(http.Response response) {
    try {
      final object = json.decode(response.body) as Map<String, dynamic>;
      final detail = object['detail'];
      if (detail is String && detail.trim().isNotEmpty) {
        return detail;
      }
    } catch (_) {
      // Ignore parsing failures and fallback to status text.
    }
    return 'Request failed with status ${response.statusCode}.';
  }

  Future<String?> _resolveAuthToken({bool forceRefresh = false}) async {
    final firebaseUser = FirebaseAuth.instance.currentUser;
    if (firebaseUser == null) return null;
    try {
      final firebaseToken = await firebaseUser.getIdToken(forceRefresh);
      final normalized = firebaseToken?.trim();
      if (normalized != null && normalized.isNotEmpty) {
        return normalized;
      }
    } on FirebaseAuthException {
      return null;
    }
    return null;
  }

  String _withTournamentQuery(String path, int? tournamentId) {
    if (tournamentId == null) return path;
    final delimiter = path.contains('?') ? '&' : '?';
    return '$path${delimiter}tournament_id=$tournamentId';
  }

  Duration _timeoutForPath(String path) {
    final normalizedPath = path.toLowerCase();
    if (normalizedPath.contains('/tournaments/') &&
        normalizedPath.contains('/players/upload')) {
      return _heavyRequestTimeout;
    }
    if (normalizedPath.contains('/rankings/upload')) {
      return _heavyRequestTimeout;
    }
    if (normalizedPath.contains('/tournament/setup')) {
      return _heavyRequestTimeout;
    }
    return _defaultRequestTimeout;
  }

  String get _timeoutGuidance {
    final host = _baseUri.host.trim().toLowerCase();
    final isLocalHost =
        host == 'localhost' ||
        host == '127.0.0.1' ||
        host == '0.0.0.0' ||
        host == '10.0.2.2';

    if (!kIsWeb &&
        defaultTargetPlatform == TargetPlatform.android &&
        isLocalHost) {
      return ' On a physical Android phone, set SRR_API_URL to a reachable '
          'host (for example http://192.168.x.x:8000).';
    }
    return ' The server may be cold-starting or processing a large upload. '
        'Please retry.';
  }
}
