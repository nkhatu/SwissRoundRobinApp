// ---------------------------------------------------------------------------
// srr_app/lib/src/di/srr_dependencies.dart
// ---------------------------------------------------------------------------
// 
// Purpose:
// - Builds and exposes the SRR dependency graph for app bootstrap.
// Architecture:
// - Dependency-injection composition layer wiring API clients and repositories.
// - Provides a single construction boundary for app-wide service objects.
// Author: Neil Khatu
// Copyright (c) The Khatu Family Trust
// 
import 'package:catu_framework/catu_framework.dart';

import '../api/srr_api_client.dart';
import '../auth/srr_auth_service.dart';
import '../repositories/srr_dashboard_repository.dart';
import '../repositories/srr_player_repository.dart';
import '../repositories/srr_tournament_repository.dart';

class SrrDependencies {
  const SrrDependencies({
    required this.apiClient,
    required this.authService,
    required this.framework,
    required this.dashboardRepository,
    required this.playerRepository,
    required this.tournamentRepository,
  });

  final SrrApiClient apiClient;
  final SrrAuthService authService;
  final AppFrameworkDependencies framework;
  final SrrDashboardRepository dashboardRepository;
  final SrrPlayerRepository playerRepository;
  final SrrTournamentRepository tournamentRepository;

  static Future<SrrDependencies> bootstrap({required String apiBaseUrl}) async {
    final apiClient = SrrApiClient(baseUrl: apiBaseUrl);
    await apiClient.bootstrapSession();

    final authService = SrrAuthService(apiClient);
    final framework = AppFrameworkDependencies(
      authService: authService,
      analytics: InMemoryCrashAnalyticsService(),
    );

    return SrrDependencies(
      apiClient: apiClient,
      authService: authService,
      framework: framework,
      dashboardRepository: SrrDashboardRepository(apiClient),
      playerRepository: SrrPlayerRepository(apiClient),
      tournamentRepository: SrrTournamentRepository(apiClient),
    );
  }
}
