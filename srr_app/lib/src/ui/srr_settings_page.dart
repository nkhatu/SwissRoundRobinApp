// ---------------------------------------------------------------------------
// srr_app/lib/src/ui/srr_settings_page.dart
// ---------------------------------------------------------------------------
// 
// Purpose:
// - Provides app settings controls for theme, localization, and preferences.
// Architecture:
// - Presentation settings screen with user preference state management.
// - Uses controller abstractions so preference storage remains decoupled from UI.
// Author: Neil Khatu
// Copyright (c) The Khatu Family Trust
// 
import 'package:catu_framework/catu_framework.dart';
import 'package:flutter/material.dart';

import '../theme/srr_display_preferences_controller.dart';
import '../theme/srr_theme_controller.dart';
import 'srr_page_scaffold.dart';

class SrrSettingsPage extends StatefulWidget {
  const SrrSettingsPage({
    super.key,
    required this.appState,
    required this.themeController,
    required this.displayPreferencesController,
    required this.analytics,
    required this.appVersion,
    required this.appBuild,
  });

  final AppState appState;
  final SrrThemeController themeController;
  final SrrDisplayPreferencesController displayPreferencesController;
  final CrashAnalyticsService analytics;
  final String appVersion;
  final String appBuild;

  @override
  State<SrrSettingsPage> createState() => _SrrSettingsPageState();
}

class _SrrSettingsPageState extends State<SrrSettingsPage> {
  bool _updatingTheme = false;
  bool _updatingDateTimeFormat = false;
  bool _updatingLocale = false;

  Future<void> _setTheme(SrrThemeVariant variant) async {
    if (_updatingTheme || widget.themeController.variant == variant) return;
    setState(() => _updatingTheme = true);
    try {
      await widget.themeController.setVariant(variant);
      widget.analytics.logEvent('theme_changed:${variant.storageValue}');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Theme changed to ${variant.label}.')),
      );
    } catch (error, stackTrace) {
      widget.analytics.recordError(
        error,
        stackTrace,
        reason: 'theme_change_failed',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Unable to change theme: $error')));
    } finally {
      if (mounted) {
        setState(() => _updatingTheme = false);
      }
    }
  }

  Future<void> _setDateTimeFormat(SrrDateTimeDisplayFormat format) async {
    if (_updatingDateTimeFormat ||
        widget.displayPreferencesController.dateTimeFormat == format) {
      return;
    }
    setState(() => _updatingDateTimeFormat = true);
    try {
      await widget.displayPreferencesController.setDateTimeFormat(format);
      widget.analytics.logEvent(
        'datetime_format_changed:${format.storageValue}',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Date/time format changed to ${format.label}.')),
      );
    } catch (error, stackTrace) {
      widget.analytics.recordError(
        error,
        stackTrace,
        reason: 'datetime_format_change_failed',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to change date/time format: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _updatingDateTimeFormat = false);
      }
    }
  }

  Future<void> _setLocalePreference(SrrLocalePreference locale) async {
    if (_updatingLocale ||
        widget.displayPreferencesController.localePreference == locale) {
      return;
    }
    setState(() => _updatingLocale = true);
    try {
      await widget.displayPreferencesController.setLocalePreference(locale);
      widget.analytics.logEvent('locale_changed:${locale.storageValue}');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Localization changed to ${locale.label}.')),
      );
    } catch (error, stackTrace) {
      widget.analytics.recordError(
        error,
        stackTrace,
        reason: 'locale_change_failed',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to change localization: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _updatingLocale = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        widget.themeController,
        widget.displayPreferencesController,
      ]),
      builder: (context, _) {
        final variant = widget.themeController.variant;
        final dateTimeFormat =
            widget.displayPreferencesController.dateTimeFormat;
        final localePreference =
            widget.displayPreferencesController.localePreference;
        final sampleTimestamp = widget.displayPreferencesController
            .formatDateTime(
              DateTime(2024, 1, 1, 12, 0, 0),
              fallbackLocale: Localizations.localeOf(context),
            );
        return SrrPageScaffold(
          title: 'Settings',
          appState: widget.appState,
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 900),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: double.infinity,
                        child: Card(
                          elevation: 0,
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Text(
                                  'Visual Theme',
                                  textAlign: TextAlign.center,
                                  style: Theme.of(context).textTheme.titleLarge
                                      ?.copyWith(fontWeight: FontWeight.w700),
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  'Choose the look and feel for Carrom.',
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 12),
                                ConstrainedBox(
                                  constraints: const BoxConstraints(
                                    maxWidth: 360,
                                  ),
                                  child:
                                      DropdownButtonFormField<SrrThemeVariant>(
                                        initialValue: variant,
                                        decoration: const InputDecoration(
                                          labelText: 'Theme variant',
                                        ),
                                        items: SrrThemeVariant.values
                                            .map(
                                              (entry) => DropdownMenuItem(
                                                value: entry,
                                                child: Text(entry.label),
                                              ),
                                            )
                                            .toList(growable: false),
                                        onChanged: _updatingTheme
                                            ? null
                                            : (value) {
                                                if (value == null) return;
                                                _setTheme(value);
                                              },
                                      ),
                                ),
                                const SizedBox(height: 12),
                                Wrap(
                                  alignment: WrapAlignment.center,
                                  spacing: 10,
                                  runSpacing: 10,
                                  children: SrrThemeVariant.values
                                      .map(
                                        (entry) => _ThemePreviewPill(
                                          variant: entry,
                                          selected: entry == variant,
                                          onTap: _updatingTheme
                                              ? null
                                              : () => _setTheme(entry),
                                        ),
                                      )
                                      .toList(growable: false),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: Card(
                          elevation: 0,
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Text(
                                  'Date & Time Display',
                                  textAlign: TextAlign.center,
                                  style: Theme.of(context).textTheme.titleLarge
                                      ?.copyWith(fontWeight: FontWeight.w700),
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  'Set the date/time format and localization for all pages.',
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 12),
                                ConstrainedBox(
                                  constraints: const BoxConstraints(
                                    maxWidth: 420,
                                  ),
                                  child:
                                      DropdownButtonFormField<
                                        SrrDateTimeDisplayFormat
                                      >(
                                        initialValue: dateTimeFormat,
                                        decoration: const InputDecoration(
                                          labelText: 'Date/time format',
                                        ),
                                        items: SrrDateTimeDisplayFormat.values
                                            .map(
                                              (entry) => DropdownMenuItem(
                                                value: entry,
                                                child: Text(entry.label),
                                              ),
                                            )
                                            .toList(growable: false),
                                        onChanged: _updatingDateTimeFormat
                                            ? null
                                            : (value) {
                                                if (value == null) return;
                                                _setDateTimeFormat(value);
                                              },
                                      ),
                                ),
                                const SizedBox(height: 10),
                                ConstrainedBox(
                                  constraints: const BoxConstraints(
                                    maxWidth: 420,
                                  ),
                                  child:
                                      DropdownButtonFormField<
                                        SrrLocalePreference
                                      >(
                                        initialValue: localePreference,
                                        decoration: const InputDecoration(
                                          labelText: 'Localization',
                                        ),
                                        items: SrrLocalePreference.values
                                            .map(
                                              (entry) => DropdownMenuItem(
                                                value: entry,
                                                child: Text(entry.label),
                                              ),
                                            )
                                            .toList(growable: false),
                                        onChanged: _updatingLocale
                                            ? null
                                            : (value) {
                                                if (value == null) return;
                                                _setLocalePreference(value);
                                              },
                                      ),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  'Sample: $sampleTimestamp',
                                  textAlign: TextAlign.center,
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: Card(
                          elevation: 0,
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              children: [
                                const Icon(Icons.info_outline),
                                const SizedBox(height: 8),
                                const Text(
                                  'App Version',
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Version ${widget.appVersion} (${widget.appBuild})',
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ThemePreviewPill extends StatelessWidget {
  const _ThemePreviewPill({
    required this.variant,
    required this.selected,
    this.onTap,
  });

  final SrrThemeVariant variant;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = _colorsFor(variant);
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? scheme.primary : scheme.outlineVariant,
            width: selected ? 2 : 1,
          ),
          color: scheme.surfaceContainerHigh,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ...colors.map(
              (color) => Container(
                width: 12,
                height: 12,
                margin: const EdgeInsets.only(right: 4),
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
            ),
            const SizedBox(width: 4),
            Text(variant.label),
          ],
        ),
      ),
    );
  }

  List<Color> _colorsFor(SrrThemeVariant variant) {
    switch (variant) {
      case SrrThemeVariant.purple:
        return const [Color(0xFF7B3AED), Color(0xFFB04DE8), Color(0xFFD9C8FF)];
      case SrrThemeVariant.orange:
        return const [Color(0xFFE56A1A), Color(0xFFF0A833), Color(0xFFFDE2B1)];
      case SrrThemeVariant.pista:
        return const [Color(0xFF6BAF4B), Color(0xFF9CCE6C), Color(0xFFD8F2BC)];
      case SrrThemeVariant.dark:
        return const [Color(0xFF0E1415), Color(0xFF1D2B2D), Color(0xFF6FD8B3)];
      case SrrThemeVariant.contrast:
        return const [Color(0xFF0B0B0B), Color(0xFFFFFFFF), Color(0xFFC13F2A)];
      case SrrThemeVariant.blue:
        return const [Color(0xFF1E56B1), Color(0xFF4E8FE8), Color(0xFFD4E5FF)];
      case SrrThemeVariant.turquoise:
        return const [Color(0xFF0F8F87), Color(0xFF33C9B8), Color(0xFFC6F3ED)];
    }
  }
}
