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

class SrrScoreConfirmation {
  const SrrScoreConfirmation({required this.score1, required this.score2});

  factory SrrScoreConfirmation.fromJson(Map<String, dynamic> json) =>
      SrrScoreConfirmation(
        score1: json['score1'] as int,
        score2: json['score2'] as int,
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
    tossWinnerPlayerId: json['toss_winner_player_id'] as int?,
    tossDecision: srrTossDecisionFromString(json['toss_decision'] as String?),
    firstStrikerPlayerId: json['first_striker_player_id'] as int?,
    firstStrikerColor: srrCarromColorFromString(
      json['first_striker_color'] as String?,
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
    boardNumber: json['board_number'] as int,
    strikerPlayerId: json['striker_player_id'] as int?,
    strikerColor: srrCarromColorFromString(json['striker_color'] as String?),
    strikerPocketed: json['striker_pocketed'] as int?,
    nonStrikerPocketed: json['non_striker_pocketed'] as int?,
    queenPocketedBy: srrQueenPocketedByFromString(
      json['queen_pocketed_by'] as String?,
    ),
    pointsPlayer1: json['points_player1'] as int,
    pointsPlayer2: json['points_player2'] as int,
    winnerPlayerId: json['winner_player_id'] as int?,
    isTiebreaker: json['is_tiebreaker'] as bool? ?? false,
    isSuddenDeath: json['is_sudden_death'] as bool? ?? false,
    notes: json['notes'] as String? ?? '',
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
    winnerPlayerId: json['winner_player_id'] as int,
    player1Hits: json['player1_hits'] as int,
    player2Hits: json['player2_hits'] as int,
    attempts: json['attempts'] as int,
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
    id: json['id'] as int,
    handle: json['handle'] as String,
    displayName: json['display_name'] as String,
    state: json['state'] as String?,
    country: json['country'] as String?,
    emailId: json['email_id'] as String?,
    registeredFlag: json['registered_flag'] as bool?,
    tshirtSize: json['t_shirt_size'] as String?,
    feesPaidFlag: json['fees_paid_flag'] as bool?,
    phoneNumber: json['phone_number'] as String?,
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
    id: json['id'] as int,
    groupNumber: (json['group_number'] as num?)?.toInt(),
    roundNumber: json['round_number'] as int,
    tableNumber: json['table_number'] as int,
    player1: SrrPlayerLite.fromJson(json['player1'] as Map<String, dynamic>),
    player2: SrrPlayerLite.fromJson(json['player2'] as Map<String, dynamic>),
    status: srrMatchStatusFromString(json['status'] as String),
    confirmedScore1: json['confirmed_score1'] as int?,
    confirmedScore2: json['confirmed_score2'] as int?,
    confirmations: json['confirmations'] as int,
    myConfirmation: json['my_confirmation'] == null
        ? null
        : SrrScoreConfirmation.fromJson(
            json['my_confirmation'] as Map<String, dynamic>,
          ),
    toss: json['toss'] == null
        ? null
        : SrrTossState.fromJson(json['toss'] as Map<String, dynamic>),
    boards: (json['boards'] as List<dynamic>? ?? const <dynamic>[])
        .cast<Map<String, dynamic>>()
        .map(SrrCarromBoard.fromJson)
        .toList(growable: false),
    suddenDeath: json['sudden_death'] == null
        ? null
        : SrrSuddenDeath.fromJson(json['sudden_death'] as Map<String, dynamic>),
  );

  final int id;
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
    roundNumber: json['round_number'] as int,
    isComplete: json['is_complete'] as bool,
    matches: (json['matches'] as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map(SrrMatch.fromJson)
        .toList(growable: false),
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
    final goalsFor = json['goals_for'] as int? ?? 0;
    final goalsAgainst = json['goals_against'] as int? ?? 0;
    final goalDifference = json['goal_difference'] as int? ?? 0;
    return SrrStandingRow(
      position: json['position'] as int,
      playerId: json['player_id'] as int,
      handle: json['handle'] as String,
      displayName: json['display_name'] as String,
      played: json['played'] as int,
      wins: json['wins'] as int,
      draws: json['draws'] as int,
      losses: json['losses'] as int,
      goalsFor: goalsFor,
      goalsAgainst: goalsAgainst,
      goalDifference: goalDifference,
      sumRoundPoints: (json['sum_round_points'] as int?) ?? goalsFor,
      sumOpponentRoundPoints:
          (json['sum_opponent_round_points'] as int?) ?? goalsAgainst,
      netGamePointsDifference:
          (json['net_game_points_difference'] as int?) ?? goalDifference,
      roundPoints: json['round_points'] as int,
      points: json['points'] as int,
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
        playerId: json['player_id'] as int,
        displayName: json['display_name'] as String,
        points: json['points'] as int,
      );

  final int playerId;
  final String displayName;
  final int points;
}

class SrrRoundPoints {
  const SrrRoundPoints({required this.roundNumber, required this.points});

  factory SrrRoundPoints.fromJson(Map<String, dynamic> json) => SrrRoundPoints(
    roundNumber: json['round_number'] as int,
    points: (json['points'] as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map(SrrPlayerRoundPoints.fromJson)
        .toList(growable: false),
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
        roundNumber: json['round_number'] as int,
        isComplete: json['is_complete'] as bool,
        standings: (json['standings'] as List<dynamic>)
            .cast<Map<String, dynamic>>()
            .map(SrrStandingRow.fromJson)
            .toList(growable: false),
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
        generatedAt: DateTime.parse(json['generated_at'] as String),
        currentRound: json['current_round'] as int?,
        rounds: (json['rounds'] as List<dynamic>)
            .cast<Map<String, dynamic>>()
            .map(SrrRound.fromJson)
            .toList(growable: false),
        standings: (json['standings'] as List<dynamic>)
            .cast<Map<String, dynamic>>()
            .map(SrrStandingRow.fromJson)
            .toList(growable: false),
      );

  final DateTime generatedAt;
  final int? currentRound;
  final List<SrrRound> rounds;
  final List<SrrStandingRow> standings;
}
