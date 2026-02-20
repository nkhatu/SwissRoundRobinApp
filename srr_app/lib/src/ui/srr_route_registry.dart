// ---------------------------------------------------------------------------
// srr_app/lib/src/ui/srr_route_registry.dart
// ---------------------------------------------------------------------------
//
// Purpose:
// - Builds the SRR route table and resolves page dependencies per route.
// Architecture:
// - Presentation composition module that centralizes route wiring.
// - Keeps route graph construction out of main.dart and app shell widgets.
// Author: Neil Khatu
// Copyright (c) The Khatu Family Trust
//
import 'package:catu_framework/catu_framework.dart';
import 'package:flutter/material.dart';

import '../api/srr_api_client.dart';
import '../repositories/srr_dashboard_repository.dart';
import '../repositories/srr_player_repository.dart';
import '../repositories/srr_tournament_repository.dart';
import '../theme/srr_display_preferences_controller.dart';
import '../theme/srr_theme_controller.dart';
import 'srr_bootstrap_page.dart';
import 'srr_complete_profile_page.dart';
import 'srr_copyright_page.dart';
import 'srr_feedback_page.dart';
import 'srr_home_page.dart';
import 'srr_privacy_page.dart';
import 'srr_ranking_upload_page.dart';
import 'srr_register_page.dart';
import 'srr_round_matchup_page.dart';
import 'srr_routes.dart';
import 'srr_settings_page.dart';
import 'srr_sign_in_page.dart';
import 'srr_support_page.dart';
import 'srr_tournament_groups_page.dart';
import 'srr_tournament_seeding_page.dart';
import 'srr_tournament_setup_page.dart';
import 'srr_upload_page.dart';

class SrrRouteRegistry {
  const SrrRouteRegistry();

  Map<String, WidgetBuilder> buildRoutes({
    required AppState appState,
    required SrrApiClient apiClient,
    required AppFrameworkDependencies framework,
    required SrrDashboardRepository dashboardRepository,
    required SrrPlayerRepository playerRepository,
    required SrrTournamentRepository tournamentRepository,
    required SrrThemeController themeController,
    required SrrDisplayPreferencesController displayPreferencesController,
    required String appVersion,
    required String appBuild,
  }) {
    return {
      AppRoutes.bootstrap: (_) =>
          SrrBootstrapPage(appState: appState, apiClient: apiClient),
      AppRoutes.signIn: (_) => SrrSignInPage(appState: appState),
      AppRoutes.register: (_) => SrrRegisterPage(appState: appState),
      AppRoutes.home: (_) => SrrHomePage(
        appState: appState,
        apiClient: apiClient,
        dashboardRepository: dashboardRepository,
        analytics: framework.analytics,
        displayPreferencesController: displayPreferencesController,
      ),
      SrrRoutes.tournamentSetup: (_) => SrrTournamentSetupPage(
        appState: appState,
        apiClient: apiClient,
        tournamentRepository: tournamentRepository,
        displayPreferencesController: displayPreferencesController,
      ),
      SrrRoutes.tournamentSeeding: (context) {
        final args = ModalRoute.of(context)?.settings.arguments;
        final initialTournamentId = args is SrrTournamentSeedingPageArguments
            ? args.tournamentId
            : null;
        return SrrTournamentSeedingPage(
          appState: appState,
          apiClient: apiClient,
          tournamentRepository: tournamentRepository,
          displayPreferencesController: displayPreferencesController,
          initialTournamentId: initialTournamentId,
        );
      },
      SrrRoutes.tournamentGroups: (context) {
        final args = ModalRoute.of(context)?.settings.arguments;
        final initialTournamentId = args is SrrTournamentGroupsPageArguments
            ? args.tournamentId
            : null;
        return SrrTournamentGroupsPage(
          appState: appState,
          apiClient: apiClient,
          tournamentRepository: tournamentRepository,
          displayPreferencesController: displayPreferencesController,
          initialTournamentId: initialTournamentId,
        );
      },
      SrrRoutes.genericUpload: (_) => SrrUploadPage(
        appState: appState,
        apiClient: apiClient,
        playerRepository: playerRepository,
        tournamentRepository: tournamentRepository,
        displayPreferencesController: displayPreferencesController,
      ),
      SrrRoutes.roundMatchup: (context) {
        final args = ModalRoute.of(context)?.settings.arguments;
        final initialTournamentId = args is SrrRoundMatchupPageArguments
            ? args.tournamentId
            : null;
        return SrrRoundMatchupPage(
          appState: appState,
          apiClient: apiClient,
          tournamentRepository: tournamentRepository,
          initialTournamentId: initialTournamentId,
        );
      },
      SrrRoutes.completeProfile: (_) =>
          SrrCompleteProfilePage(appState: appState, apiClient: apiClient),
      SrrRoutes.currentNationalRanking: (_) => SrrRankingUploadPage(
        appState: appState,
        apiClient: apiClient,
        tournamentRepository: tournamentRepository,
        displayPreferencesController: displayPreferencesController,
        readOnly: true,
      ),
      AppRoutes.profile: (_) => UserProfilePage(appState: appState),
      AppRoutes.inbox: (_) => InboxPage(appState: appState),
      AppRoutes.settings: (_) => SrrSettingsPage(
        appState: appState,
        themeController: themeController,
        displayPreferencesController: displayPreferencesController,
        analytics: framework.analytics,
        appVersion: appVersion,
        appBuild: appBuild,
      ),
      AppRoutes.support: (_) => SrrSupportPage(appState: appState),
      AppRoutes.feedback: (_) => SrrFeedbackPage(
        appState: appState,
        apiClient: apiClient,
        analytics: framework.analytics,
      ),
      AppRoutes.privacy: (_) => SrrPrivacyPage(appState: appState),
      AppRoutes.copyright: (_) => SrrCopyrightPage(appState: appState),
    };
  }
}
