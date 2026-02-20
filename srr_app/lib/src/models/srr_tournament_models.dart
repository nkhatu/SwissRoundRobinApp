// ---------------------------------------------------------------------------
// srr_app/lib/src/models/srr_tournament_models.dart
// ---------------------------------------------------------------------------
//
// Purpose:
// - Houses the tournament-centric DTOs, workflows, and seeding helpers.
// Architecture:
// - Groups related classes for tournament, workflow, and grouping responses.
// Author: Neil Khatu
// Copyright (c) The Khatu Family Trust
//
import 'srr_match_models.dart';

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
    required this.numberOfGroups,
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
        .map((entry) =>
            normalizeType(entry?.toString().trim().toLowerCase() ?? ''))
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
        : (const {'singles', 'doubles'}
                    .contains(legacySubTypeCandidate)
            ? legacySubTypeCandidate
            : 'singles');
    final now = DateTime.now();
    final startDateTime =
        DateTime.tryParse((json['start_date_time'] ??
                        json['tournament_start_date_time'] ??
                        json['startDateTime'] ??
                        '')
                    .toString()) ??
            now;
    final endDateTime =
        DateTime.tryParse((json['end_date_time'] ??
                        json['tournament_end_date_time'] ??
                        json['endDateTime'] ??
                        '')
                    .toString()) ??
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
    final groupsRaw =
        json['number_of_groups'] ??
        json['tournament_number_of_groups'] ??
        json['numberOfGroups'];
    final parsedGroupCount = switch (groupsRaw) {
      int value => value,
      num value => value.toInt(),
      String value => int.tryParse(value.trim()) ?? 4,
      _ => 4,
    };
    return SrrTournamentMetadata(
      type: type,
      subType: subType,
      strength: (json['strength'] as num).toDouble(),
      startDateTime: startDateTime,
      endDateTime: endDateTime,
      srrRounds: parsedSrrRounds < 1 ? 7 : parsedSrrRounds,
      numberOfGroups: parsedGroupCount < 2 ? 4 : parsedGroupCount,
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
  final int numberOfGroups;
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
    'tournament_number_of_groups': numberOfGroups,
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
          (json['type'] as String?)?.trim().toLowerCase() ?? metadata?.type ?? '',
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
        int val => val,
        num val => val.toInt(),
        String val => int.tryParse(val.trim()) ?? 0,
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
    final generatedAtRaw =
        (json['generated_at'] ?? json['generatedAt'])?.toString().trim();
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

class SrrTournamentGroupingMethod {
  const SrrTournamentGroupingMethod._();

  static const interleaved = 'interleaved';
  static const snake = 'snake';

  static const values = <String>[interleaved, snake];
}

class SrrTournamentGroupRow {
  const SrrTournamentGroupRow({
    required this.seed,
    required this.groupNumber,
    required this.groupCount,
    required this.method,
    required this.playerId,
    required this.displayName,
    required this.handle,
    required this.state,
    required this.country,
    required this.emailId,
    required this.sourceType,
    required this.rankingRank,
    required this.rankingYear,
    required this.rankingDescription,
    required this.updatedAt,
  });

  factory SrrTournamentGroupRow.fromJson(Map<String, dynamic> json) {
    final seedRaw = json['seed'];
    final seed = switch (seedRaw) {
      int value => value,
      num value => value.toInt(),
      String value => int.tryParse(value.trim()) ?? 0,
      _ => 0,
    };
    final groupNumberRaw = json['group_number'] ?? json['groupNumber'];
    final groupNumber = switch (groupNumberRaw) {
      int value => value,
      num value => value.toInt(),
      String value => int.tryParse(value.trim()) ?? 0,
      _ => 0,
    };
    final groupCountRaw = json['group_count'] ?? json['groupCount'];
    final groupCount = switch (groupCountRaw) {
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
    return SrrTournamentGroupRow(
      seed: seed < 1 ? 0 : seed,
      groupNumber: groupNumber < 1 ? 0 : groupNumber,
      groupCount: groupCount < 1 ? 0 : groupCount,
      method: (json['method'] ?? SrrTournamentGroupingMethod.interleaved)
          .toString()
          .trim()
          .toLowerCase(),
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
      rankingRank: rankingRank,
      rankingYear: rankingYear,
      rankingDescription:
          (json['ranking_description'] ?? json['rankingDescription'] ?? '')
              .toString()
              .trim(),
      updatedAt: updatedAtRaw,
    );
  }

  final int seed;
  final int groupNumber;
  final int groupCount;
  final String method;
  final int playerId;
  final String displayName;
  final String handle;
  final String state;
  final String country;
  final String emailId;
  final String sourceType;
  final int? rankingRank;
  final int? rankingYear;
  final String rankingDescription;
  final String updatedAt;
}

class SrrTournamentGroupsSnapshot {
  const SrrTournamentGroupsSnapshot({
    required this.tournament,
    required this.generated,
    required this.method,
    required this.groupCount,
    required this.generatedAt,
    required this.rows,
  });

  factory SrrTournamentGroupsSnapshot.fromJson(Map<String, dynamic> json) {
    final groupCountRaw = json['group_count'] ?? json['groupCount'];
    final groupCount = switch (groupCountRaw) {
      int value => value,
      num value => value.toInt(),
      String value => int.tryParse(value.trim()) ?? 0,
      _ => 0,
    };
    final generatedAtRaw = (json['generated_at'] ?? json['generatedAt'])
        ?.toString()
        .trim();
    final generatedAt = generatedAtRaw == null || generatedAtRaw.isEmpty
        ? null
        : DateTime.tryParse(generatedAtRaw);
    final method = (json['method'] ?? '').toString().trim().toLowerCase();
    return SrrTournamentGroupsSnapshot(
      tournament: SrrTournamentRecord.fromJson(
        json['tournament'] as Map<String, dynamic>,
      ),
      generated: json['generated'] as bool? ?? false,
      method: SrrTournamentGroupingMethod.values.contains(method)
          ? method
          : null,
      groupCount: groupCount < 2 ? 2 : groupCount,
      generatedAt: generatedAt,
      rows: (json['rows'] as List<dynamic>? ?? const <dynamic>[])
          .whereType<Map<String, dynamic>>()
          .map(SrrTournamentGroupRow.fromJson)
          .toList(growable: false),
    );
  }

  final SrrTournamentRecord tournament;
  final bool generated;
  final String? method;
  final int groupCount;
  final DateTime? generatedAt;
  final List<SrrTournamentGroupRow> rows;
}

class SrrTournamentGroupsDeleteResult {
  const SrrTournamentGroupsDeleteResult({
    required this.tournament,
    required this.deletedRows,
  });

  factory SrrTournamentGroupsDeleteResult.fromJson(Map<String, dynamic> json) {
    final deletedRowsRaw = json['deleted_rows'] ?? json['deletedRows'];
    final deletedRows = switch (deletedRowsRaw) {
      int value => value,
      num value => value.toInt(),
      String value => int.tryParse(value.trim()) ?? 0,
      _ => 0,
    };
    return SrrTournamentGroupsDeleteResult(
      tournament: SrrTournamentRecord.fromJson(
        json['tournament'] as Map<String, dynamic>,
      ),
      deletedRows: deletedRows < 0 ? 0 : deletedRows,
    );
  }

  final SrrTournamentRecord tournament;
  final int deletedRows;
}

class SrrGroupMatchupSummary {
  const SrrGroupMatchupSummary({
    required this.groupNumber,
    required this.playerCount,
    required this.currentRound,
    required this.maxRounds,
    required this.pendingMatches,
    required this.completedMatches,
  });

  factory SrrGroupMatchupSummary.fromJson(Map<String, dynamic> json) {
    int parseInt(dynamic value) {
      return switch (value) {
        int val => val,
        num val => val.toInt(),
        String val => int.tryParse(val.trim()) ?? 0,
        _ => 0,
      };
    }

    return SrrGroupMatchupSummary(
      groupNumber: parseInt(json['group_number'] ?? json['groupNumber']),
      playerCount: parseInt(json['player_count'] ?? json['playerCount']),
      currentRound: parseInt(json['current_round'] ?? json['currentRound']),
      maxRounds: parseInt(json['max_rounds'] ?? json['maxRounds']),
      pendingMatches: parseInt(
        json['pending_matches'] ?? json['pendingMatches'],
      ),
      completedMatches: parseInt(
        json['completed_matches'] ?? json['completedMatches'],
      ),
    );
  }

  final int groupNumber;
  final int playerCount;
  final int currentRound;
  final int maxRounds;
  final int pendingMatches;
  final int completedMatches;
}

class SrrMatchupGenerateResult {
  const SrrMatchupGenerateResult({
    required this.tournament,
    required this.groupNumber,
    required this.roundNumber,
    required this.method,
    required this.matchesCreated,
    required this.summary,
  });

  factory SrrMatchupGenerateResult.fromJson(Map<String, dynamic> json) {
    int parseInt(dynamic value) {
      return switch (value) {
        int val => val,
        num val => val.toInt(),
        String val => int.tryParse(val.trim()) ?? 0,
        _ => 0,
      };
    }

    return SrrMatchupGenerateResult(
      tournament: SrrTournamentRecord.fromJson(
        json['tournament'] as Map<String, dynamic>,
      ),
      groupNumber: parseInt(json['group_number'] ?? json['groupNumber']),
      roundNumber: parseInt(json['round_number'] ?? json['roundNumber']),
      method: (json['method'] ?? '').toString().trim().toLowerCase(),
      matchesCreated: parseInt(
        json['matches_created'] ?? json['matchesCreated'],
      ),
      summary: SrrGroupMatchupSummary.fromJson(
        (json['summary'] as Map<String, dynamic>? ?? const {}),
      ),
    );
  }

  final SrrTournamentRecord tournament;
  final int groupNumber;
  final int roundNumber;
  final String method;
  final int matchesCreated;
  final SrrGroupMatchupSummary summary;
}

class SrrMatchupDeleteResult {
  const SrrMatchupDeleteResult({
    required this.tournament,
    required this.groupNumber,
    required this.deletedRoundNumber,
    required this.deletedMatches,
    required this.summary,
  });

  factory SrrMatchupDeleteResult.fromJson(Map<String, dynamic> json) {
    int parseInt(dynamic value) {
      return switch (value) {
        int val => val,
        num val => val.toInt(),
        String val => int.tryParse(val.trim()) ?? 0,
        _ => 0,
      };
    }

    return SrrMatchupDeleteResult(
      tournament: SrrTournamentRecord.fromJson(
        json['tournament'] as Map<String, dynamic>,
      ),
      groupNumber: parseInt(json['group_number'] ?? json['groupNumber']),
      deletedRoundNumber: parseInt(
        json['deleted_round_number'] ?? json['deletedRoundNumber'],
      ),
      deletedMatches: parseInt(
        json['deleted_matches'] ?? json['deletedMatches'],
      ),
      summary: SrrGroupMatchupSummary.fromJson(
        (json['summary'] as Map<String, dynamic>? ?? const {}),
      ),
    );
  }

  final SrrTournamentRecord tournament;
  final int groupNumber;
  final int deletedRoundNumber;
  final int deletedMatches;
  final SrrGroupMatchupSummary summary;
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
