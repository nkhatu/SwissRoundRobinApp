// ---------------------------------------------------------------------------
// srr_app/lib/src/services/srr_country_iso.dart
// ---------------------------------------------------------------------------
//
// Purpose:
// - Provides shared country alias normalization and ISO/flag derivation helpers.
// Architecture:
// - Stateless utility functions shared by presentation pages that display country flags.
// - Keeps country alias mapping in one global place to avoid per-screen duplication.
// Author: Neil Khatu
// Copyright (c) The Khatu Family Trust
//

const Map<String, String> srrCountryIsoAliases = {
  'us': 'US',
  'usa': 'US',
  'unitedstates': 'US',
  'unitedstatesofamerica': 'US',
  'america': 'US',
  'india': 'IN',
  'bharat': 'IN',
  'france': 'FR',
  'germany': 'DE',
  'deutschland': 'DE',
  'italy': 'IT',
  'italia': 'IT',
  'canada': 'CA',
  'poland': 'PL',
  'polska': 'PL',
  'switzerland': 'CH',
  'suisse': 'CH',
  'schweiz': 'CH',
  'svizzera': 'CH',
  'holland': 'NL',
  'netherlands': 'NL',
  'uk': 'GB',
  'unitedkingdom': 'GB',
  'greatbritain': 'GB',
  'england': 'GB',
  'australia': 'AU',
  'japan': 'JP',
  'nippon': 'JP',
  'nihon': 'JP',
  'maldives': 'MV',
  'srilanka': 'LK',
  'ceylon': 'LK',
  'bangladesh': 'BD',
  'pakistan': 'PK',
  'southkorea': 'KR',
  'republicofkorea': 'KR',
  'koreasouth': 'KR',
  'malaysia': 'MY',
  'singapore': 'SG',
  'uae': 'AE',
  'unitedarabemirates': 'AE',
};

String srrNormalizeCountryLookup(String value) {
  return value.trim().toLowerCase().replaceAll(RegExp(r'[^a-z]'), '');
}

String srrCountryIsoCode(String country) {
  final normalized = srrNormalizeCountryLookup(country);
  if (normalized.length == 2) {
    return normalized.toUpperCase();
  }
  return srrCountryIsoAliases[normalized] ?? '';
}

String srrCountryFlagEmoji(String country) {
  final isoCode = srrCountryIsoCode(country);
  if (isoCode.length != 2) return '';
  final upper = isoCode.toUpperCase();
  final first = upper.codeUnitAt(0);
  final second = upper.codeUnitAt(1);
  if (first < 65 || first > 90 || second < 65 || second > 90) return '';
  return String.fromCharCodes([first + 127397, second + 127397]);
}
