// ---------------------------------------------------------------------------
// srr_app/test/player_upload_parser_test.dart
// ---------------------------------------------------------------------------
// 
// Purpose:
// - Validates player upload parser behavior across supported input edge cases.
// Architecture:
// - Unit test module focused on parsing and validation outcomes.
// - Protects upload workflows from regressions in file handling logic.
// Author: Neil Khatu
// Copyright (c) The Khatu Family Trust
// 
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:srr_app/src/services/player_upload_parser.dart';

void main() {
  test('parses players_list_100.xlsx upload template', () {
    final file = File('../templates/players_list_100.xlsx');
    expect(file.existsSync(), isTrue);

    final rows = PlayerUploadParser.parse(
      fileName: 'players_list_100.xlsx',
      bytes: file.readAsBytesSync(),
    );

    expect(rows.length, 100);
    expect(rows.first.displayName, 'Aarav Sharma');
    expect(rows.first.emailId, 'player001@srr.example.com');
    expect(rows.last.displayName, 'Manav Gupta');
    expect(rows.last.emailId, 'player100@srr.example.com');
  });
}
