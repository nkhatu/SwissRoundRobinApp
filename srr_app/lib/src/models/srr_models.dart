// ---------------------------------------------------------------------------
// srr_app/lib/src/models/srr_models.dart
// ---------------------------------------------------------------------------
// 
// Purpose:
// - Declares SRR domain/data models and JSON serialization mappings.
// Architecture:
// - Model layer defining contracts shared across API, repositories, and UI.
// - Encapsulates parsing and transport-shape conversion in one place.
// Author: Neil Khatu
// Copyright (c) The Khatu Family Trust
// 
import 'dart:convert';

enum SrrMatchStatus { pending, disputed, confirmed }

enum SrrTossDecision { strikeFirst, chooseSide }

enum SrrCarromColor { white, black }

enum SrrQueenPocketedBy { none, striker, nonStriker }

SrrMatchStatus _statusFromString(String value) {
  switch (value) {
    case 'confirmed':
      return SrrMatchStatus.confirmed;
    case 'disputed':
      return SrrMatchStatus.disputed;
    case 'pending':
    default:
      return SrrMatchStatus.pending;
  }
}

SrrTossDecision? _tossDecisionFromString(String? value) {
  switch (value) {
    case 'strike_first':
      return SrrTossDecision.strikeFirst;
    case 'choose_side':
      return SrrTossDecision.chooseSide;
    default:
      return null;
  }
}

SrrCarromColor? _carromColorFromString(String? value) {
  switch (value) {
    case 'white':
      return SrrCarromColor.white;
    case 'black':
      return SrrCarromColor.black;
    default:
      return null;
  }
}

SrrQueenPocketedBy _queenPocketedByFromString(String? value) {
  switch (value) {
    case 'striker':
      return SrrQueenPocketedBy.striker;
    case 'non_striker':
      return SrrQueenPocketedBy.nonStriker;
    case 'none':
    default:
      return SrrQueenPocketedBy.none;
  }
}

class SrrUser {
  const SrrUser({
    required this.id,
    required this.email,
    required this.handle,
    required this.displayName,
    required this.firstName,
    required this.lastName,
    required this.profileComplete,
    required this.role,
  });

  factory SrrUser.fromJson(Map<String, dynamic> json) => SrrUser(
    id: json['id'] as int,
    email: (json['email'] as String?) ?? (json['handle'] as String),
    handle: json['handle'] as String,
    displayName: json['display_name'] as String,
    firstName: json['first_name'] as String?,
    lastName: json['last_name'] as String?,
    profileComplete: json['profile_complete'] as bool? ?? false,
    role: json['role'] as String,
  );

  final int id;
  final String email;
  final String handle;
  final String displayName;
  final String? firstName;
  final String? lastName;
  final bool profileComplete;
  final String role;

  bool get isPlayer => role == 'player';
  bool get isViewer => role == 'viewer';
  bool get isAdmin => role == 'admin';
}

class SrrActiveTournamentStatus {
  const SrrActiveTournamentStatus({
    required this.hasActiveTournament,
    required this.tournament,
  });

  factory SrrActiveTournamentStatus.fromJson(Map<String, dynamic> json) {
    final tournamentJson = json['tournament'];
    return SrrActiveTournamentStatus(
      hasActiveTournament: json['has_active_tournament'] as bool? ?? false,
      tournament: tournamentJson is Map<String, dynamic>
          ? SrrTournamentRecord.fromJson(tournamentJson)
          : null,
    );
  }

  final bool hasActiveTournament;
  final SrrTournamentRecord? tournament;
}

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
    tossDecision: _tossDecisionFromString(json['toss_decision'] as String?),
    firstStrikerPlayerId: json['first_striker_player_id'] as int?,
    firstStrikerColor: _carromColorFromString(
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
    strikerColor: _carromColorFromString(json['striker_color'] as String?),
    strikerPocketed: json['striker_pocketed'] as int?,
    nonStrikerPocketed: json['non_striker_pocketed'] as int?,
    queenPocketedBy: _queenPocketedByFromString(
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
    roundNumber: json['round_number'] as int,
    tableNumber: json['table_number'] as int,
    player1: SrrPlayerLite.fromJson(json['player1'] as Map<String, dynamic>),
    player2: SrrPlayerLite.fromJson(json['player2'] as Map<String, dynamic>),
    status: _statusFromString(json['status'] as String),
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

class SrrTournamentSetupPlayerInput {
  const SrrTournamentSetupPlayerInput({
    required this.displayName,
    this.state,
    this.country,
    this.emailId,
    this.registeredFlag,
    this.tshirtSize,
    this.feesPaidFlag,
    this.phoneNumber,
  });

  final String displayName;
  final String? state;
  final String? country;
  final String? emailId;
  final bool? registeredFlag;
  final String? tshirtSize;
  final bool? feesPaidFlag;
  final String? phoneNumber;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'display_name': displayName,
    if (state != null && state!.trim().isNotEmpty) 'state': state!.trim(),
    if (country != null && country!.trim().isNotEmpty)
      'country': country!.trim(),
    if (emailId != null && emailId!.trim().isNotEmpty)
      'email_id': emailId!.trim(),
    if (registeredFlag != null) 'registered_flag': registeredFlag,
    if (tshirtSize != null && tshirtSize!.trim().isNotEmpty)
      't_shirt_size': tshirtSize!.trim(),
    if (feesPaidFlag != null) 'fees_paid_flag': feesPaidFlag,
    if (phoneNumber != null && phoneNumber!.trim().isNotEmpty)
      'phone_number': phoneNumber!.trim(),
  };
}

class SrrTournamentSetupCredential {
  const SrrTournamentSetupCredential({
    required this.playerId,
    required this.displayName,
    required this.handle,
    required this.password,
  });

  factory SrrTournamentSetupCredential.fromJson(Map<String, dynamic> json) =>
      SrrTournamentSetupCredential(
        playerId: json['player_id'] as int,
        displayName: json['display_name'] as String,
        handle: json['handle'] as String,
        password: json['password'] as String,
      );

  final int playerId;
  final String displayName;
  final String handle;
  final String password;
}

class SrrPersonName {
  const SrrPersonName({required this.firstName, required this.lastName});

  factory SrrPersonName.fromJson(Map<String, dynamic> json) => SrrPersonName(
    firstName: json['first_name'] as String,
    lastName: json['last_name'] as String,
  );

  final String firstName;
  final String lastName;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'first_name': firstName,
    'last_name': lastName,
  };
}

class SrrTournamentMetadata {
  const SrrTournamentMetadata({
    required this.type,
    required this.subType,
    required this.strength,
    required this.startDateTime,
    required this.endDateTime,
    required this.srrRounds,
    required this.singlesMaxParticipants,
    required this.doublesMaxTeams,
    required this.numberOfTables,
    required this.roundTimeLimitMinutes,
    required this.venueName,
    required this.directorName,
    required this.referees,
    required this.chiefReferee,
    required this.category,
    required this.subCategory,
  });

  factory SrrTournamentMetadata.fromJson(Map<String, dynamic> json) {
    final typeValues = const {'national', 'open', 'regional', 'club'};
    String normalizeType(String value) =>
        value == 'reginaol' ? 'regional' : value;
    final type = [json['type'], json['flag']]
        .map(
          (entry) =>
              normalizeType(entry?.toString().trim().toLowerCase() ?? ''),
        )
        .firstWhere(typeValues.contains, orElse: () => 'open');
    final subTypeCandidate = (json['sub_type'] ?? json['subType'] ?? '')
        .toString()
        .trim()
        .toLowerCase();
    final legacySubTypeCandidate = (json['type'] ?? '')
        .toString()
        .trim()
        .toLowerCase();
    final subType = const {'singles', 'doubles'}.contains(subTypeCandidate)
        ? subTypeCandidate
        : (const {'singles', 'doubles'}.contains(legacySubTypeCandidate)
              ? legacySubTypeCandidate
              : 'singles');
    final now = DateTime.now();
    final startDateTime =
        DateTime.tryParse(
          (json['start_date_time'] ??
                  json['tournament_start_date_time'] ??
                  json['startDateTime'] ??
                  '')
              .toString(),
        ) ??
        now;
    final endDateTime =
        DateTime.tryParse(
          (json['end_date_time'] ??
                  json['tournament_end_date_time'] ??
                  json['endDateTime'] ??
                  '')
              .toString(),
        ) ??
        startDateTime.add(const Duration(hours: 2));
    final srrRoundsRaw =
        json['srr_rounds'] ??
        json['tournament_srr_rounds'] ??
        json['number_of_srr_rounds'] ??
        json['srrRounds'];
    final parsedSrrRounds = switch (srrRoundsRaw) {
      int value => value,
      num value => value.toInt(),
      String value => int.tryParse(value.trim()) ?? 7,
      _ => 7,
    };
    return SrrTournamentMetadata(
      type: type,
      subType: subType,
      strength: (json['strength'] as num).toDouble(),
      startDateTime: startDateTime,
      endDateTime: endDateTime,
      srrRounds: parsedSrrRounds < 1 ? 7 : parsedSrrRounds,
      singlesMaxParticipants: json['singles_max_participants'] as int,
      doublesMaxTeams: json['doubles_max_teams'] as int,
      numberOfTables: json['number_of_tables'] as int,
      roundTimeLimitMinutes: json['round_time_limit_minutes'] as int,
      venueName: json['venue_name'] as String,
      directorName: json['director_name'] as String,
      referees: (json['referees'] as List<dynamic>)
          .cast<Map<String, dynamic>>()
          .map(SrrPersonName.fromJson)
          .toList(growable: false),
      chiefReferee: SrrPersonName.fromJson(
        json['chief_referee'] as Map<String, dynamic>,
      ),
      category: json['category'] as String,
      subCategory: json['sub_category'] as String,
    );
  }

  final String type;
  final String subType;
  final double strength;
  final DateTime startDateTime;
  final DateTime endDateTime;
  final int srrRounds;
  final int singlesMaxParticipants;
  final int doublesMaxTeams;
  final int numberOfTables;
  final int roundTimeLimitMinutes;
  final String venueName;
  final String directorName;
  final List<SrrPersonName> referees;
  final SrrPersonName chiefReferee;
  final String category;
  final String subCategory;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'tournament_type': type,
    'tournament_sub_type': subType,
    'tournament_strength': strength,
    'tournament_start_date_time': startDateTime.toUtc().toIso8601String(),
    'tournament_end_date_time': endDateTime.toUtc().toIso8601String(),
    'tournament_srr_rounds': srrRounds,
    'tournament_limits_singles_max_participants': singlesMaxParticipants,
    'tournament_limits_doubles_max_teams': doublesMaxTeams,
    'tournament_number_of_tables': numberOfTables,
    'tournament_round_time_limit_minutes': roundTimeLimitMinutes,
    'tournament_venue_name': venueName,
    'tournament_director_name': directorName,
    'tournament_referees': referees.map((entry) => entry.toJson()).toList(),
    'tournament_chief_referee': chiefReferee.toJson(),
    'tournament_category': category,
    'tournament_sub_category': subCategory,
  };
}

class SrrTournamentWorkflowStep {
  const SrrTournamentWorkflowStep({
    required this.key,
    required this.status,
    required this.completedAt,
  });

  factory SrrTournamentWorkflowStep.fromJson(Map<String, dynamic> json) {
    final rawStatus = (json['status'] as String? ?? 'pending')
        .trim()
        .toLowerCase();
    final status = rawStatus == 'completed' ? 'completed' : 'pending';
    final completedAtRaw = json['completed_at'] as String?;
    return SrrTournamentWorkflowStep(
      key: (json['key'] as String? ?? '').trim(),
      status: status,
      completedAt: completedAtRaw == null
          ? null
          : DateTime.tryParse(completedAtRaw),
    );
  }

  final String key;
  final String status;
  final DateTime? completedAt;

  bool get isCompleted => status == 'completed';
}

class SrrTournamentWorkflow {
  const SrrTournamentWorkflow({required this.steps, required this.updatedAt});

  static const orderedStepKeys = <String>[
    'create_tournament',
    'load_registered_players',
    'load_current_national_ranking',
    'create_tournament_seeding',
    'create_tournament_groups',
    'generate_matchups_next_round',
    'create_final_srr_standings',
    'generate_knockout_brackets',
    'generate_final_tournament_standings',
    'announce_winners',
  ];

  factory SrrTournamentWorkflow.fromJson(Map<String, dynamic> json) {
    final rawSteps = (json['steps'] as List<dynamic>? ?? const <dynamic>[])
        .whereType<Map<String, dynamic>>()
        .map(SrrTournamentWorkflowStep.fromJson)
        .toList(growable: false);
    final stepsByKey = <String, SrrTournamentWorkflowStep>{
      for (final step in rawSteps)
        if (step.key.isNotEmpty) step.key: step,
    };
    final normalizedSteps = orderedStepKeys
        .map(
          (key) =>
              stepsByKey[key] ??
              SrrTournamentWorkflowStep(
                key: key,
                status: 'pending',
                completedAt: null,
              ),
        )
        .toList(growable: false);
    final updatedAtRaw = json['updated_at'] as String?;
    return SrrTournamentWorkflow(
      steps: normalizedSteps,
      updatedAt:
          DateTime.tryParse(updatedAtRaw ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  factory SrrTournamentWorkflow.fallback() => SrrTournamentWorkflow(
    steps: orderedStepKeys
        .map(
          (key) => SrrTournamentWorkflowStep(
            key: key,
            status: key == 'create_tournament' ? 'completed' : 'pending',
            completedAt: null,
          ),
        )
        .toList(growable: false),
    updatedAt: DateTime.fromMillisecondsSinceEpoch(0),
  );

  final List<SrrTournamentWorkflowStep> steps;
  final DateTime updatedAt;

  SrrTournamentWorkflowStep stepByKey(String key) {
    for (final step in steps) {
      if (step.key == key) return step;
    }
    return SrrTournamentWorkflowStep(
      key: key,
      status: 'pending',
      completedAt: null,
    );
  }
}

class SrrTournamentRecord {
  const SrrTournamentRecord({
    required this.id,
    required this.name,
    required this.status,
    required this.type,
    required this.createdAt,
    required this.updatedAt,
    required this.category,
    required this.subCategory,
    required this.selectedRankingYear,
    required this.selectedRankingDescription,
    required this.metadata,
    required this.workflow,
  });

  factory SrrTournamentRecord.fromJson(Map<String, dynamic> json) {
    final metadataJson = json['metadata'] as Map<String, dynamic>?;
    final metadata = metadataJson == null
        ? null
        : SrrTournamentMetadata.fromJson(metadataJson);
    final createdAtRaw = json['created_at'] as String? ?? '';
    final updatedAtRaw = json['updated_at'] as String? ?? '';
    return SrrTournamentRecord(
      id: json['id'] as int,
      name: json['name'] as String,
      status: json['status'] as String,
      type:
          (json['type'] as String?)?.trim().toLowerCase() ??
          metadata?.type ??
          '',
      createdAt:
          DateTime.tryParse(createdAtRaw) ??
          DateTime.fromMillisecondsSinceEpoch(0),
      updatedAt:
          DateTime.tryParse(updatedAtRaw) ??
          DateTime.fromMillisecondsSinceEpoch(0),
      category: (json['category'] as String?) ?? metadata?.category ?? '',
      subCategory:
          (json['sub_category'] as String?) ?? metadata?.subCategory ?? '',
      selectedRankingYear: (json['selected_ranking_year'] as num?)?.toInt(),
      selectedRankingDescription: (() {
        final value = (json['selected_ranking_description'] as String? ?? '')
            .trim();
        return value.isEmpty ? null : value;
      })(),
      metadata: metadata,
      workflow: json['workflow'] == null
          ? SrrTournamentWorkflow.fallback()
          : SrrTournamentWorkflow.fromJson(
              json['workflow'] as Map<String, dynamic>,
            ),
    );
  }

  final int id;
  final String name;
  final String status;
  final String type;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String category;
  final String subCategory;
  final int? selectedRankingYear;
  final String? selectedRankingDescription;
  final SrrTournamentMetadata? metadata;
  final SrrTournamentWorkflow workflow;
}

class SrrNationalRankingOption {
  const SrrNationalRankingOption({
    required this.rankingYear,
    required this.rankingDescription,
  });

  factory SrrNationalRankingOption.fromJson(Map<String, dynamic> json) {
    final yearRaw = json['ranking_year'] ?? json['rankingYear'] ?? json['year'];
    final parsedYear = switch (yearRaw) {
      int value => value,
      num value => value.toInt(),
      String value => int.tryParse(value.trim()) ?? DateTime.now().year,
      _ => DateTime.now().year,
    };
    final description =
        (json['ranking_description'] ??
                json['rankingDescription'] ??
                json['description'] ??
                '')
            .toString()
            .trim();
    return SrrNationalRankingOption(
      rankingYear: parsedYear < 1 ? DateTime.now().year : parsedYear,
      rankingDescription: description.isEmpty ? 'Default' : description,
    );
  }

  final int rankingYear;
  final String rankingDescription;

  String get key => '$rankingYear::$rankingDescription';
  String get label => '$rankingYear - $rankingDescription';
}

class SrrNationalRankingRecord {
  const SrrNationalRankingRecord({
    required this.rank,
    required this.playerName,
    required this.state,
    required this.country,
    required this.emailId,
    required this.rankingPoints,
    required this.rankingYear,
    required this.rankingDescription,
    required this.lastUpdated,
  });

  factory SrrNationalRankingRecord.fromJson(Map<String, dynamic> json) {
    final rankRaw =
        json['rank'] ?? json['ranking_position'] ?? json['position'];
    final parsedRank = switch (rankRaw) {
      int value => value,
      num value => value.toInt(),
      String value => int.tryParse(value.trim()) ?? 0,
      _ => 0,
    };
    final yearRaw = json['ranking_year'] ?? json['rankingYear'] ?? json['year'];
    final parsedYear = switch (yearRaw) {
      int value => value,
      num value => value.toInt(),
      String value => int.tryParse(value.trim()) ?? DateTime.now().year,
      _ => DateTime.now().year,
    };
    final pointsRaw = json['ranking_points'] ?? json['rankingPoints'];
    final points = switch (pointsRaw) {
      null => null,
      num value => value.toDouble(),
      String value => double.tryParse(value.trim()),
      _ => null,
    };
    final description =
        (json['ranking_description'] ??
                json['rankingDescription'] ??
                json['description'] ??
                '')
            .toString()
            .trim();
    final lastUpdatedRaw = (json['last_updated'] ?? json['lastUpdated'] ?? '')
        .toString()
        .trim();

    return SrrNationalRankingRecord(
      rank: parsedRank < 1 ? 0 : parsedRank,
      playerName:
          (json['player_name'] ?? json['playerName'] ?? json['name'] ?? '')
              .toString()
              .trim(),
      state: (json['state'] ?? '').toString().trim(),
      country: (json['country'] ?? '').toString().trim(),
      emailId: (json['email_id'] ?? json['emailId'] ?? '').toString().trim(),
      rankingPoints: points,
      rankingYear: parsedYear < 1 ? DateTime.now().year : parsedYear,
      rankingDescription: description.isEmpty ? 'Default' : description,
      lastUpdated: lastUpdatedRaw,
    );
  }

  final int rank;
  final String playerName;
  final String state;
  final String country;
  final String emailId;
  final double? rankingPoints;
  final int rankingYear;
  final String rankingDescription;
  final String lastUpdated;
}

class SrrNationalRankingInput {
  const SrrNationalRankingInput({
    required this.rank,
    required this.playerName,
    required this.rankingDescription,
    required this.state,
    required this.country,
    required this.emailId,
    required this.rankingPoints,
    required this.rankingYear,
    required this.lastUpdated,
  });

  final int rank;
  final String playerName;
  final String rankingDescription;
  final String? state;
  final String? country;
  final String? emailId;
  final double? rankingPoints;
  final int rankingYear;
  final String? lastUpdated;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'rank': rank,
      'player_name': playerName,
      'ranking_description': rankingDescription,
      'state': state,
      'country': country,
      'email_id': emailId,
      'ranking_points': rankingPoints,
      'ranking_year': rankingYear,
      'last_updated': lastUpdated,
    };
  }
}

class SrrNationalRankingUploadResult {
  const SrrNationalRankingUploadResult({
    required this.uploadedRows,
    required this.years,
    required this.rankings,
  });

  factory SrrNationalRankingUploadResult.fromJson(Map<String, dynamic> json) {
    return SrrNationalRankingUploadResult(
      uploadedRows: json['uploaded_rows'] as int? ?? 0,
      years:
          (json['years'] as List<dynamic>? ?? const <dynamic>[])
              .map((entry) => entry is num ? entry.toInt() : null)
              .whereType<int>()
              .toList(growable: false)
            ..sort((a, b) => b - a),
      rankings: (json['rankings'] as List<dynamic>? ?? const <dynamic>[])
          .whereType<Map<String, dynamic>>()
          .map(SrrNationalRankingOption.fromJson)
          .toList(growable: false),
    );
  }

  final int uploadedRows;
  final List<int> years;
  final List<SrrNationalRankingOption> rankings;
}

class SrrNationalRankingDeleteResult {
  const SrrNationalRankingDeleteResult({
    required this.deletedRows,
    required this.rankingYear,
    required this.rankingDescription,
    required this.rankings,
  });

  factory SrrNationalRankingDeleteResult.fromJson(Map<String, dynamic> json) {
    final rankingYearRaw =
        json['ranking_year'] ?? json['rankingYear'] ?? json['year'];
    final parsedYear = switch (rankingYearRaw) {
      int value => value,
      num value => value.toInt(),
      String value => int.tryParse(value.trim()) ?? DateTime.now().year,
      _ => DateTime.now().year,
    };
    final description =
        (json['ranking_description'] ??
                json['rankingDescription'] ??
                json['description'] ??
                '')
            .toString()
            .trim();
    return SrrNationalRankingDeleteResult(
      deletedRows: json['deleted_rows'] as int? ?? 0,
      rankingYear: parsedYear < 1 ? DateTime.now().year : parsedYear,
      rankingDescription: description.isEmpty ? 'Default' : description,
      rankings: (json['rankings'] as List<dynamic>? ?? const <dynamic>[])
          .whereType<Map<String, dynamic>>()
          .map(SrrNationalRankingOption.fromJson)
          .toList(growable: false),
    );
  }

  final int deletedRows;
  final int rankingYear;
  final String rankingDescription;
  final List<SrrNationalRankingOption> rankings;
}

class SrrTournamentPlayersUploadResult {
  const SrrTournamentPlayersUploadResult({
    required this.tournament,
    required this.playersUploaded,
    required this.players,
  });

  factory SrrTournamentPlayersUploadResult.fromJson(Map<String, dynamic> json) {
    return SrrTournamentPlayersUploadResult(
      tournament: SrrTournamentRecord.fromJson(
        json['tournament'] as Map<String, dynamic>,
      ),
      playersUploaded: json['players_uploaded'] as int,
      players: (json['players'] as List<dynamic>? ?? const <dynamic>[])
          .cast<Map<String, dynamic>>()
          .map(SrrPlayerLite.fromJson)
          .toList(growable: false),
    );
  }

  final SrrTournamentRecord tournament;
  final int playersUploaded;
  final List<SrrPlayerLite> players;
}

class SrrTournamentPlayersDeleteResult {
  const SrrTournamentPlayersDeleteResult({
    required this.tournament,
    required this.playersDeleted,
    required this.players,
  });

  factory SrrTournamentPlayersDeleteResult.fromJson(Map<String, dynamic> json) {
    return SrrTournamentPlayersDeleteResult(
      tournament: SrrTournamentRecord.fromJson(
        json['tournament'] as Map<String, dynamic>,
      ),
      playersDeleted: json['players_deleted'] as int? ?? 0,
      players: (json['players'] as List<dynamic>? ?? const <dynamic>[])
          .cast<Map<String, dynamic>>()
          .map(SrrPlayerLite.fromJson)
          .toList(growable: false),
    );
  }

  final SrrTournamentRecord tournament;
  final int playersDeleted;
  final List<SrrPlayerLite> players;
}

class SrrTournamentSeedingRow {
  const SrrTournamentSeedingRow({
    required this.seed,
    required this.playerId,
    required this.displayName,
    required this.handle,
    required this.state,
    required this.country,
    required this.emailId,
    required this.sourceType,
    required this.matchedBy,
    required this.rankingRank,
    required this.rankingYear,
    required this.rankingDescription,
    required this.isManual,
    required this.updatedAt,
  });

  factory SrrTournamentSeedingRow.fromJson(Map<String, dynamic> json) {
    final seedRaw = json['seed'];
    final seed = switch (seedRaw) {
      int value => value,
      num value => value.toInt(),
      String value => int.tryParse(value.trim()) ?? 0,
      _ => 0,
    };
    final playerIdRaw = json['player_id'] ?? json['playerId'];
    final playerId = switch (playerIdRaw) {
      int value => value,
      num value => value.toInt(),
      String value => int.tryParse(value.trim()) ?? 0,
      _ => 0,
    };
    final rankingRankRaw = json['ranking_rank'] ?? json['rankingRank'];
    final rankingRank = switch (rankingRankRaw) {
      null => null,
      int value => value,
      num value => value.toInt(),
      String value => int.tryParse(value.trim()),
      _ => null,
    };
    final rankingYearRaw = json['ranking_year'] ?? json['rankingYear'];
    final rankingYear = switch (rankingYearRaw) {
      null => null,
      int value => value,
      num value => value.toInt(),
      String value => int.tryParse(value.trim()),
      _ => null,
    };
    final updatedAtRaw = (json['updated_at'] ?? json['updatedAt'] ?? '')
        .toString()
        .trim();
    return SrrTournamentSeedingRow(
      seed: seed < 1 ? 0 : seed,
      playerId: playerId < 1 ? 0 : playerId,
      displayName: (json['display_name'] ?? json['displayName'] ?? '')
          .toString()
          .trim(),
      handle: (json['handle'] ?? '').toString().trim(),
      state: (json['state'] ?? '').toString().trim(),
      country: (json['country'] ?? '').toString().trim(),
      emailId: (json['email_id'] ?? json['emailId'] ?? '').toString().trim(),
      sourceType: (json['source_type'] ?? json['sourceType'] ?? 'new')
          .toString()
          .trim()
          .toLowerCase(),
      matchedBy: (json['matched_by'] ?? json['matchedBy'] ?? 'none')
          .toString()
          .trim()
          .toLowerCase(),
      rankingRank: rankingRank,
      rankingYear: rankingYear,
      rankingDescription:
          (json['ranking_description'] ?? json['rankingDescription'] ?? '')
              .toString()
              .trim(),
      isManual:
          json['is_manual'] as bool? ?? json['isManual'] as bool? ?? false,
      updatedAt: updatedAtRaw,
    );
  }

  final int seed;
  final int playerId;
  final String displayName;
  final String handle;
  final String state;
  final String country;
  final String emailId;
  final String sourceType;
  final String matchedBy;
  final int? rankingRank;
  final int? rankingYear;
  final String rankingDescription;
  final bool isManual;
  final String updatedAt;

  bool get isNational => sourceType == 'national';
  bool get isInternational => sourceType == 'international';
  bool get isNew => sourceType == 'new';

  String get sourceLabel {
    if (isNational) return 'National';
    if (isInternational) return 'International';
    return 'New';
  }

  SrrTournamentSeedingRow copyWith({int? seed}) {
    return SrrTournamentSeedingRow(
      seed: seed ?? this.seed,
      playerId: playerId,
      displayName: displayName,
      handle: handle,
      state: state,
      country: country,
      emailId: emailId,
      sourceType: sourceType,
      matchedBy: matchedBy,
      rankingRank: rankingRank,
      rankingYear: rankingYear,
      rankingDescription: rankingDescription,
      isManual: isManual,
      updatedAt: updatedAt,
    );
  }
}

class SrrTournamentSeedingSummary {
  const SrrTournamentSeedingSummary({
    required this.nationalPlayers,
    required this.internationalPlayers,
    required this.newPlayers,
  });

  factory SrrTournamentSeedingSummary.fromJson(Map<String, dynamic> json) {
    int parseInt(dynamic value) {
      return switch (value) {
        int v => v,
        num v => v.toInt(),
        String v => int.tryParse(v.trim()) ?? 0,
        _ => 0,
      };
    }

    return SrrTournamentSeedingSummary(
      nationalPlayers: parseInt(
        json['national_players'] ?? json['nationalPlayers'],
      ),
      internationalPlayers: parseInt(
        json['international_players'] ?? json['internationalPlayers'],
      ),
      newPlayers: parseInt(json['new_players'] ?? json['newPlayers']),
    );
  }

  final int nationalPlayers;
  final int internationalPlayers;
  final int newPlayers;
}

class SrrTournamentSeedingSnapshot {
  const SrrTournamentSeedingSnapshot({
    required this.tournament,
    required this.rankingYear,
    required this.rankingDescription,
    required this.nationalCountry,
    required this.seeded,
    required this.generatedAt,
    required this.summary,
    required this.rows,
  });

  factory SrrTournamentSeedingSnapshot.fromJson(Map<String, dynamic> json) {
    final rankingYearRaw = json['ranking_year'] ?? json['rankingYear'];
    final rankingYear = switch (rankingYearRaw) {
      int value => value,
      num value => value.toInt(),
      String value => int.tryParse(value.trim()) ?? DateTime.now().year,
      _ => DateTime.now().year,
    };
    final generatedAtRaw = (json['generated_at'] ?? json['generatedAt'])
        ?.toString()
        .trim();
    final generatedAt = generatedAtRaw == null || generatedAtRaw.isEmpty
        ? null
        : DateTime.tryParse(generatedAtRaw);
    return SrrTournamentSeedingSnapshot(
      tournament: SrrTournamentRecord.fromJson(
        json['tournament'] as Map<String, dynamic>,
      ),
      rankingYear: rankingYear,
      rankingDescription:
          (json['ranking_description'] ?? json['rankingDescription'] ?? '')
              .toString()
              .trim(),
      nationalCountry:
          (json['national_country'] ?? json['nationalCountry'] ?? '')
              .toString()
              .trim(),
      seeded: json['seeded'] as bool? ?? false,
      generatedAt: generatedAt,
      summary: json['summary'] is Map<String, dynamic>
          ? SrrTournamentSeedingSummary.fromJson(
              json['summary'] as Map<String, dynamic>,
            )
          : const SrrTournamentSeedingSummary(
              nationalPlayers: 0,
              internationalPlayers: 0,
              newPlayers: 0,
            ),
      rows: (json['rows'] as List<dynamic>? ?? const <dynamic>[])
          .whereType<Map<String, dynamic>>()
          .map(SrrTournamentSeedingRow.fromJson)
          .toList(growable: false),
    );
  }

  final SrrTournamentRecord tournament;
  final int rankingYear;
  final String rankingDescription;
  final String nationalCountry;
  final bool seeded;
  final DateTime? generatedAt;
  final SrrTournamentSeedingSummary summary;
  final List<SrrTournamentSeedingRow> rows;
}

class SrrTournamentSeedingDeleteResult {
  const SrrTournamentSeedingDeleteResult({
    required this.tournament,
    required this.deletedRows,
  });

  factory SrrTournamentSeedingDeleteResult.fromJson(Map<String, dynamic> json) {
    final deletedRowsRaw = json['deleted_rows'] ?? json['deletedRows'];
    final deletedRows = switch (deletedRowsRaw) {
      int value => value,
      num value => value.toInt(),
      String value => int.tryParse(value.trim()) ?? 0,
      _ => 0,
    };
    return SrrTournamentSeedingDeleteResult(
      tournament: SrrTournamentRecord.fromJson(
        json['tournament'] as Map<String, dynamic>,
      ),
      deletedRows: deletedRows < 0 ? 0 : deletedRows,
    );
  }

  final SrrTournamentRecord tournament;
  final int deletedRows;
}

class SrrTournamentSetupResult {
  const SrrTournamentSetupResult({
    required this.tournamentId,
    required this.tournamentName,
    required this.tournamentStatus,
    required this.metadata,
    required this.playersCreated,
    required this.roundsCreated,
    required this.matchesCreated,
    required this.credentials,
  });

  factory SrrTournamentSetupResult.fromJson(Map<String, dynamic> json) {
    final tournament = json['tournament'] as Map<String, dynamic>;
    return SrrTournamentSetupResult(
      tournamentId: tournament['id'] as int,
      tournamentName: tournament['name'] as String,
      tournamentStatus: tournament['status'] as String,
      metadata: tournament['metadata'] == null
          ? null
          : SrrTournamentMetadata.fromJson(
              tournament['metadata'] as Map<String, dynamic>,
            ),
      playersCreated: json['players_created'] as int,
      roundsCreated: json['rounds_created'] as int,
      matchesCreated: json['matches_created'] as int,
      credentials: (json['credentials'] as List<dynamic>)
          .cast<Map<String, dynamic>>()
          .map(SrrTournamentSetupCredential.fromJson)
          .toList(growable: false),
    );
  }

  final int tournamentId;
  final String tournamentName;
  final String tournamentStatus;
  final SrrTournamentMetadata? metadata;
  final int playersCreated;
  final int roundsCreated;
  final int matchesCreated;
  final List<SrrTournamentSetupCredential> credentials;
}

Map<String, dynamic> decodeObject(String jsonBody) =>
    json.decode(jsonBody) as Map<String, dynamic>;

List<Map<String, dynamic>> decodeObjectList(String jsonBody) =>
    (json.decode(jsonBody) as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .toList(growable: false);
