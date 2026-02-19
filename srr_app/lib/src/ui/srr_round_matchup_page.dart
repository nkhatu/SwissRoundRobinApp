// ---------------------------------------------------------------------------
// srr_app/lib/src/ui/srr_round_matchup_page.dart
// ---------------------------------------------------------------------------
// 
// Purpose:
// - Handles round matchup generation and navigation into round-level workflows.
// Architecture:
// - Feature page coordinating matchup controls and round flow presentation.
// - Uses API/repository abstractions to separate UI from domain state changes.
// Author: Neil Khatu
// Copyright (c) The Khatu Family Trust
// 
import 'package:catu_framework/catu_framework.dart';
import 'package:flutter/material.dart';

import '../api/srr_api_client.dart';
import 'srr_page_scaffold.dart';

class SrrRoundMatchupPage extends StatelessWidget {
  const SrrRoundMatchupPage({
    super.key,
    required this.appState,
    required this.apiClient,
  });

  final AppState appState;
  final SrrApiClient apiClient;

  @override
  Widget build(BuildContext context) {
    final user = apiClient.currentUserSnapshot;
    final isAdmin = user?.isAdmin ?? false;

    return SrrPageScaffold(
      title: 'Round Matchup',
      appState: appState,
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                user == null
                    ? 'Session is not loaded.'
                    : 'Signed in as ${user.displayName} (${user.role})',
                textAlign: TextAlign.center,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                isAdmin
                    ? 'Round matchup tooling is admin-only and reserved on this page.'
                    : 'Round matchup is available only for admin accounts.',
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
