// ---------------------------------------------------------------------------
// srr_app/lib/src/services/srr_tournament_labels.dart
// ---------------------------------------------------------------------------
//
// Purpose:
// - Centralizes tournament label formatting for dropdowns and context display.
// Architecture:
// - Stateless formatting utility consumed by multiple presentation pages.
// - Keeps tournament naming rules consistent across workflow and upload screens.
// Author: Neil Khatu
// Copyright (c) The Khatu Family Trust
//

import '../models/srr_models.dart';

String srrInitCapWords(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return '';
  final normalized = trimmed.replaceAll(RegExp(r'[_-]+'), ' ').toLowerCase();
  return normalized
      .split(RegExp(r'\s+'))
      .where((word) => word.isNotEmpty)
      .map((word) => '${word[0].toUpperCase()}${word.substring(1)}')
      .join(' ');
}

String srrTournamentDropdownLabel(SrrTournamentRecord tournament) {
  final rawName = tournament.name.trim();
  final name = rawName.isEmpty ? 'Unnamed Tournament' : rawName;
  final type = srrInitCapWords(
    tournament.type.trim().isNotEmpty
        ? tournament.type
        : (tournament.metadata?.type ?? ''),
  );
  final subType = srrInitCapWords(tournament.metadata?.subType ?? '');

  if (type.isEmpty && subType.isEmpty) {
    return name;
  }
  if (type.isEmpty) {
    return '$name ($subType)';
  }
  if (subType.isEmpty) {
    return '$name $type';
  }
  return '$name $type ($subType)';
}
