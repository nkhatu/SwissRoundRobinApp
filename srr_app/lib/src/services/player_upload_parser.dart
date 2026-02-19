// ---------------------------------------------------------------------------
// srr_app/lib/src/services/player_upload_parser.dart
// ---------------------------------------------------------------------------
// 
// Purpose:
// - Parses and validates player CSV/XLSX files into typed upload rows.
// Architecture:
// - Parsing utility layer handling spreadsheet format differences and field mapping.
// - Separates validation/transformation logic from upload page UI concerns.
// Author: Neil Khatu
// Copyright (c) The Khatu Family Trust
// 
import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:csv/csv.dart';
import 'package:excel/excel.dart';
import 'package:xml/xml.dart';

class TournamentUploadPlayerRow {
  const TournamentUploadPlayerRow({
    required this.displayName,
    required this.state,
    required this.country,
    required this.emailId,
    required this.registeredFlag,
    required this.tshirtSize,
    required this.feesPaidFlag,
    required this.phoneNumber,
    required this.validationErrors,
  });

  final String displayName;
  final String state;
  final String country;
  final String emailId;
  final bool registeredFlag;
  final String tshirtSize;
  final bool feesPaidFlag;
  final String phoneNumber;
  final List<String> validationErrors;

  bool get isValid => validationErrors.isEmpty;
}

class PlayerUploadParser {
  const PlayerUploadParser._();

  static TournamentUploadPlayerRow buildRow({
    required String displayName,
    required String state,
    required String country,
    required String emailId,
    required String phoneNumber,
    bool registeredFlag = false,
    String tshirtSize = 'L',
    bool feesPaidFlag = false,
  }) {
    final normalizedDisplayName = displayName.trim();
    final normalizedState = state.trim();
    final normalizedCountry = country.trim();
    final normalizedEmail = emailId.trim();
    final normalizedPhoneNumber = phoneNumber.trim();
    final normalizedTshirtSize = tshirtSize.trim().isEmpty
        ? 'L'
        : tshirtSize.trim();

    final validationErrors = <String>[];
    if (normalizedDisplayName.isEmpty) {
      validationErrors.add('Player Name is required.');
    }
    if (normalizedState.isEmpty) {
      validationErrors.add('State is required.');
    }
    if (normalizedCountry.isEmpty) {
      validationErrors.add('Country is required.');
    }
    if (normalizedEmail.isEmpty) {
      validationErrors.add('Email_Id is required.');
    } else if (!_isValidEmail(normalizedEmail)) {
      validationErrors.add('Email_Id must be a valid email.');
    }
    if (normalizedPhoneNumber.isEmpty) {
      validationErrors.add('Phone Number is required.');
    }

    return TournamentUploadPlayerRow(
      displayName: normalizedDisplayName,
      state: normalizedState,
      country: normalizedCountry,
      emailId: normalizedEmail,
      registeredFlag: registeredFlag,
      tshirtSize: normalizedTshirtSize,
      feesPaidFlag: feesPaidFlag,
      phoneNumber: normalizedPhoneNumber,
      validationErrors: validationErrors,
    );
  }

  static List<TournamentUploadPlayerRow> revalidateRows(
    List<TournamentUploadPlayerRow> rows,
  ) {
    return rows
        .map(
          (row) => buildRow(
            displayName: row.displayName,
            state: row.state,
            country: row.country,
            emailId: row.emailId,
            phoneNumber: row.phoneNumber,
            registeredFlag: row.registeredFlag,
            tshirtSize: row.tshirtSize,
            feesPaidFlag: row.feesPaidFlag,
          ),
        )
        .toList(growable: false);
  }

  static List<TournamentUploadPlayerRow> parse({
    required String fileName,
    required Uint8List bytes,
  }) {
    final extension = fileName.split('.').last.toLowerCase();
    final rawRows = switch (extension) {
      'csv' => _parseCsvRows(bytes),
      'xlsx' || 'xls' => _parseExcelRows(bytes: bytes, extension: extension),
      _ => throw const FormatException('Unsupported file extension.'),
    };

    final players = _rowsToUploadPlayers(rawRows);
    if (players.isEmpty) {
      throw const FormatException('No player rows found in the uploaded file.');
    }
    return players;
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
      if (workbook.tables.isEmpty) {
        return const [];
      }

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
      if (extension == 'xlsx') {
        return _parseXlsxRowsFallback(bytes);
      }
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
      return inline
          .findAllElements('t')
          .map((node) => node.innerText)
          .join()
          .trim();
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
    if (type == 'b') {
      return rawValue == '1' ? 'true' : 'false';
    }
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

  static List<TournamentUploadPlayerRow> _rowsToUploadPlayers(
    List<List<String>> rawRows,
  ) {
    final rows = rawRows
        .map((row) => row.map((cell) => cell.trim()).toList(growable: false))
        .where((row) => row.any((cell) => cell.isNotEmpty))
        .toList(growable: false);

    if (rows.isEmpty) return const [];

    final firstRow = rows.first;
    final normalizedHeader = firstRow
        .map(_normalizeHeader)
        .toList(growable: false);

    final hasHeader = normalizedHeader.any(_isKnownHeader);
    final dataRows = (hasHeader ? rows.skip(1).toList(growable: false) : rows)
        .where((row) => !_isHeaderLikeRow(row))
        .toList(growable: false);

    final nameIndex = hasHeader
        ? _findHeaderIndex(normalizedHeader, const [
            'display_name',
            'displayname',
            'name',
            'player',
            'player_name',
          ])
        : 0;
    final stateIndex = hasHeader
        ? _findHeaderIndex(normalizedHeader, const ['state'])
        : -1;
    final countryIndex = hasHeader
        ? _findHeaderIndex(normalizedHeader, const ['country'])
        : -1;
    final emailIndex = hasHeader
        ? _findHeaderIndex(normalizedHeader, const [
            'email_id',
            'emailid',
            'email',
          ])
        : -1;
    final registeredFlagIndex = hasHeader
        ? _findHeaderIndex(normalizedHeader, const [
            'registered_flag',
            'registered',
          ])
        : -1;
    final tshirtSizeIndex = hasHeader
        ? _findHeaderIndex(normalizedHeader, const [
            't_shirt_size',
            'tshirt_size',
            'tshirt',
            'shirt_size',
          ])
        : -1;
    final feesPaidFlagIndex = hasHeader
        ? _findHeaderIndex(normalizedHeader, const [
            'fees_paid_flag',
            'fees_paid',
            'feespaid',
          ])
        : -1;
    final phoneIndex = hasHeader
        ? _findHeaderIndex(normalizedHeader, const [
            'phone_number',
            'phonenumber',
            'phone',
            'mobile_number',
            'mobile',
          ])
        : -1;

    if (nameIndex < 0) {
      throw const FormatException(
        'Could not find player name column. Use a header like "display_name" or "name".',
      );
    }

    final output = <TournamentUploadPlayerRow>[];
    for (final row in dataRows) {
      output.add(
        buildRow(
          displayName: _cellAt(row, nameIndex),
          state: _cellAt(row, stateIndex),
          country: _cellAt(row, countryIndex),
          emailId: _cellAt(row, emailIndex),
          phoneNumber: _cellAt(row, phoneIndex),
          registeredFlag: _boolAt(row, registeredFlagIndex) ?? false,
          tshirtSize: _cellAt(row, tshirtSizeIndex),
          feesPaidFlag: _boolAt(row, feesPaidFlagIndex) ?? false,
        ),
      );
    }
    return output;
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
      'display_name',
      'displayname',
      'name',
      'player',
      'player_name',
      'state',
      'country',
      'email_id',
      'emailid',
      'email',
      'registered_flag',
      'registered',
      't_shirt_size',
      'tshirt_size',
      'tshirt',
      'shirt_size',
      'fees_paid_flag',
      'fees_paid',
      'feespaid',
      'phone_number',
      'phonenumber',
      'phone',
      'mobile_number',
      'mobile',
    }.contains(value);
  }

  static bool _isHeaderLikeRow(List<String> row) {
    final normalized = row
        .map(_normalizeHeader)
        .where((cell) => cell.isNotEmpty)
        .toList(growable: false);
    if (normalized.isEmpty) return false;

    final headerMatches = normalized.where(_isKnownHeader).length;
    final hasPlayerNameHeader = normalized.any(
      (value) => const {
        'display_name',
        'displayname',
        'name',
        'player',
        'player_name',
      }.contains(value),
    );

    return hasPlayerNameHeader && headerMatches >= 2;
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

  static bool? _boolAt(List<String> row, int index) {
    final value = _cellAt(row, index);
    if (value.isEmpty) return null;
    final normalized = value.trim().toLowerCase();
    return normalized == '1' ||
        normalized == 'true' ||
        normalized == 'yes' ||
        normalized == 'y';
  }

  static bool _isValidEmail(String value) {
    final normalized = value.trim();
    return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(normalized);
  }
}
