// ---------------------------------------------------------------------------
// srr_app/lib/src/ui/srr_bootstrap_page.dart
// ---------------------------------------------------------------------------
// 
// Purpose:
// - Resolves initial signed-in state and routes users to the correct first screen.
// Architecture:
// - Presentation bootstrap layer that evaluates auth/profile/tournament context.
// - Delegates session and API state loading to app state and API client dependencies.
// Author: Neil Khatu
// Copyright (c) The Khatu Family Trust
// 
import 'package:catu_framework/catu_framework.dart';
import 'package:flutter/material.dart';

import '../api/srr_api_client.dart';
import 'srr_routes.dart';

class SrrBootstrapPage extends StatefulWidget {
  const SrrBootstrapPage({
    super.key,
    required this.appState,
    required this.apiClient,
  });

  final AppState appState;
  final SrrApiClient apiClient;

  @override
  State<SrrBootstrapPage> createState() => _SrrBootstrapPageState();
}

class _SrrBootstrapPageState extends State<SrrBootstrapPage> {
  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    await widget.appState.bootstrap();
    if (!mounted) return;

    final currentUser = widget.apiClient.currentUserSnapshot;
    String destination;
    if (!widget.appState.isSignedIn) {
      destination = AppRoutes.signIn;
    } else if (!(currentUser?.profileComplete ?? false)) {
      destination = SrrRoutes.completeProfile;
    } else {
      destination = AppRoutes.home;
      try {
        final status = await widget.apiClient.fetchActiveTournamentStatus();
        if (!mounted) return;
        if (!status.hasActiveTournament) {
          if (currentUser?.isAdmin ?? false) {
            destination = SrrRoutes.tournamentSetup;
          } else if (currentUser?.isPlayer ?? false) {
            destination = SrrRoutes.currentNationalRanking;
          }
        }
      } on ApiException {
        destination = AppRoutes.home;
      }
    }

    Navigator.pushNamedAndRemoveUntil(context, destination, (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
