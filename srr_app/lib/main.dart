// ---------------------------------------------------------------------------
// srr_app/lib/main.dart
// ---------------------------------------------------------------------------
//
// Purpose:
// - Bootstraps the app, initializes Firebase, and wires the full route graph.
// Architecture:
// - Application entrypoint that composes dependencies, themes, and localization.
// - Delegates feature behavior to page modules and repository-backed services.
// Author: Neil Khatu
// Copyright (c) The Khatu Family Trust
//
import 'package:catu_framework/catu_framework.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:google_fonts/google_fonts.dart';

import 'src/config/srr_app_config.dart';
import 'src/di/srr_dependencies.dart';
import 'src/theme/srr_display_preferences_controller.dart';
import 'src/theme/srr_theme_controller.dart';
import 'src/theme/srr_split_action_button_theme.dart';
import 'src/ui/srr_bootstrap_page.dart';
import 'src/ui/srr_complete_profile_page.dart';
import 'src/ui/srr_copyright_page.dart';
import 'src/ui/srr_feedback_page.dart';
import 'src/ui/srr_home_page.dart';
import 'src/ui/srr_privacy_page.dart';
import 'src/ui/srr_register_page.dart';
import 'src/ui/srr_ranking_upload_page.dart';
import 'src/ui/srr_tournament_groups_page.dart';
import 'src/ui/srr_round_matchup_page.dart';
import 'src/ui/srr_routes.dart';
import 'src/ui/srr_settings_page.dart';
import 'src/ui/srr_sign_in_page.dart';
import 'src/ui/srr_support_page.dart';
import 'src/ui/srr_tournament_seeding_page.dart';
import 'src/ui/srr_tournament_setup_page.dart';
import 'src/ui/srr_upload_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _initializeFirebase();

  final dependencies = await SrrDependencies.bootstrap(
    apiBaseUrl: _resolveApiBaseUrl(),
  );

  runApp(SrrTournamentApp(dependencies: dependencies));
}

Future<void> _initializeFirebase() async {
  if (!kIsWeb) {
    await Firebase.initializeApp();
    return;
  }

  const apiKey = String.fromEnvironment('FIREBASE_WEB_API_KEY');
  const appId = String.fromEnvironment('FIREBASE_WEB_APP_ID');
  const messagingSenderId = String.fromEnvironment(
    'FIREBASE_WEB_MESSAGING_SENDER_ID',
  );
  const projectId = String.fromEnvironment('FIREBASE_WEB_PROJECT_ID');
  const authDomain = String.fromEnvironment('FIREBASE_WEB_AUTH_DOMAIN');
  const storageBucket = String.fromEnvironment('FIREBASE_WEB_STORAGE_BUCKET');
  const measurementId = String.fromEnvironment('FIREBASE_WEB_MEASUREMENT_ID');

  if (apiKey.isEmpty ||
      appId.isEmpty ||
      messagingSenderId.isEmpty ||
      projectId.isEmpty) {
    throw StateError(
      'Missing Firebase web config. Provide FIREBASE_WEB_API_KEY, '
      'FIREBASE_WEB_APP_ID, FIREBASE_WEB_MESSAGING_SENDER_ID, and FIREBASE_WEB_PROJECT_ID.',
    );
  }

  final defaultAuthDomain = '$projectId.firebaseapp.com';
  final resolvedAuthDomain = authDomain.isNotEmpty
      ? authDomain
      : defaultAuthDomain;

  await Firebase.initializeApp(
    options: FirebaseOptions(
      apiKey: apiKey,
      appId: appId,
      messagingSenderId: messagingSenderId,
      projectId: projectId,
      authDomain: resolvedAuthDomain,
      storageBucket: storageBucket.isEmpty ? null : storageBucket,
      measurementId: measurementId.isEmpty ? null : measurementId,
    ),
  );
}

String _resolveApiBaseUrl() {
  const configured = String.fromEnvironment('SRR_API_URL');
  if (configured.isNotEmpty) return configured;

  return 'https://example.com/api';
}

class SrrTournamentApp extends StatefulWidget {
  const SrrTournamentApp({super.key, required this.dependencies});

  final SrrDependencies dependencies;

  @override
  State<SrrTournamentApp> createState() => _SrrTournamentAppState();
}

class _SrrTournamentAppState extends State<SrrTournamentApp> {
  late final AppState _appState;
  late final SrrThemeController _themeController;
  late final SrrDisplayPreferencesController _displayPreferencesController;

  @override
  void initState() {
    super.initState();
    installCrashAnalyticsHandlers(widget.dependencies.framework.analytics);

    _appState = widget.dependencies.framework.createAppState();
    _themeController = SrrThemeController();
    _displayPreferencesController = SrrDisplayPreferencesController();

    _appState.addListener(_syncThemeUser);
    _syncThemeUser();
  }

  @override
  void dispose() {
    _appState.removeListener(_syncThemeUser);
    _appState.dispose();
    _themeController.dispose();
    _displayPreferencesController.dispose();
    super.dispose();
  }

  void _syncThemeUser() {
    final userId = _appState.user?.id;
    _themeController.load(userId: userId);
    _displayPreferencesController.load(userId: userId);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        _themeController,
        _displayPreferencesController,
      ]),
      builder: (context, _) {
        return MaterialApp(
          title: SrrAppConfig.appName,
          debugShowCheckedModeBanner: false,
          theme: _buildCarromTheme(_themeController.variant),
          locale: _displayPreferencesController.locale,
          supportedLocales: SrrDisplayPreferencesController.supportedLocales,
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          builder: (context, child) {
            final content = child ?? const SizedBox.shrink();
            if (!kIsWeb) return content;
            return SelectionArea(child: content);
          },
          initialRoute: AppRoutes.bootstrap,
          routes: {
            AppRoutes.bootstrap: (_) => SrrBootstrapPage(
              appState: _appState,
              apiClient: widget.dependencies.apiClient,
            ),
            AppRoutes.signIn: (_) => SrrSignInPage(appState: _appState),
            AppRoutes.register: (_) => SrrRegisterPage(appState: _appState),
            AppRoutes.home: (_) => SrrHomePage(
              appState: _appState,
              apiClient: widget.dependencies.apiClient,
              dashboardRepository: widget.dependencies.dashboardRepository,
              analytics: widget.dependencies.framework.analytics,
              displayPreferencesController: _displayPreferencesController,
            ),
            SrrRoutes.tournamentSetup: (_) => SrrTournamentSetupPage(
              appState: _appState,
              apiClient: widget.dependencies.apiClient,
              tournamentRepository: widget.dependencies.tournamentRepository,
              displayPreferencesController: _displayPreferencesController,
            ),
            SrrRoutes.tournamentSeeding: (context) {
              final args = ModalRoute.of(context)?.settings.arguments;
              final initialTournamentId =
                  args is SrrTournamentSeedingPageArguments
                  ? args.tournamentId
                  : null;
              return SrrTournamentSeedingPage(
                appState: _appState,
                apiClient: widget.dependencies.apiClient,
                tournamentRepository: widget.dependencies.tournamentRepository,
                displayPreferencesController: _displayPreferencesController,
                initialTournamentId: initialTournamentId,
              );
            },
            SrrRoutes.tournamentGroups: (context) {
              final args = ModalRoute.of(context)?.settings.arguments;
              final initialTournamentId =
                  args is SrrTournamentGroupsPageArguments
                  ? args.tournamentId
                  : null;
              return SrrTournamentGroupsPage(
                appState: _appState,
                apiClient: widget.dependencies.apiClient,
                tournamentRepository: widget.dependencies.tournamentRepository,
                displayPreferencesController: _displayPreferencesController,
                initialTournamentId: initialTournamentId,
              );
            },
            SrrRoutes.genericUpload: (_) => SrrUploadPage(
              appState: _appState,
              apiClient: widget.dependencies.apiClient,
              playerRepository: widget.dependencies.playerRepository,
              tournamentRepository: widget.dependencies.tournamentRepository,
              displayPreferencesController: _displayPreferencesController,
            ),
            SrrRoutes.roundMatchup: (context) {
              final args = ModalRoute.of(context)?.settings.arguments;
              final initialTournamentId = args is SrrRoundMatchupPageArguments
                  ? args.tournamentId
                  : null;
              return SrrRoundMatchupPage(
                appState: _appState,
                apiClient: widget.dependencies.apiClient,
                tournamentRepository: widget.dependencies.tournamentRepository,
                initialTournamentId: initialTournamentId,
              );
            },
            SrrRoutes.completeProfile: (_) => SrrCompleteProfilePage(
              appState: _appState,
              apiClient: widget.dependencies.apiClient,
            ),
            SrrRoutes.currentNationalRanking: (_) => SrrRankingUploadPage(
              appState: _appState,
              apiClient: widget.dependencies.apiClient,
              tournamentRepository: widget.dependencies.tournamentRepository,
              displayPreferencesController: _displayPreferencesController,
              readOnly: true,
            ),
            AppRoutes.profile: (_) => UserProfilePage(appState: _appState),
            AppRoutes.inbox: (_) => InboxPage(appState: _appState),
            AppRoutes.settings: (_) => SrrSettingsPage(
              appState: _appState,
              themeController: _themeController,
              displayPreferencesController: _displayPreferencesController,
              analytics: widget.dependencies.framework.analytics,
              appVersion: SrrAppConfig.appVersion,
              appBuild: SrrAppConfig.appBuild,
            ),
            AppRoutes.support: (_) => SrrSupportPage(appState: _appState),
            AppRoutes.feedback: (_) => SrrFeedbackPage(
              appState: _appState,
              apiClient: widget.dependencies.apiClient,
              analytics: widget.dependencies.framework.analytics,
            ),
            AppRoutes.privacy: (_) => SrrPrivacyPage(appState: _appState),
            AppRoutes.copyright: (_) => SrrCopyrightPage(appState: _appState),
          },
        );
      },
    );
  }
}

ThemeData _buildCarromTheme(SrrThemeVariant variant) {
  final colorScheme = _colorSchemeForVariant(variant);
  final brightness = colorScheme.brightness;
  final isDark = brightness == Brightness.dark;

  final baseText = GoogleFonts.plusJakartaSansTextTheme(
    ThemeData(brightness: brightness, useMaterial3: true).textTheme,
  );
  final headlineFont = GoogleFonts.dmSerifDisplayTextTheme(baseText);

  final textTheme = baseText.copyWith(
    displayLarge: headlineFont.displayLarge?.copyWith(
      fontWeight: FontWeight.w700,
      letterSpacing: 0.3,
    ),
    displayMedium: headlineFont.displayMedium?.copyWith(
      fontWeight: FontWeight.w700,
      letterSpacing: 0.2,
    ),
    headlineLarge: headlineFont.headlineLarge?.copyWith(
      fontWeight: FontWeight.w700,
      letterSpacing: 0.2,
    ),
    headlineMedium: headlineFont.headlineMedium?.copyWith(
      fontWeight: FontWeight.w700,
      letterSpacing: 0.2,
    ),
    titleLarge: baseText.titleLarge?.copyWith(
      fontWeight: FontWeight.w700,
      letterSpacing: 0.15,
    ),
    titleMedium: baseText.titleMedium?.copyWith(
      fontWeight: FontWeight.w600,
      letterSpacing: 0.1,
    ),
    bodyLarge: baseText.bodyLarge?.copyWith(height: 1.35),
    bodyMedium: baseText.bodyMedium?.copyWith(height: 1.35),
  );

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: colorScheme.surface,
    textTheme: textTheme,
    appBarTheme: AppBarTheme(
      backgroundColor: colorScheme.primary,
      foregroundColor: colorScheme.onPrimary,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: textTheme.titleLarge?.copyWith(
        color: colorScheme.onPrimary,
        fontWeight: FontWeight.w700,
        fontSize: 22,
      ),
    ),
    cardTheme: CardThemeData(
      elevation: isDark ? 0 : 1,
      color: colorScheme.surfaceContainerLow,
      shadowColor: colorScheme.shadow.withValues(alpha: isDark ? 0.0 : 0.15),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      margin: EdgeInsets.zero,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        textStyle: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
        minimumSize: const Size(0, 46),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: colorScheme.primary,
        textStyle: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
        side: BorderSide(color: colorScheme.outline),
        minimumSize: const Size(0, 46),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: colorScheme.surfaceContainerHigh,
      labelStyle: textTheme.bodyMedium?.copyWith(
        color: colorScheme.onSurfaceVariant,
      ),
      hintStyle: textTheme.bodyMedium?.copyWith(
        color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: colorScheme.outlineVariant),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: colorScheme.outlineVariant),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: colorScheme.primary, width: 1.4),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: colorScheme.error),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: colorScheme.secondaryContainer,
      selectedColor: colorScheme.primaryContainer,
      secondarySelectedColor: colorScheme.primaryContainer,
      labelStyle: textTheme.labelMedium?.copyWith(
        color: colorScheme.onSecondaryContainer,
        fontWeight: FontWeight.w600,
      ),
      side: BorderSide(color: colorScheme.outlineVariant),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: colorScheme.inverseSurface,
      contentTextStyle: textTheme.bodyMedium?.copyWith(
        color: colorScheme.onInverseSurface,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      behavior: SnackBarBehavior.floating,
    ),
    dividerColor: colorScheme.outlineVariant,
    extensions: <ThemeExtension<dynamic>>[
      SrrSplitActionButtonTheme.fromColorScheme(colorScheme),
    ],
  );
}

ColorScheme _colorSchemeForVariant(SrrThemeVariant variant) {
  switch (variant) {
    case SrrThemeVariant.purple:
      return ColorScheme.fromSeed(
        seedColor: const Color(0xFF6E44FF),
        brightness: Brightness.light,
      ).copyWith(
        primary: const Color(0xFF5D35D6),
        secondary: const Color(0xFF9B59B6),
        tertiary: const Color(0xFF385FA9),
        surface: const Color(0xFFF8F5FF),
      );
    case SrrThemeVariant.orange:
      return ColorScheme.fromSeed(
        seedColor: const Color(0xFFE67E22),
        brightness: Brightness.light,
      ).copyWith(
        primary: const Color(0xFFD05A12),
        secondary: const Color(0xFF8F5B2A),
        tertiary: const Color(0xFF3A7288),
        surface: const Color(0xFFFFF8EF),
      );
    case SrrThemeVariant.pista:
      return ColorScheme.fromSeed(
        seedColor: const Color(0xFF7BAF45),
        brightness: Brightness.light,
      ).copyWith(
        primary: const Color(0xFF4A8A2E),
        secondary: const Color(0xFF2E7A64),
        tertiary: const Color(0xFF6D5B9C),
        surface: const Color(0xFFF6FAF0),
      );
    case SrrThemeVariant.dark:
      return ColorScheme.fromSeed(
        seedColor: const Color(0xFF4EB89A),
        brightness: Brightness.dark,
      ).copyWith(
        primary: const Color(0xFF73DCC0),
        secondary: const Color(0xFFFFB290),
        tertiary: const Color(0xFF9AB9FF),
        surface: const Color(0xFF0F1317),
      );
    case SrrThemeVariant.contrast:
      return const ColorScheme(
        brightness: Brightness.light,
        primary: Color(0xFF111111),
        onPrimary: Color(0xFFFFFFFF),
        secondary: Color(0xFF003DA5),
        onSecondary: Color(0xFFFFFFFF),
        tertiary: Color(0xFFC63D00),
        onTertiary: Color(0xFFFFFFFF),
        error: Color(0xFF8A0000),
        onError: Color(0xFFFFFFFF),
        surface: Color(0xFFFFFFFF),
        onSurface: Color(0xFF111111),
        surfaceContainerLowest: Color(0xFFFFFFFF),
        surfaceContainerLow: Color(0xFFF2F2F2),
        surfaceContainer: Color(0xFFE8E8E8),
        surfaceContainerHigh: Color(0xFFDDDDDD),
        surfaceContainerHighest: Color(0xFFD1D1D1),
        onSurfaceVariant: Color(0xFF1A1A1A),
        outline: Color(0xFF2E2E2E),
        outlineVariant: Color(0xFF616161),
      );
    case SrrThemeVariant.blue:
      return ColorScheme.fromSeed(
        seedColor: const Color(0xFF2F80ED),
        brightness: Brightness.light,
      ).copyWith(
        primary: const Color(0xFF235FBE),
        secondary: const Color(0xFF3A7C96),
        tertiary: const Color(0xFF7452A2),
        surface: const Color(0xFFF1F6FF),
      );
    case SrrThemeVariant.turquoise:
      return ColorScheme.fromSeed(
        seedColor: const Color(0xFF12A39C),
        brightness: Brightness.light,
      ).copyWith(
        primary: const Color(0xFF0F817A),
        secondary: const Color(0xFF2F768A),
        tertiary: const Color(0xFF4666A5),
        surface: const Color(0xFFEFFAF8),
      );
  }
}
