// ---------------------------------------------------------------------------
// srr_app/test/ranking_upload_parser_test.dart
// ---------------------------------------------------------------------------
// 
// Purpose:
// - Validates ranking upload parser behavior across supported input edge cases.
// Architecture:
// - Unit test module focused on ranking parsing and validation outcomes.
// - Protects ranking workflows from regressions in file handling logic.
// Author: Neil Khatu
// Copyright (c) The Khatu Family Trust
// 
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:srr_app/src/services/ranking_upload_parser.dart';

void main() {
  test('flags blank and duplicate ranks', () {
    const csv = '''
Rank,Player Name,State,Country,Email_Id,Ranking Points,Ranking Year,Last Updated,Extra
1,Alice,Rajasthan,India,alice@srr.example.com,2500,2026,2026-02-18,ignored
,Bob,Maharashtra,India,bob@srr.example.com,2480,2026,2026-02-18,ignored
1,Charlie,Karnataka,India,charlie@srr.example.com,2470,2026,2026-02-18,ignored
''';

    final rows = RankingUploadParser.parse(
      fileName: 'ranking.csv',
      bytes: Uint8List.fromList(utf8.encode(csv)),
    );

    expect(rows.length, 3);
    expect(rows[0].isValid, isFalse);
    expect(rows[1].isValid, isFalse);
    expect(rows[2].isValid, isFalse);
    expect(rows[1].validationErrors, contains('Rank is required.'));
    expect(
      rows[0].validationErrors.any((entry) => entry.contains('Duplicate rank')),
      isTrue,
    );
    expect(
      rows[2].validationErrors.any((entry) => entry.contains('Duplicate rank')),
      isTrue,
    );
  });
}
