// ---------------------------------------------------------------------------
// srr_app/lib/src/models/srr_enums.dart
// ---------------------------------------------------------------------------
//
// Purpose:
// - Defines shared SRR domain enums and parsing helpers.
// Architecture:
// - Centralizes all JSON normalization helpers so the models split cleanly.
// Author: Neil Khatu
// Copyright (c) The Khatu Family Trust
//

enum SrrMatchStatus { pending, disputed, confirmed }

enum SrrTossDecision { strikeFirst, chooseSide }

enum SrrCarromColor { white, black }

enum SrrQueenPocketedBy { none, striker, nonStriker }

SrrMatchStatus srrMatchStatusFromString(String value) {
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

SrrTossDecision? srrTossDecisionFromString(String? value) {
  switch (value) {
    case 'strike_first':
      return SrrTossDecision.strikeFirst;
    case 'choose_side':
      return SrrTossDecision.chooseSide;
    default:
      return null;
  }
}

SrrCarromColor? srrCarromColorFromString(String? value) {
  switch (value) {
    case 'white':
      return SrrCarromColor.white;
    case 'black':
      return SrrCarromColor.black;
    default:
      return null;
  }
}

SrrQueenPocketedBy srrQueenPocketedByFromString(String? value) {
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
