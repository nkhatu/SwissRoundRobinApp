// ---------------------------------------------------------------------------
// srr_app/lib/src/di/srr_dependencies.dart
// ---------------------------------------------------------------------------
//
// Purpose:
// - Builds and exposes the SRR dependency graph for app bootstrap.
// Architecture:
// - Dependency-injection composition layer wiring feature repositories and services.
// - Provides a single construction boundary for app-wide controllers.
// Author: Neil Khatu
// Copyright (c) The Khatu Family Trust
//
import 'package:catu_framework/catu_framework.dart';

import '../api/auth_api_client.dart';
import '../api/srr_api_transport.dart';
import '../api/srr_dashboard_api.dart';
import '../api/srr_player_api.dart';
import '../api/srr_tournament_api.dart';
import '../auth/srr_auth_service.dart';
import '../repositories/srr_auth_repository.dart';
import '../repositories/srr_dashboard_repository.dart';
import '../repositories/srr_player_repository.dart';
import '../repositories/srr_tournament_repository.dart';
import '../theme/srr_display_preferences_controller.dart';
import '../theme/srr_theme_controller.dart';
import '../theme/srr_theme_factory.dart';
import '../theme/srr_user_preferences_coordinator.dart';
import '../ui/routes/srr_route_registry.dart';

class SrrDependencies {
  const SrrDependencies({
    required this.authService,
    required this.framework,
    required this.appState,
    required this.dashboardRepository,
    required this.playerRepository,
    required this.tournamentRepository,
    required this.themeController,
    required this.displayPreferencesController,
    required this.themeFactory,
    required this.routeRegistry,
    required this.userPreferencesCoordinator,
  });

  final SrrAuthService authService;
  final AppFrameworkDependencies framework;
  final AppState appState;
  final SrrDashboardRepository dashboardRepository;
  final SrrPlayerRepository playerRepository;
  final SrrTournamentRepository tournamentRepository;
  final SrrThemeController themeController;
  final SrrDisplayPreferencesController displayPreferencesController;
  final SrrThemeFactory themeFactory;
  final SrrRouteRegistry routeRegistry;
  final SrrUserPreferencesCoordinator userPreferencesCoordinator;

  static Future<SrrDependencies> bootstrap({required String apiBaseUrl}) async {
    final transport = SrrApiTransport(baseUrl: apiBaseUrl);
    final authRepository = SrrAuthRepository(AuthApiClient(transport));
    await authRepository.bootstrapSession();

    final authService = SrrAuthService(authRepository);
    final framework = AppFrameworkDependencies(
      authService: authService,
      analytics: InMemoryCrashAnalyticsService(),
    );
    final appState = framework.createAppState();
    final themeController = SrrThemeController();
    final displayPreferencesController = SrrDisplayPreferencesController();
    final userPreferencesCoordinator = SrrUserPreferencesCoordinator(
      appState: appState,
      themeController: themeController,
      displayPreferencesController: displayPreferencesController,
    );

    return SrrDependencies(
      authService: authService,
      framework: framework,
      appState: appState,
      dashboardRepository: SrrDashboardRepository(SrrDashboardApi(transport)),
      playerRepository: SrrPlayerRepository(SrrPlayerApi(transport)),
      tournamentRepository: SrrTournamentRepository(
        SrrTournamentApi(transport),
      ),
      themeController: themeController,
      displayPreferencesController: displayPreferencesController,
      themeFactory: const SrrThemeFactory(),
      routeRegistry: const SrrRouteRegistry(),
      userPreferencesCoordinator: userPreferencesCoordinator,
    );
  }
}
