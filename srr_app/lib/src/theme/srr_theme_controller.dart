// ---------------------------------------------------------------------------
// srr_app/lib/src/theme/srr_theme_controller.dart
// ---------------------------------------------------------------------------
// 
// Purpose:
// - Persists and applies selected theme variants for each signed-in user.
// Architecture:
// - Controller layer that owns theme preference state and persistence behavior.
// - Separates visual configuration state from feature and routing logic.
// Author: Neil Khatu
// Copyright (c) The Khatu Family Trust
// 
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum SrrThemeVariant { purple, orange, pista, dark, contrast, blue, turquoise }

extension SrrThemeVariantX on SrrThemeVariant {
  String get storageValue {
    switch (this) {
      case SrrThemeVariant.purple:
        return 'purple';
      case SrrThemeVariant.orange:
        return 'orange';
      case SrrThemeVariant.pista:
        return 'pista';
      case SrrThemeVariant.dark:
        return 'dark';
      case SrrThemeVariant.contrast:
        return 'contrast';
      case SrrThemeVariant.blue:
        return 'blue';
      case SrrThemeVariant.turquoise:
        return 'turquoise';
    }
  }

  String get label {
    switch (this) {
      case SrrThemeVariant.purple:
        return 'Purple';
      case SrrThemeVariant.orange:
        return 'Orange';
      case SrrThemeVariant.pista:
        return 'Pista';
      case SrrThemeVariant.dark:
        return 'Dark';
      case SrrThemeVariant.contrast:
        return 'Contrast (Contract)';
      case SrrThemeVariant.blue:
        return 'Blue';
      case SrrThemeVariant.turquoise:
        return 'Turquoise (Torquise)';
    }
  }
}

class SrrThemeController extends ChangeNotifier {
  static const _guestThemeKey = 'srr_theme_guest';
  static const _userThemePrefix = 'srr_theme_user_';

  SrrThemeVariant _variant = SrrThemeVariant.blue;
  String? _activeUserId;

  SrrThemeVariant get variant => _variant;

  Future<void> load({String? userId}) async {
    _activeUserId = userId?.trim();
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_keyFor(_activeUserId));
    final resolved = _decode(stored);
    if (_variant != resolved) {
      _variant = resolved;
      notifyListeners();
    }
  }

  Future<void> setVariant(SrrThemeVariant variant) async {
    if (_variant == variant) return;
    _variant = variant;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyFor(_activeUserId), variant.storageValue);
  }

  String _keyFor(String? userId) {
    if (userId == null || userId.isEmpty) return _guestThemeKey;
    return '$_userThemePrefix$userId';
  }

  SrrThemeVariant _decode(String? value) {
    switch ((value ?? '').trim().toLowerCase()) {
      case 'purple':
        return SrrThemeVariant.purple;
      case 'orange':
        return SrrThemeVariant.orange;
      case 'pista':
        return SrrThemeVariant.pista;
      case 'dark':
        return SrrThemeVariant.dark;
      case 'contrast':
      case 'contract':
      case 'high_contrast':
        return SrrThemeVariant.contrast;
      case 'blue':
        return SrrThemeVariant.blue;
      case 'turquoise':
      case 'torquise':
        return SrrThemeVariant.turquoise;
      default:
        return SrrThemeVariant.blue;
    }
  }
}
