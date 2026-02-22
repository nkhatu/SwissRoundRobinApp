// ---------------------------------------------------------------------------
// srr_app/lib/src/models/srr_match_models.dart
// ---------------------------------------------------------------------------
//
// Purpose:
// - Contains match, round, and live snapshot models.
// Architecture:
// - Depends on the shared enum helpers for parsing and keeps all scoring shapes together.
// Author: Neil Khatu
// Copyright (c) The Khatu Family Trust
//
import 'srr_enums.dart';

String _srrAsString(Object? value, {String fallback = ''}) {
  if (value is String) return value;
  if (value is num || value is bool) return value.toString();
  return fallback;
}

int _srrAsInt(Object? value, {int fallback = 0}) {
  return switch (value) {
    int number => number,
    num number => number.toInt(),
    String text => int.tryParse(text.trim()) ?? fallback,
    _ => fallback,
  };
}

int? _srrAsNullableInt(Object? value) {
  if (value == null) return null;
  return switch (value) {
    int number => number,
    num number => number.toInt(),
    String text => int.tryParse(text.trim()),
    _ => null,
  };
}

bool _srrAsBool(Object? value, {bool fallback = false}) {
  return switch (value) {
    bool flag => flag,
    num number => number != 0,
    String text => text.trim().toLowerCase() == 'true' || text.trim() == '1',
    _ => fallback,
  };
}

Map<String, dynamic>? _srrAsObjectMapOrNull(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) {
    return value.map((key, item) => MapEntry(key.toString(), item));
  }
  return null;
}

List<Map<String, dynamic>> _srrAsObjectMapList(Object? value) {
  if (value is! List) return const <Map<String, dynamic>>[];
  return value
      .map(_srrAsObjectMapOrNull)
      .whereType<Map<String, dynamic>>()
      .toList(growable: false);
}

class SrrScoreConfirmation {
  const SrrScoreConfirmation({required this.score1, required this.score2});

  factory SrrScoreConfirmation.fromJson(Map<String, dynamic> json) =>
      SrrScoreConfirmation(
        score1: _srrAsInt(json['score1']),
        score2: _srrAsInt(json['score2']),
      );

  final int score1;
  final int score2;
}

class SrrTossState {
  const SrrTossState({
    required this.tossWinnerPlayerId,
    required this.tossDecision,
    required this.firstStrikerPlayerId,
    required this.firstStrikerColor,
  });

  factory SrrTossState.fromJson(Map<String, dynamic> json) => SrrTossState(
    tossWinnerPlayerId: _srrAsNullableInt(json['toss_winner_player_id']),
    tossDecision: srrTossDecisionFromString(
      _srrAsString(json['toss_decision']),
    ),
    firstStrikerPlayerId: _srrAsNullableInt(json['first_striker_player_id']),
    firstStrikerColor: srrCarromColorFromString(
      _srrAsString(json['first_striker_color']),
    ),
  );

  final int? tossWinnerPlayerId;
  final SrrTossDecision? tossDecision;
  final int? firstStrikerPlayerId;
  final SrrCarromColor? firstStrikerColor;
}

class SrrCarromBoard {
  const SrrCarromBoard({
    required this.boardNumber,
    required this.strikerPlayerId,
    required this.strikerColor,
    required this.strikerPocketed,
    required this.nonStrikerPocketed,
    required this.queenPocketedBy,
    required this.pointsPlayer1,
    required this.pointsPlayer2,
    required this.winnerPlayerId,
    required this.isTiebreaker,
    required this.isSuddenDeath,
    required this.notes,
  });

  factory SrrCarromBoard.fromJson(Map<String, dynamic> json) => SrrCarromBoard(
    boardNumber: _srrAsInt(json['board_number']),
    strikerPlayerId: _srrAsNullableInt(json['striker_player_id']),
    strikerColor: srrCarromColorFromString(_srrAsString(json['striker_color'])),
    strikerPocketed: _srrAsNullableInt(json['striker_pocketed']),
    nonStrikerPocketed: _srrAsNullableInt(json['non_striker_pocketed']),
    queenPocketedBy: srrQueenPocketedByFromString(
      _srrAsString(json['queen_pocketed_by']),
    ),
    pointsPlayer1: _srrAsInt(json['points_player1']),
    pointsPlayer2: _srrAsInt(json['points_player2']),
    winnerPlayerId: _srrAsNullableInt(json['winner_player_id']),
    isTiebreaker: _srrAsBool(json['is_tiebreaker']),
    isSuddenDeath: _srrAsBool(json['is_sudden_death']),
    notes: _srrAsString(json['notes']),
  );

  final int boardNumber;
  final int? strikerPlayerId;
  final SrrCarromColor? strikerColor;
  final int? strikerPocketed;
  final int? nonStrikerPocketed;
  final SrrQueenPocketedBy queenPocketedBy;
  final int pointsPlayer1;
  final int pointsPlayer2;
  final int? winnerPlayerId;
  final bool isTiebreaker;
  final bool isSuddenDeath;
  final String notes;
}

class SrrSuddenDeath {
  const SrrSuddenDeath({
    required this.winnerPlayerId,
    required this.player1Hits,
    required this.player2Hits,
    required this.attempts,
  });

  factory SrrSuddenDeath.fromJson(Map<String, dynamic> json) => SrrSuddenDeath(
    winnerPlayerId: _srrAsInt(json['winner_player_id']),
    player1Hits: _srrAsInt(json['player1_hits']),
    player2Hits: _srrAsInt(json['player2_hits']),
    attempts: _srrAsInt(json['attempts']),
  );

  final int winnerPlayerId;
  final int player1Hits;
  final int player2Hits;
  final int attempts;
}

class SrrPlayerLite {
  const SrrPlayerLite({
    required this.id,
    required this.handle,
    required this.displayName,
    this.state,
    this.country,
    this.emailId,
    this.registeredFlag,
    this.tshirtSize,
    this.feesPaidFlag,
    this.phoneNumber,
  });

  factory SrrPlayerLite.fromJson(Map<String, dynamic> json) => SrrPlayerLite(
    id: _srrAsInt(json['id']),
    handle: (() {
      final value = _srrAsString(json['handle']).trim();
      if (value.isNotEmpty) return value;
      final email = _srrAsString(json['email_id']).trim();
      if (email.isNotEmpty) return email;
      final displayName = _srrAsString(json['display_name']).trim();
      if (displayName.isNotEmpty) return displayName;
      return 'player_${_srrAsInt(json['id'])}';
    })(),
    displayName: (() {
      final value = _srrAsString(json['display_name']).trim();
      if (value.isNotEmpty) return value;
      final handle = _srrAsString(json['handle']).trim();
      if (handle.isNotEmpty) return handle;
      return 'Player ${_srrAsInt(json['id'])}';
    })(),
    state: (() {
      final value = _srrAsString(json['state']).trim();
      return value.isEmpty ? null : value;
    })(),
    country: (() {
      final value = _srrAsString(json['country']).trim();
      return value.isEmpty ? null : value;
    })(),
    emailId: (() {
      final value = _srrAsString(json['email_id']).trim();
      return value.isEmpty ? null : value;
    })(),
    registeredFlag: (() {
      final raw = json['registered_flag'];
      if (raw == null) return null;
      return _srrAsBool(raw);
    })(),
    tshirtSize: (() {
      final value = _srrAsString(json['t_shirt_size']).trim();
      return value.isEmpty ? null : value;
    })(),
    feesPaidFlag: (() {
      final raw = json['fees_paid_flag'];
      if (raw == null) return null;
      return _srrAsBool(raw);
    })(),
    phoneNumber: (() {
      final value = _srrAsString(json['phone_number']).trim();
      return value.isEmpty ? null : value;
    })(),
  );

  final int id;
  final String handle;
  final String displayName;
  final String? state;
  final String? country;
  final String? emailId;
  final bool? registeredFlag;
  final String? tshirtSize;
  final bool? feesPaidFlag;
  final String? phoneNumber;
}

class SrrMatch {
  const SrrMatch({
    required this.id,
    required this.tournamentId,
    required this.groupNumber,
    required this.roundNumber,
    required this.tableNumber,
    required this.player1,
    required this.player2,
    required this.status,
    required this.confirmedScore1,
    required this.confirmedScore2,
    required this.confirmations,
    required this.myConfirmation,
    required this.toss,
    required this.boards,
    required this.suddenDeath,
  });

  factory SrrMatch.fromJson(Map<String, dynamic> json) => SrrMatch(
    id: _srrAsInt(json['id']),
    tournamentId: _srrAsNullableInt(json['tournament_id']),
    groupNumber: _srrAsNullableInt(json['group_number']),
    roundNumber: _srrAsInt(json['round_number']),
    tableNumber: _srrAsInt(json['table_number']),
    player1: SrrPlayerLite.fromJson(
      _srrAsObjectMapOrNull(json['player1']) ?? const <String, dynamic>{},
    ),
    player2: SrrPlayerLite.fromJson(
      _srrAsObjectMapOrNull(json['player2']) ?? const <String, dynamic>{},
    ),
    status: srrMatchStatusFromString(_srrAsString(json['status'])),
    confirmedScore1: _srrAsNullableInt(json['confirmed_score1']),
    confirmedScore2: _srrAsNullableInt(json['confirmed_score2']),
    confirmations: _srrAsInt(json['confirmations']),
    myConfirmation: json['my_confirmation'] == null
        ? null
        : SrrScoreConfirmation.fromJson(
            _srrAsObjectMapOrNull(json['my_confirmation']) ??
                const <String, dynamic>{},
          ),
    toss: json['toss'] == null
        ? null
        : SrrTossState.fromJson(
            _srrAsObjectMapOrNull(json['toss']) ?? const <String, dynamic>{},
          ),
    boards: _srrAsObjectMapList(
      json['boards'],
    ).map(SrrCarromBoard.fromJson).toList(growable: false),
    suddenDeath: json['sudden_death'] == null
        ? null
        : SrrSuddenDeath.fromJson(
            _srrAsObjectMapOrNull(json['sudden_death']) ??
                const <String, dynamic>{},
          ),
  );

  final int id;
  final int? tournamentId;
  final int? groupNumber;
  final int roundNumber;
  final int tableNumber;
  final SrrPlayerLite player1;
  final SrrPlayerLite player2;
  final SrrMatchStatus status;
  final int? confirmedScore1;
  final int? confirmedScore2;
  final int confirmations;
  final SrrScoreConfirmation? myConfirmation;
  final SrrTossState? toss;
  final List<SrrCarromBoard> boards;
  final SrrSuddenDeath? suddenDeath;

  bool get isConfirmed => status == SrrMatchStatus.confirmed;

  String get statusLabel {
    switch (status) {
      case SrrMatchStatus.confirmed:
        return 'Confirmed';
      case SrrMatchStatus.disputed:
        return 'Disputed';
      case SrrMatchStatus.pending:
        return 'Pending';
    }
  }

  bool canBeConfirmedBy(int userId) =>
      !isConfirmed && (player1.id == userId || player2.id == userId);
}

class SrrRound {
  const SrrRound({
    required this.roundNumber,
    required this.isComplete,
    required this.matches,
  });

  factory SrrRound.fromJson(Map<String, dynamic> json) => SrrRound(
    roundNumber: _srrAsInt(json['round_number']),
    isComplete: _srrAsBool(json['is_complete']),
    matches: _srrAsObjectMapList(
      json['matches'],
    ).map(SrrMatch.fromJson).toList(growable: false),
  );

  final int roundNumber;
  final bool isComplete;
  final List<SrrMatch> matches;
}

class SrrStandingRow {
  const SrrStandingRow({
    required this.position,
    required this.playerId,
    required this.handle,
    required this.displayName,
    required this.played,
    required this.wins,
    required this.draws,
    required this.losses,
    required this.goalsFor,
    required this.goalsAgainst,
    required this.goalDifference,
    required this.sumRoundPoints,
    required this.sumOpponentRoundPoints,
    required this.netGamePointsDifference,
    required this.roundPoints,
    required this.points,
  });

  factory SrrStandingRow.fromJson(Map<String, dynamic> json) {
    final goalsFor = _srrAsInt(json['goals_for']);
    final goalsAgainst = _srrAsInt(json['goals_against']);
    final goalDifference = _srrAsInt(json['goal_difference']);
    return SrrStandingRow(
      position: _srrAsInt(json['position']),
      playerId: _srrAsInt(json['player_id']),
      handle: _srrAsString(json['handle']),
      displayName: (() {
        final displayName = _srrAsString(json['display_name']).trim();
        if (displayName.isNotEmpty) return displayName;
        final handle = _srrAsString(json['handle']).trim();
        if (handle.isNotEmpty) return handle;
        return 'Player ${_srrAsInt(json['player_id'])}';
      })(),
      played: _srrAsInt(json['played']),
      wins: _srrAsInt(json['wins']),
      draws: _srrAsInt(json['draws']),
      losses: _srrAsInt(json['losses']),
      goalsFor: goalsFor,
      goalsAgainst: goalsAgainst,
      goalDifference: goalDifference,
      sumRoundPoints: _srrAsInt(json['sum_round_points'], fallback: goalsFor),
      sumOpponentRoundPoints: _srrAsInt(
        json['sum_opponent_round_points'],
        fallback: goalsAgainst,
      ),
      netGamePointsDifference: _srrAsInt(
        json['net_game_points_difference'],
        fallback: goalDifference,
      ),
      roundPoints: _srrAsInt(json['round_points']),
      points: _srrAsInt(json['points']),
    );
  }

  final int position;
  final int playerId;
  final String handle;
  final String displayName;
  final int played;
  final int wins;
  final int draws;
  final int losses;
  final int goalsFor;
  final int goalsAgainst;
  final int goalDifference;
  final int sumRoundPoints;
  final int sumOpponentRoundPoints;
  final int netGamePointsDifference;
  final int roundPoints;
  final int points;
}

class SrrPlayerRoundPoints {
  const SrrPlayerRoundPoints({
    required this.playerId,
    required this.displayName,
    required this.points,
  });

  factory SrrPlayerRoundPoints.fromJson(Map<String, dynamic> json) =>
      SrrPlayerRoundPoints(
        playerId: _srrAsInt(json['player_id']),
        displayName: (() {
          final value = _srrAsString(json['display_name']).trim();
          if (value.isNotEmpty) return value;
          return 'Player ${_srrAsInt(json['player_id'])}';
        })(),
        points: _srrAsInt(json['points']),
      );

  final int playerId;
  final String displayName;
  final int points;
}

class SrrRoundPoints {
  const SrrRoundPoints({required this.roundNumber, required this.points});

  factory SrrRoundPoints.fromJson(Map<String, dynamic> json) => SrrRoundPoints(
    roundNumber: _srrAsInt(json['round_number']),
    points: _srrAsObjectMapList(
      json['points'],
    ).map(SrrPlayerRoundPoints.fromJson).toList(growable: false),
  );

  final int roundNumber;
  final List<SrrPlayerRoundPoints> points;
}

class SrrRoundStandings {
  const SrrRoundStandings({
    required this.roundNumber,
    required this.isComplete,
    required this.standings,
  });

  factory SrrRoundStandings.fromJson(Map<String, dynamic> json) =>
      SrrRoundStandings(
        roundNumber: _srrAsInt(json['round_number']),
        isComplete: _srrAsBool(json['is_complete']),
        standings: _srrAsObjectMapList(
          json['standings'],
        ).map(SrrStandingRow.fromJson).toList(growable: false),
      );

  final int roundNumber;
  final bool isComplete;
  final List<SrrStandingRow> standings;
}

class SrrLiveSnapshot {
  const SrrLiveSnapshot({
    required this.generatedAt,
    required this.currentRound,
    required this.rounds,
    required this.standings,
  });

  factory SrrLiveSnapshot.fromJson(Map<String, dynamic> json) =>
      SrrLiveSnapshot(
        generatedAt:
            DateTime.tryParse(_srrAsString(json['generated_at'])) ??
            DateTime.fromMillisecondsSinceEpoch(0),
        currentRound: _srrAsNullableInt(json['current_round']),
        rounds: _srrAsObjectMapList(
          json['rounds'],
        ).map(SrrRound.fromJson).toList(growable: false),
        standings: _srrAsObjectMapList(
          json['standings'],
        ).map(SrrStandingRow.fromJson).toList(growable: false),
      );

  final DateTime generatedAt;
  final int? currentRound;
  final List<SrrRound> rounds;
  final List<SrrStandingRow> standings;
}
