// ---------------------------------------------------------------------------
// srr_app/lib/src/ui/srr_tournament_app.dart
// ---------------------------------------------------------------------------
//
// Purpose:
// - Hosts the root MaterialApp and binds injected app services/controllers.
// Architecture:
// - Presentation shell that consumes DI-provided routing and theming services.
// - Delegates user-context preference synchronization to coordinator services.
// Author: Neil Khatu
// Copyright (c) The Khatu Family Trust
//
import 'package:catu_framework/catu_framework.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../config/srr_app_config.dart';
import '../di/srr_dependencies.dart';
import '../theme/srr_display_preferences_controller.dart';

class SrrTournamentApp extends StatefulWidget {
  const SrrTournamentApp({super.key, required this.dependencies});

  final SrrDependencies dependencies;

  @override
  State<SrrTournamentApp> createState() => _SrrTournamentAppState();
}

class _SrrTournamentAppState extends State<SrrTournamentApp> {
  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    widget.dependencies.userPreferencesCoordinator.dispose();
    widget.dependencies.appState.dispose();
    widget.dependencies.themeController.dispose();
    widget.dependencies.displayPreferencesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        widget.dependencies.themeController,
        widget.dependencies.displayPreferencesController,
      ]),
      builder: (context, _) {
        return MaterialApp(
          title: SrrAppConfig.appName,
          debugShowCheckedModeBanner: false,
          theme: widget.dependencies.themeFactory.build(
            widget.dependencies.themeController.variant,
          ),
          locale: widget.dependencies.displayPreferencesController.locale,
          supportedLocales: SrrDisplayPreferencesController.supportedLocales,
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          builder: (context, child) {
            final content = child ?? const SizedBox.shrink();
            if (!kIsWeb) return content;
            return SelectionArea(child: content);
          },
          initialRoute: AppRoutes.bootstrap,
          routes: widget.dependencies.routeRegistry.buildRoutes(
            appState: widget.dependencies.appState,
            apiClient: widget.dependencies.apiClient,
            framework: widget.dependencies.framework,
            dashboardRepository: widget.dependencies.dashboardRepository,
            playerRepository: widget.dependencies.playerRepository,
            tournamentRepository: widget.dependencies.tournamentRepository,
            themeController: widget.dependencies.themeController,
            displayPreferencesController:
                widget.dependencies.displayPreferencesController,
            appVersion: SrrAppConfig.appVersion,
            appBuild: SrrAppConfig.appBuild,
          ),
        );
      },
    );
  }
}
