// ---------------------------------------------------------------------------
// srr_app/lib/src/models/srr_ranking_models.dart
// ---------------------------------------------------------------------------
//
// Purpose:
// - Captures national ranking DTOs and upload responses.
// Architecture:
// - Aligns ranking-specific parsing with the Firestore collection schema.
// Author: Neil Khatu
// Copyright (c) The Khatu Family Trust
//
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
      years: (json['years'] as List<dynamic>? ?? const <dynamic>[])
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
