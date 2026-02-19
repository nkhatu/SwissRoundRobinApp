// ---------------------------------------------------------------------------
// srr_app/lib/src/services/ranking_upload_parser.dart
// ---------------------------------------------------------------------------
// 
// Purpose:
// - Parses and validates ranking CSV/XLSX files into typed upload rows.
// Architecture:
// - Parsing utility layer handling ranking schema mapping and validation rules.
// - Separates file normalization logic from ranking page workflow orchestration.
// Author: Neil Khatu
// Copyright (c) The Khatu Family Trust
// 
import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:csv/csv.dart';
import 'package:excel/excel.dart';
import 'package:xml/xml.dart';

class RankingUploadRow {
  RankingUploadRow({
    required this.rank,
    required this.playerName,
    required this.state,
    required this.country,
    required this.emailId,
    required this.rankingPoints,
    required this.rankingYear,
    required this.lastUpdated,
    required this.validationErrors,
  });

  final String rank;
  final String playerName;
  final String state;
  final String country;
  final String emailId;
  final String rankingPoints;
  final String rankingYear;
  final String lastUpdated;
  final List<String> validationErrors;

  bool get isValid => validationErrors.isEmpty;
}

class RankingUploadParser {
  const RankingUploadParser._();

  static RankingUploadRow buildRow({
    required String rank,
    required String playerName,
    required String state,
    required String country,
    required String emailId,
    required String rankingPoints,
    required String rankingYear,
    required String lastUpdated,
  }) {
    final normalizedRank = rank.trim();
    final validationErrors = <String>[];
    if (normalizedRank.isEmpty) {
      validationErrors.add('Rank is required.');
    }
    return RankingUploadRow(
      rank: normalizedRank,
      playerName: playerName.trim(),
      state: state.trim(),
      country: country.trim(),
      emailId: emailId.trim(),
      rankingPoints: rankingPoints.trim(),
      rankingYear: rankingYear.trim(),
      lastUpdated: lastUpdated.trim(),
      validationErrors: validationErrors,
    );
  }

  static List<RankingUploadRow> revalidateRows(List<RankingUploadRow> rows) {
    final output = rows
        .map(
          (row) => buildRow(
            rank: row.rank,
            playerName: row.playerName,
            state: row.state,
            country: row.country,
            emailId: row.emailId,
            rankingPoints: row.rankingPoints,
            rankingYear: row.rankingYear,
            lastUpdated: row.lastUpdated,
          ),
        )
        .toList(growable: false);

    final seenRanks = <String, List<int>>{};
    for (int index = 0; index < output.length; index += 1) {
      final rank = output[index].rank;
      if (rank.isEmpty) continue;
      final canonicalRank = _canonicalRank(rank);
      seenRanks.putIfAbsent(canonicalRank, () => <int>[]).add(index);
    }
    seenRanks.forEach((rank, indexes) {
      if (indexes.length <= 1) return;
      for (final index in indexes) {
        output[index].validationErrors.add(
          'Duplicate rank "$rank" is not allowed.',
        );
      }
    });
    return output;
  }

  static List<RankingUploadRow> parse({
    required String fileName,
    required Uint8List bytes,
  }) {
    final extension = fileName.split('.').last.toLowerCase();
    final rawRows = switch (extension) {
      'csv' => _parseCsvRows(bytes),
      'xlsx' || 'xls' => _parseExcelRows(bytes: bytes, extension: extension),
      _ => throw const FormatException('Unsupported file extension.'),
    };
    final rows = _rowsToRanking(rawRows);
    if (rows.isEmpty) {
      throw const FormatException(
        'No ranking rows found in the uploaded file.',
      );
    }
    return rows;
  }

  static List<List<String>> _parseCsvRows(Uint8List bytes) {
    final csvText = utf8.decode(bytes, allowMalformed: true);
    final rows = const CsvDecoder(dynamicTyping: false).convert(csvText);
    return rows
        .map(
          (row) =>
              row.map((cell) => _normalizeCell(cell)).toList(growable: false),
        )
        .toList(growable: false);
  }

  static List<List<String>> _parseExcelRows({
    required Uint8List bytes,
    required String extension,
  }) {
    try {
      final workbook = Excel.decodeBytes(bytes);
      if (workbook.tables.isEmpty) return const [];

      Sheet? selectedSheet;
      for (final sheet in workbook.tables.values) {
        if (sheet.rows.any((row) => row.any((cell) => cell?.value != null))) {
          selectedSheet = sheet;
          break;
        }
      }
      selectedSheet ??= workbook.tables.values.first;
      return selectedSheet.rows
          .map(
            (row) => row
                .map((cell) => _normalizeCell(cell?.value))
                .toList(growable: false),
          )
          .toList(growable: false);
    } catch (_) {
      if (extension == 'xlsx') return _parseXlsxRowsFallback(bytes);
      throw const FormatException(
        'Unable to parse this Excel file. Save as .xlsx or .csv and retry.',
      );
    }
  }

  static List<List<String>> _parseXlsxRowsFallback(Uint8List bytes) {
    final archive = ZipDecoder().decodeBytes(bytes, verify: false);
    final sheetXml = _archiveFileText(archive, _firstSheetPath(archive));
    if (sheetXml == null || sheetXml.trim().isEmpty) {
      throw const FormatException(
        'XLSX parse failed: worksheet data is missing. Save and retry.',
      );
    }

    final sharedStrings = _readSharedStrings(archive);
    final document = XmlDocument.parse(sheetXml);
    final sheetData = document.findAllElements('sheetData').firstOrNull;
    if (sheetData == null) return const [];

    final rows = <List<String>>[];
    for (final row in sheetData.findElements('row')) {
      final valuesByCol = <int, String>{};
      var maxCol = -1;
      for (final cell in row.findElements('c')) {
        final reference = cell.getAttribute('r') ?? '';
        final colIndex = _columnIndexFromCellRef(reference);
        if (colIndex < 0) continue;
        final value = _cellValue(cell: cell, sharedStrings: sharedStrings);
        if (value.isEmpty) continue;
        valuesByCol[colIndex] = value;
        if (colIndex > maxCol) maxCol = colIndex;
      }
      if (maxCol < 0) {
        rows.add(const []);
        continue;
      }
      final expanded = List<String>.filled(maxCol + 1, '');
      valuesByCol.forEach((index, value) {
        expanded[index] = value;
      });
      rows.add(expanded);
    }
    return rows;
  }

  static String _cellValue({
    required XmlElement cell,
    required List<String> sharedStrings,
  }) {
    final type = (cell.getAttribute('t') ?? '').trim().toLowerCase();
    if (type == 'inlineStr'.toLowerCase()) {
      final inline = cell.findAllElements('is').firstOrNull;
      if (inline == null) return '';
      return inline.findAllElements('t').map((entry) => entry.innerText).join();
    }
    final rawValue = cell.findElements('v').firstOrNull?.innerText.trim() ?? '';
    if (rawValue.isEmpty) return '';
    if (type == 's') {
      final index = int.tryParse(rawValue);
      if (index == null || index < 0 || index >= sharedStrings.length) {
        return '';
      }
      return sharedStrings[index];
    }
    if (type == 'b') return rawValue == '1' ? 'true' : 'false';
    return rawValue;
  }

  static List<String> _readSharedStrings(Archive archive) {
    final content = _archiveFileText(archive, 'xl/sharedStrings.xml');
    if (content == null || content.trim().isEmpty) return const [];
    final document = XmlDocument.parse(content);
    return document
        .findAllElements('si')
        .map(
          (si) => si
              .findAllElements('t')
              .map((text) => text.innerText)
              .join()
              .trim(),
        )
        .toList(growable: false);
  }

  static String _firstSheetPath(Archive archive) {
    final worksheetFiles =
        archive.files
            .where((file) => file.name.startsWith('xl/worksheets/sheet'))
            .map((file) => file.name)
            .toList(growable: false)
          ..sort();
    if (worksheetFiles.isEmpty) {
      throw const FormatException(
        'XLSX parse failed: no worksheet found in workbook.',
      );
    }
    return worksheetFiles.first;
  }

  static String? _archiveFileText(Archive archive, String path) {
    final file = archive.files.firstWhere(
      (entry) => entry.name == path,
      orElse: () => ArchiveFile(path, 0, const <int>[]),
    );
    if (file.size == 0 || file.content is! List<int>) return null;
    return utf8.decode(file.content as List<int>, allowMalformed: true);
  }

  static int _columnIndexFromCellRef(String reference) {
    if (reference.isEmpty) return -1;
    final letters = reference.toUpperCase().replaceAll(RegExp(r'[^A-Z]'), '');
    if (letters.isEmpty) return -1;
    var value = 0;
    for (final codeUnit in letters.codeUnits) {
      value = value * 26 + (codeUnit - 64);
    }
    return value - 1;
  }

  static List<RankingUploadRow> _rowsToRanking(List<List<String>> rawRows) {
    final rows = rawRows
        .map((row) => row.map((cell) => cell.trim()).toList(growable: false))
        .where((row) => row.any((cell) => cell.isNotEmpty))
        .toList(growable: false);
    if (rows.isEmpty) return const [];

    final normalizedHeader = rows.first
        .map(_normalizeHeader)
        .toList(growable: false);
    final hasHeader = normalizedHeader.any(_isKnownHeader);
    final dataRows = (hasHeader ? rows.skip(1).toList(growable: false) : rows)
        .where((row) => !_isHeaderLikeRow(row))
        .toList(growable: false);

    final rankIndex = hasHeader
        ? _findHeaderIndex(normalizedHeader, const [
            'rank',
            'ranking',
            'ranking_position',
            'position',
          ])
        : 0;
    final playerNameIndex = hasHeader
        ? _findHeaderIndex(normalizedHeader, const [
            'player_name',
            'player',
            'name',
            'display_name',
          ])
        : 1;
    final stateIndex = hasHeader
        ? _findHeaderIndex(normalizedHeader, const ['state'])
        : 2;
    final countryIndex = hasHeader
        ? _findHeaderIndex(normalizedHeader, const ['country'])
        : 3;
    final emailIndex = hasHeader
        ? _findHeaderIndex(normalizedHeader, const ['email_id', 'email'])
        : 4;
    final pointsIndex = hasHeader
        ? _findHeaderIndex(normalizedHeader, const ['ranking_points', 'points'])
        : 5;
    final yearIndex = hasHeader
        ? _findHeaderIndex(normalizedHeader, const ['ranking_year', 'year'])
        : 6;
    final updatedIndex = hasHeader
        ? _findHeaderIndex(normalizedHeader, const [
            'last_updated',
            'updated_on',
            'updated_at',
          ])
        : 7;

    if (rankIndex < 0) {
      throw const FormatException(
        'Could not find rank column. Use a header like "rank".',
      );
    }

    final output = dataRows
        .map(
          (row) => buildRow(
            rank: _cellAt(row, rankIndex),
            playerName: _cellAt(row, playerNameIndex),
            state: _cellAt(row, stateIndex),
            country: _cellAt(row, countryIndex),
            emailId: _cellAt(row, emailIndex),
            rankingPoints: _cellAt(row, pointsIndex),
            rankingYear: _cellAt(row, yearIndex),
            lastUpdated: _cellAt(row, updatedIndex),
          ),
        )
        .toList(growable: false);
    return revalidateRows(output);
  }

  static String _normalizeCell(Object? value) {
    if (value == null) return '';
    return value.toString().trim();
  }

  static String _normalizeHeader(String value) {
    return value
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
  }

  static bool _isKnownHeader(String value) {
    return const {
      'rank',
      'ranking',
      'ranking_position',
      'position',
      'player_name',
      'player',
      'name',
      'display_name',
      'state',
      'country',
      'email_id',
      'email',
      'ranking_points',
      'points',
      'ranking_year',
      'year',
      'last_updated',
      'updated_on',
      'updated_at',
    }.contains(value);
  }

  static bool _isHeaderLikeRow(List<String> row) {
    final normalized = row
        .map(_normalizeHeader)
        .where((cell) => cell.isNotEmpty)
        .toList(growable: false);
    if (normalized.isEmpty) return false;

    final headerMatches = normalized.where(_isKnownHeader).length;
    final hasRankHeader = normalized.any(
      (value) => const {
        'rank',
        'ranking',
        'ranking_position',
        'position',
      }.contains(value),
    );

    return hasRankHeader && headerMatches >= 2;
  }

  static int _findHeaderIndex(List<String> header, List<String> candidates) {
    for (final candidate in candidates) {
      final index = header.indexOf(candidate);
      if (index >= 0) return index;
    }
    return -1;
  }

  static String _cellAt(List<String> row, int index) {
    if (index < 0 || index >= row.length) return '';
    return row[index].trim();
  }

  static String _canonicalRank(String value) {
    final trimmed = value.trim();
    final asInt = int.tryParse(trimmed);
    if (asInt != null) return asInt.toString();
    return trimmed.toLowerCase();
  }
}
