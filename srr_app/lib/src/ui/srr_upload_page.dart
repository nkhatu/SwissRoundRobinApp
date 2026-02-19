// ---------------------------------------------------------------------------
// srr_app/lib/src/ui/srr_upload_page.dart
// ---------------------------------------------------------------------------
// 
// Purpose:
// - Routes generic upload context to player upload or ranking upload feature pages.
// Architecture:
// - Presentation router that maps upload intent to dedicated feature components.
// - Keeps upload context selection logic centralized and reusable.
// Author: Neil Khatu
// Copyright (c) The Khatu Family Trust
// 
import 'package:catu_framework/catu_framework.dart';
import 'package:flutter/material.dart';

import '../api/srr_api_client.dart';
import '../repositories/srr_player_repository.dart';
import '../repositories/srr_tournament_repository.dart';
import '../theme/srr_display_preferences_controller.dart';
import 'srr_player_upload_page.dart';
import 'srr_ranking_upload_page.dart';

enum SrrUploadContext { players, ranking }

class SrrUploadPageArguments {
  const SrrUploadPageArguments({required this.context, this.tournamentId});

  final SrrUploadContext context;
  final int? tournamentId;
}

class SrrUploadPage extends StatelessWidget {
  const SrrUploadPage({
    super.key,
    required this.appState,
    required this.apiClient,
    required this.playerRepository,
    required this.tournamentRepository,
    required this.displayPreferencesController,
  });

  final AppState appState;
  final SrrApiClient apiClient;
  final SrrPlayerRepository playerRepository;
  final SrrTournamentRepository tournamentRepository;
  final SrrDisplayPreferencesController displayPreferencesController;

  @override
  Widget build(BuildContext context) {
    final routeArguments = ModalRoute.of(context)?.settings.arguments;
    final uploadContext = routeArguments is SrrUploadPageArguments
        ? routeArguments.context
        : SrrUploadContext.players;

    switch (uploadContext) {
      case SrrUploadContext.players:
        return SrrPlayerUploadPage(
          appState: appState,
          apiClient: apiClient,
          playerRepository: playerRepository,
          tournamentRepository: tournamentRepository,
          displayPreferencesController: displayPreferencesController,
          initialTournamentId: routeArguments is SrrUploadPageArguments
              ? routeArguments.tournamentId
              : null,
        );
      case SrrUploadContext.ranking:
        return SrrRankingUploadPage(
          appState: appState,
          apiClient: apiClient,
          tournamentRepository: tournamentRepository,
          displayPreferencesController: displayPreferencesController,
          initialTournamentId: routeArguments is SrrUploadPageArguments
              ? routeArguments.tournamentId
              : null,
        );
    }
  }
}
