// ---------------------------------------------------------------------------
// srr_app/lib/src/theme/srr_display_preferences_controller.dart
// ---------------------------------------------------------------------------
// 
// Purpose:
// - Manages locale and date-time display formatting preferences per user.
// Architecture:
// - Controller layer for formatting/localization preference state and persistence.
// - Provides formatting helpers consumed by upload and dashboard presentation layers.
// Author: Neil Khatu
// Copyright (c) The Khatu Family Trust
// 
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum SrrDateTimeDisplayFormat {
  us24,
  us12,
  dayMonth24,
  localeAdaptive,
  isoLocal,
}

extension SrrDateTimeDisplayFormatX on SrrDateTimeDisplayFormat {
  String get storageValue {
    switch (this) {
      case SrrDateTimeDisplayFormat.us24:
        return 'us_24';
      case SrrDateTimeDisplayFormat.us12:
        return 'us_12';
      case SrrDateTimeDisplayFormat.dayMonth24:
        return 'day_month_24';
      case SrrDateTimeDisplayFormat.localeAdaptive:
        return 'locale_adaptive';
      case SrrDateTimeDisplayFormat.isoLocal:
        return 'iso_local';
    }
  }

  String get label {
    switch (this) {
      case SrrDateTimeDisplayFormat.us24:
        return 'MM/DD/YYYY HH:MM:SS';
      case SrrDateTimeDisplayFormat.us12:
        return 'MM/DD/YYYY hh:MM:SS AM/PM';
      case SrrDateTimeDisplayFormat.dayMonth24:
        return 'DD/MM/YYYY HH:MM:SS';
      case SrrDateTimeDisplayFormat.localeAdaptive:
        return 'Locale Adaptive';
      case SrrDateTimeDisplayFormat.isoLocal:
        return 'YYYY-MM-DD HH:MM:SS';
    }
  }
}

enum SrrLocalePreference { system, enUs, enGb, hiIn, frFr }

extension SrrLocalePreferenceX on SrrLocalePreference {
  String get storageValue {
    switch (this) {
      case SrrLocalePreference.system:
        return 'system';
      case SrrLocalePreference.enUs:
        return 'en_US';
      case SrrLocalePreference.enGb:
        return 'en_GB';
      case SrrLocalePreference.hiIn:
        return 'hi_IN';
      case SrrLocalePreference.frFr:
        return 'fr_FR';
    }
  }

  String get label {
    switch (this) {
      case SrrLocalePreference.system:
        return 'System Default';
      case SrrLocalePreference.enUs:
        return 'English (US)';
      case SrrLocalePreference.enGb:
        return 'English (UK)';
      case SrrLocalePreference.hiIn:
        return 'Hindi (India)';
      case SrrLocalePreference.frFr:
        return 'French (France)';
    }
  }

  Locale? get locale {
    switch (this) {
      case SrrLocalePreference.system:
        return null;
      case SrrLocalePreference.enUs:
        return const Locale('en', 'US');
      case SrrLocalePreference.enGb:
        return const Locale('en', 'GB');
      case SrrLocalePreference.hiIn:
        return const Locale('hi', 'IN');
      case SrrLocalePreference.frFr:
        return const Locale('fr', 'FR');
    }
  }
}

class SrrDisplayPreferencesController extends ChangeNotifier {
  static const _guestDateTimeFormatKey = 'srr_datetime_format_guest';
  static const _guestLocaleKey = 'srr_locale_guest';
  static const _userDateTimeFormatPrefix = 'srr_datetime_format_user_';
  static const _userLocalePrefix = 'srr_locale_user_';

  static const List<Locale> supportedLocales = <Locale>[
    Locale('en', 'US'),
    Locale('en', 'GB'),
    Locale('hi', 'IN'),
    Locale('fr', 'FR'),
  ];

  SrrDateTimeDisplayFormat _dateTimeFormat = SrrDateTimeDisplayFormat.us24;
  SrrLocalePreference _localePreference = SrrLocalePreference.system;
  String? _activeUserId;

  SrrDateTimeDisplayFormat get dateTimeFormat => _dateTimeFormat;
  SrrLocalePreference get localePreference => _localePreference;
  Locale? get locale => _localePreference.locale;

  Future<void> load({String? userId}) async {
    _activeUserId = userId?.trim();
    final prefs = await SharedPreferences.getInstance();
    final storedFormat = prefs.getString(_dateTimeFormatKeyFor(_activeUserId));
    final storedLocale = prefs.getString(_localeKeyFor(_activeUserId));
    final decodedFormat = _decodeDateTimeFormat(storedFormat);
    final decodedLocale = _decodeLocalePreference(storedLocale);
    if (_dateTimeFormat != decodedFormat ||
        _localePreference != decodedLocale) {
      _dateTimeFormat = decodedFormat;
      _localePreference = decodedLocale;
      notifyListeners();
    }
  }

  Future<void> setDateTimeFormat(SrrDateTimeDisplayFormat value) async {
    if (_dateTimeFormat == value) return;
    _dateTimeFormat = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _dateTimeFormatKeyFor(_activeUserId),
      value.storageValue,
    );
  }

  Future<void> setLocalePreference(SrrLocalePreference value) async {
    if (_localePreference == value) return;
    _localePreference = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_localeKeyFor(_activeUserId), value.storageValue);
  }

  String formatDateTime(
    DateTime value, {
    Locale? fallbackLocale,
    bool includeSeconds = true,
  }) {
    final local = value.toLocal();
    final localeTag = _resolveLocaleTag(fallbackLocale);
    switch (_dateTimeFormat) {
      case SrrDateTimeDisplayFormat.us24:
        return DateFormat('MM/dd/yyyy HH:mm:ss', localeTag).format(local);
      case SrrDateTimeDisplayFormat.us12:
        return DateFormat('MM/dd/yyyy hh:mm:ss a', localeTag).format(local);
      case SrrDateTimeDisplayFormat.dayMonth24:
        return DateFormat('dd/MM/yyyy HH:mm:ss', localeTag).format(local);
      case SrrDateTimeDisplayFormat.localeAdaptive:
        final date = DateFormat.yMd(localeTag).format(local);
        final time = includeSeconds
            ? DateFormat.Hms(localeTag).format(local)
            : DateFormat.Hm(localeTag).format(local);
        return '$date $time';
      case SrrDateTimeDisplayFormat.isoLocal:
        return DateFormat('yyyy-MM-dd HH:mm:ss').format(local);
    }
  }

  String formatIsoDateTime(
    String rawValue, {
    Locale? fallbackLocale,
    String empty = '-',
  }) {
    final trimmed = rawValue.trim();
    if (trimmed.isEmpty) return empty;
    final parsed = DateTime.tryParse(trimmed);
    if (parsed == null) return trimmed;
    return formatDateTime(parsed, fallbackLocale: fallbackLocale);
  }

  String _dateTimeFormatKeyFor(String? userId) {
    if (userId == null || userId.isEmpty) return _guestDateTimeFormatKey;
    return '$_userDateTimeFormatPrefix$userId';
  }

  String _localeKeyFor(String? userId) {
    if (userId == null || userId.isEmpty) return _guestLocaleKey;
    return '$_userLocalePrefix$userId';
  }

  String _resolveLocaleTag(Locale? fallbackLocale) {
    final preferred = _localePreference.locale ?? fallbackLocale;
    if (preferred == null) {
      return 'en_US';
    }
    final country = preferred.countryCode;
    if (country == null || country.isEmpty) {
      return preferred.languageCode;
    }
    return '${preferred.languageCode}_$country';
  }

  SrrDateTimeDisplayFormat _decodeDateTimeFormat(String? rawValue) {
    switch ((rawValue ?? '').trim().toLowerCase()) {
      case 'us_24':
        return SrrDateTimeDisplayFormat.us24;
      case 'us_12':
        return SrrDateTimeDisplayFormat.us12;
      case 'day_month_24':
        return SrrDateTimeDisplayFormat.dayMonth24;
      case 'locale_adaptive':
        return SrrDateTimeDisplayFormat.localeAdaptive;
      case 'iso_local':
        return SrrDateTimeDisplayFormat.isoLocal;
      default:
        return SrrDateTimeDisplayFormat.us24;
    }
  }

  SrrLocalePreference _decodeLocalePreference(String? rawValue) {
    switch ((rawValue ?? '').trim().toLowerCase()) {
      case 'system':
        return SrrLocalePreference.system;
      case 'en_us':
        return SrrLocalePreference.enUs;
      case 'en_gb':
        return SrrLocalePreference.enGb;
      case 'hi_in':
        return SrrLocalePreference.hiIn;
      case 'fr_fr':
        return SrrLocalePreference.frFr;
      default:
        return SrrLocalePreference.system;
    }
  }
}
