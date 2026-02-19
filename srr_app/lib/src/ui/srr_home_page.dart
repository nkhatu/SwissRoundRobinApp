// ---------------------------------------------------------------------------
// srr_app/lib/src/ui/srr_home_page.dart
// ---------------------------------------------------------------------------
// 
// Purpose:
// - Displays primary SRR dashboard views, standings summaries, and navigation actions.
// Architecture:
// - Feature page coordinating dashboard widgets and role-based actions.
// - Consumes repository/API abstractions for live and standings data presentation.
// Author: Neil Khatu
// Copyright (c) The Khatu Family Trust
// 
import 'dart:async';

import 'package:catu_framework/catu_framework.dart';
import 'package:flutter/material.dart';

import '../api/srr_api_client.dart';
import '../models/srr_models.dart';
import '../repositories/srr_dashboard_repository.dart';
import '../theme/srr_display_preferences_controller.dart';
import 'srr_page_scaffold.dart';
import 'srr_routes.dart';
import 'srr_split_action_button.dart';
import 'srr_upload_page.dart';

class SrrHomePage extends StatefulWidget {
  const SrrHomePage({
    super.key,
    required this.appState,
    required this.apiClient,
    required this.dashboardRepository,
    required this.analytics,
    required this.displayPreferencesController,
  });

  final AppState appState;
  final SrrApiClient apiClient;
  final SrrDashboardRepository dashboardRepository;
  final CrashAnalyticsService analytics;
  final SrrDisplayPreferencesController displayPreferencesController;

  @override
  State<SrrHomePage> createState() => _SrrHomePageState();
}

class _SrrHomePageState extends State<SrrHomePage> {
  static const _pollInterval = Duration(seconds: 5);
  static const _setupPageMenuValue = '__setup_page__';
  static const _playerUploadPageMenuValue = '__player_upload_page__';
  static const _roundMatchupPageMenuValue = '__round_matchup_page__';
  static const _rankingUploadPageMenuValue = '__ranking_upload_page__';

  SrrLiveSnapshot? _snapshot;
  List<SrrRoundPoints> _roundPoints = const [];
  List<SrrRoundStandings> _roundStandings = const [];
  bool _loading = true;
  bool _refreshing = false;
  String? _error;
  DateTime? _lastRefresh;
  final Set<int> _submittingMatches = <int>{};
  Timer? _timer;
  bool _redirectingToProfile = false;

  _TournamentSection _section = _TournamentSection.dashboard;
  int? _selectedStandingsRound;

  @override
  void initState() {
    super.initState();
    if (_redirectToProfileIfIncomplete()) {
      return;
    }
    _load(initial: true);
    _timer = Timer.periodic(_pollInterval, (_) {
      if (!mounted) return;
      _load();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load({bool initial = false}) async {
    if (initial) {
      setState(() {
        _loading = true;
        _error = null;
      });
    } else {
      setState(() => _refreshing = true);
    }

    try {
      final bundle = await widget.dashboardRepository.fetchDashboardBundle();

      if (!mounted) return;
      setState(() {
        _snapshot = bundle.liveSnapshot;
        _roundPoints = bundle.roundPoints;
        _roundStandings = bundle.roundStandings;
        _lastRefresh = DateTime.now();
        _error = null;
      });
    } catch (error, stackTrace) {
      widget.analytics.recordError(
        error,
        stackTrace,
        reason: 'dashboard_refresh_failed',
      );
      if (!mounted) return;
      setState(() {
        _error = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _refreshing = false;
        });
      }
    }
  }

  bool _redirectToProfileIfIncomplete() {
    final user = widget.apiClient.currentUserSnapshot;
    if (user == null || user.profileComplete) {
      return false;
    }

    _redirectingToProfile = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(
        context,
        SrrRoutes.completeProfile,
        (_) => false,
      );
    });
    return true;
  }

  Future<void> _confirmMatch(SrrMatch match) async {
    final data = await showDialog<_ScoreSubmission>(
      context: context,
      builder: (context) => _ScoreDialog(match: match),
    );
    if (data == null) return;

    setState(() => _submittingMatches.add(match.id));
    try {
      final updated = await widget.dashboardRepository.confirmMatchScore(
        matchId: match.id,
        score1: data.score1,
        score2: data.score2,
      );
      if (!mounted) return;

      final message = switch (updated.status) {
        SrrMatchStatus.confirmed =>
          'Score confirmed by both players. Points and standings updated.',
        SrrMatchStatus.disputed =>
          'Score submitted. Players currently disagree on the result.',
        SrrMatchStatus.pending =>
          'Score submitted. Waiting for the second player confirmation.',
      };

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
      await _load();
    } on ApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted) {
        setState(() => _submittingMatches.remove(match.id));
      }
    }
  }

  List<SrrMatch> _myMatchesFor(int userId) {
    final snapshot = _snapshot;
    if (snapshot == null) return const [];

    return snapshot.rounds
        .expand((round) => round.matches)
        .where(
          (match) => match.player1.id == userId || match.player2.id == userId,
        )
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    if (_redirectingToProfile) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final snapshot = _snapshot;
    final user = widget.apiClient.currentUserSnapshot;
    final isAdmin = user?.isAdmin ?? false;

    return SrrPageScaffold(
      title: _section.pageTitle,
      appState: widget.appState,
      actions: [
        PopupMenuButton<String>(
          icon: const Icon(Icons.dashboard_customize),
          tooltip: 'Tournament pages',
          onSelected: (value) {
            if (value == _setupPageMenuValue) {
              Navigator.pushNamed(context, SrrRoutes.tournamentSetup);
              return;
            }
            if (value == _playerUploadPageMenuValue) {
              Navigator.pushNamed(
                context,
                SrrRoutes.genericUpload,
                arguments: const SrrUploadPageArguments(
                  context: SrrUploadContext.players,
                ),
              );
              return;
            }
            if (value == _roundMatchupPageMenuValue) {
              Navigator.pushNamed(context, SrrRoutes.roundMatchup);
              return;
            }
            if (value == _rankingUploadPageMenuValue) {
              Navigator.pushNamed(
                context,
                SrrRoutes.genericUpload,
                arguments: const SrrUploadPageArguments(
                  context: SrrUploadContext.ranking,
                ),
              );
              return;
            }

            final section = _TournamentSection.values.firstWhere(
              (entry) => entry.name == value,
              orElse: () => _section,
            );
            setState(() => _section = section);
          },
          itemBuilder: (context) => [
            ..._TournamentSection.values.map(
              (section) => CheckedPopupMenuItem<String>(
                value: section.name,
                checked: section == _section,
                child: Text(section.menuLabel),
              ),
            ),
            if (isAdmin) ...[
              const PopupMenuDivider(),
              const PopupMenuItem<String>(
                value: _setupPageMenuValue,
                child: Text('Tournament Setup (Admin)'),
              ),
              const PopupMenuItem<String>(
                value: _playerUploadPageMenuValue,
                child: Text('Player Upload (Admin)'),
              ),
              const PopupMenuItem<String>(
                value: _roundMatchupPageMenuValue,
                child: Text('Round Matchup (Admin)'),
              ),
              const PopupMenuItem<String>(
                value: _rankingUploadPageMenuValue,
                child: Text('Ranking Upload (Admin)'),
              ),
            ],
          ],
        ),
      ],
      body: _loading && snapshot == null
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () => _load(),
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _StatusCard(
                    user: user,
                    snapshot: snapshot,
                    sectionLabel: _section.menuLabel,
                    lastRefresh: _lastRefresh,
                    displayPreferencesController:
                        widget.displayPreferencesController,
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    _ErrorBanner(
                      message: _error!,
                      onRetry: _load,
                      isRefreshing: _refreshing,
                    ),
                  ],
                  const SizedBox(height: 12),
                  _buildSelectedSection(user, snapshot),
                ],
              ),
            ),
    );
  }

  Widget _buildSelectedSection(SrrUser? user, SrrLiveSnapshot? snapshot) {
    switch (_section) {
      case _TournamentSection.dashboard:
        return _DashboardCard(snapshot: snapshot);
      case _TournamentSection.standings:
        return _StandingsWithRoundPickerCard(
          liveStandings: snapshot?.standings ?? const [],
          roundStandings: _roundStandings,
          selectedRound: _selectedStandingsRound,
          onRoundChanged: (value) {
            setState(() => _selectedStandingsRound = value);
          },
        );
      case _TournamentSection.roundPoints:
        return _RoundPointsCard(roundPoints: _roundPoints);
      case _TournamentSection.myScoreConfirmation:
        if (user != null && user.isPlayer) {
          return _MyMatchesCard(
            matches: _myMatchesFor(user.id),
            submittingMatches: _submittingMatches,
            onConfirm: _confirmMatch,
          );
        }
        return const _ViewerNoticeCard();
      case _TournamentSection.roundFeed:
        return _RoundsCard(rounds: snapshot?.rounds ?? const []);
    }
  }
}

enum _TournamentSection {
  dashboard,
  standings,
  roundPoints,
  myScoreConfirmation,
  roundFeed,
}

extension on _TournamentSection {
  String get menuLabel {
    switch (this) {
      case _TournamentSection.dashboard:
        return 'Live Tournament Dashboard';
      case _TournamentSection.standings:
        return 'Standings (Round Picker)';
      case _TournamentSection.roundPoints:
        return 'Round Points';
      case _TournamentSection.myScoreConfirmation:
        return 'My Score Confirmation';
      case _TournamentSection.roundFeed:
        return 'Round Feed';
    }
  }

  String get pageTitle {
    switch (this) {
      case _TournamentSection.dashboard:
        return 'Live Tournament Dashboard';
      case _TournamentSection.standings:
        return 'Standings';
      case _TournamentSection.roundPoints:
        return 'Round Points';
      case _TournamentSection.myScoreConfirmation:
        return 'My Score Confirmation';
      case _TournamentSection.roundFeed:
        return 'Round Feed';
    }
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({
    required this.user,
    required this.snapshot,
    required this.sectionLabel,
    required this.lastRefresh,
    required this.displayPreferencesController,
  });

  final SrrUser? user;
  final SrrLiveSnapshot? snapshot;
  final String sectionLabel;
  final DateTime? lastRefresh;
  final SrrDisplayPreferencesController displayPreferencesController;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final lastRefreshLabel = lastRefresh == null
        ? 'Not synced yet'
        : displayPreferencesController.formatDateTime(
            lastRefresh!,
            fallbackLocale: Localizations.localeOf(context),
          );

    return Card(
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              scheme.primaryContainer.withValues(alpha: 0.65),
              scheme.surfaceContainerHighest,
            ],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: scheme.primary,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    Icons.sports_kabaddi_rounded,
                    color: scheme.onPrimary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        'Carrom Command Center',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                          fontFamily: 'serif',
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        user == null
                            ? 'Session is not loaded.'
                            : 'Signed in as ${user!.displayName} (${user!.role})',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                _HeaderPill(
                  icon: Icons.timeline,
                  label: 'Current round: ${snapshot?.currentRound ?? '-'}',
                ),
                _HeaderPill(
                  icon: Icons.view_compact_alt_outlined,
                  label: sectionLabel,
                ),
                _HeaderPill(
                  icon: Icons.schedule,
                  label: 'Last sync: $lastRefreshLabel',
                ),
                _HeaderPill(
                  icon: Icons.leaderboard_outlined,
                  label: 'Standings: ${snapshot?.standings.length ?? 0}',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DashboardCard extends StatelessWidget {
  const _DashboardCard({required this.snapshot});

  final SrrLiveSnapshot? snapshot;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rounds = snapshot?.rounds ?? const <SrrRound>[];
    final matches = rounds
        .expand((round) => round.matches)
        .toList(growable: false);
    final confirmed = matches.where((match) => match.isConfirmed).length;
    final disputed = matches
        .where((match) => match.status == SrrMatchStatus.disputed)
        .length;
    final pending = matches.length - confirmed;
    final topRows = (snapshot?.standings ?? const <SrrStandingRow>[]).take(3);

    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.insights_rounded, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Live Tournament Dashboard',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 10,
              runSpacing: 10,
              children: [
                _MetricTile(
                  icon: Icons.repeat_rounded,
                  label: 'Rounds',
                  value: '${rounds.length}',
                ),
                _MetricTile(
                  icon: Icons.table_restaurant_rounded,
                  label: 'Matches',
                  value: '${matches.length}',
                ),
                _MetricTile(
                  icon: Icons.verified_rounded,
                  label: 'Confirmed',
                  value: '$confirmed',
                ),
                _MetricTile(
                  icon: Icons.schedule_rounded,
                  label: 'Pending',
                  value: '$pending',
                ),
                _MetricTile(
                  icon: Icons.report_gmailerrorred_rounded,
                  label: 'Disputed',
                  value: '$disputed',
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.emoji_events_rounded,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Top Standings',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            if (topRows.isEmpty)
              const Text('No standings yet.', textAlign: TextAlign.center)
            else
              ...topRows.map((row) {
                IconData icon;
                switch (row.position) {
                  case 1:
                    icon = Icons.looks_one_rounded;
                    break;
                  case 2:
                    icon = Icons.looks_two_rounded;
                    break;
                  case 3:
                    icon = Icons.looks_3_rounded;
                    break;
                  default:
                    icon = Icons.pin_outlined;
                }
                return Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 760),
                    child: ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(icon, color: theme.colorScheme.primary),
                      title: Text(
                        row.displayName,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        'SRP ${row.sumRoundPoints} • SOP ${row.sumOpponentRoundPoints} • NGD ${row.netGamePointsDifference}',
                        textAlign: TextAlign.center,
                      ),
                      trailing: Text('${row.points} pts'),
                    ),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}

class _HeaderPill extends StatelessWidget {
  const _HeaderPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: scheme.surface.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: scheme.primary),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: 156,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, size: 18, color: scheme.primary),
          const SizedBox(height: 8),
          Text(
            value,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 2),
          Text(label, textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

class _StandingsWithRoundPickerCard extends StatelessWidget {
  const _StandingsWithRoundPickerCard({
    required this.liveStandings,
    required this.roundStandings,
    required this.selectedRound,
    required this.onRoundChanged,
  });

  final List<SrrStandingRow> liveStandings;
  final List<SrrRoundStandings> roundStandings;
  final int? selectedRound;
  final ValueChanged<int?> onRoundChanged;

  @override
  Widget build(BuildContext context) {
    SrrRoundStandings? selectedRoundData;
    if (selectedRound != null) {
      for (final entry in roundStandings) {
        if (entry.roundNumber == selectedRound) {
          selectedRoundData = entry;
          break;
        }
      }
    }

    final tableRows = selectedRoundData?.standings ?? liveStandings;
    final subtitle = selectedRoundData == null
        ? 'Live standings across all confirmed rounds'
        : selectedRoundData.isComplete
        ? 'After Round ${selectedRoundData.roundNumber} (Complete)'
        : 'After Round ${selectedRoundData.roundNumber} (In progress)';

    final roundChoices =
        roundStandings
            .map((entry) => entry.roundNumber)
            .toSet()
            .toList(growable: false)
          ..sort();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              'Standings with Round Picker',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: DropdownButtonFormField<int?>(
                  key: ValueKey<int?>(selectedRound),
                  initialValue: selectedRound,
                  decoration: const InputDecoration(
                    labelText: 'Pick standings scope',
                  ),
                  items: [
                    const DropdownMenuItem<int?>(
                      value: null,
                      child: Text('Live (all rounds)'),
                    ),
                    ...roundChoices.map(
                      (round) => DropdownMenuItem<int?>(
                        value: round,
                        child: Text('After Round $round'),
                      ),
                    ),
                  ],
                  onChanged: onRoundChanged,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(subtitle, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            _StandingsTable(rows: tableRows),
          ],
        ),
      ),
    );
  }
}

class _StandingsTable extends StatelessWidget {
  const _StandingsTable({required this.rows});

  final List<SrrStandingRow> rows;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return const Text(
        'No standings yet. Confirm match scores to populate table.',
        textAlign: TextAlign.center,
      );
    }

    return Center(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columns: const [
            DataColumn(label: Center(child: Text('#'))),
            DataColumn(label: Center(child: Text('Player'))),
            DataColumn(label: Center(child: Text('SRP'))),
            DataColumn(label: Center(child: Text('SOP'))),
            DataColumn(label: Center(child: Text('NGD'))),
            DataColumn(label: Center(child: Text('MP'))),
          ],
          rows: rows
              .map(
                (row) => DataRow(
                  cells: [
                    DataCell(Center(child: Text(row.position.toString()))),
                    DataCell(
                      Center(
                        child: Text(
                          row.displayName,
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                    DataCell(
                      Center(child: Text(row.sumRoundPoints.toString())),
                    ),
                    DataCell(
                      Center(
                        child: Text(row.sumOpponentRoundPoints.toString()),
                      ),
                    ),
                    DataCell(
                      Center(
                        child: Text(row.netGamePointsDifference.toString()),
                      ),
                    ),
                    DataCell(Center(child: Text(row.points.toString()))),
                  ],
                ),
              )
              .toList(growable: false),
        ),
      ),
    );
  }
}

class _RoundPointsCard extends StatelessWidget {
  const _RoundPointsCard({required this.roundPoints});

  final List<SrrRoundPoints> roundPoints;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              'Round Points (Carrom Game Points)',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            if (roundPoints.isEmpty)
              const Text(
                'No round points available yet.',
                textAlign: TextAlign.center,
              )
            else
              ...roundPoints.map(
                (round) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      Chip(label: Text('Round ${round.roundNumber}')),
                      ...round.points.map(
                        (entry) => Chip(
                          label: Text('${entry.displayName}: ${entry.points}'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _MyMatchesCard extends StatelessWidget {
  const _MyMatchesCard({
    required this.matches,
    required this.submittingMatches,
    required this.onConfirm,
  });

  final List<SrrMatch> matches;
  final Set<int> submittingMatches;
  final ValueChanged<SrrMatch> onConfirm;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              'My Score Confirmation',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            if (matches.isEmpty)
              const Text(
                'No matches assigned to this player.',
                textAlign: TextAlign.center,
              )
            else
              ...matches.map(
                (match) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    'Round ${match.roundNumber}: '
                    '${match.player1.displayName} vs ${match.player2.displayName}',
                    textAlign: TextAlign.center,
                  ),
                  subtitle: Text(
                    match.isConfirmed
                        ? 'Confirmed: '
                              '${match.confirmedScore1} - ${match.confirmedScore2}'
                        : 'Status: ${match.statusLabel} • '
                              '${match.confirmations}/2 confirmations',
                    textAlign: TextAlign.center,
                  ),
                  trailing: match.isConfirmed
                      ? const Icon(Icons.check_circle, color: Colors.green)
                      : SizedBox(
                          width: 178,
                          child: SrrSplitActionButton(
                            label: submittingMatches.contains(match.id)
                                ? 'Submitting...'
                                : (match.myConfirmation == null
                                      ? 'Enter Score'
                                      : 'Update Score'),
                            variant: SrrSplitActionButtonVariant.outlined,
                            leadingIcon: Icons.scoreboard_outlined,
                            onPressed: submittingMatches.contains(match.id)
                                ? null
                                : () => onConfirm(match),
                          ),
                        ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _RoundsCard extends StatelessWidget {
  const _RoundsCard({required this.rounds});

  final List<SrrRound> rounds;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              'Round Feed',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            if (rounds.isEmpty)
              const Text('No rounds loaded yet.', textAlign: TextAlign.center)
            else
              ...rounds.map(
                (round) => ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  title: Text(
                    'Round ${round.roundNumber}',
                    textAlign: TextAlign.center,
                  ),
                  subtitle: Text(
                    round.isComplete ? 'Complete' : 'In progress',
                    textAlign: TextAlign.center,
                  ),
                  children: round.matches
                      .map(
                        (match) => ListTile(
                          dense: true,
                          title: Text(
                            'Table ${match.tableNumber}: '
                            '${match.player1.displayName} vs ${match.player2.displayName}',
                            textAlign: TextAlign.center,
                          ),
                          subtitle: Text(
                            match.isConfirmed
                                ? 'Score: ${match.confirmedScore1} - ${match.confirmedScore2}'
                                : '${match.statusLabel} • '
                                      '${match.confirmations}/2 confirmations',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      )
                      .toList(growable: false),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ViewerNoticeCard extends StatelessWidget {
  const _ViewerNoticeCard();

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Text(
          'Viewer mode is read-only. Live standings and round updates refresh automatically.',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({
    required this.message,
    required this.onRetry,
    required this.isRefreshing,
  });

  final String message;
  final Future<void> Function({bool initial}) onRetry;
  final bool isRefreshing;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 4),
            TextButton(
              onPressed: isRefreshing ? null : () => onRetry(),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScoreSubmission {
  const _ScoreSubmission({required this.score1, required this.score2});

  final int score1;
  final int score2;
}

class _ScoreDialog extends StatefulWidget {
  const _ScoreDialog({required this.match});

  final SrrMatch match;

  @override
  State<_ScoreDialog> createState() => _ScoreDialogState();
}

class _ScoreDialogState extends State<_ScoreDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _score1Ctrl;
  late final TextEditingController _score2Ctrl;

  @override
  void initState() {
    super.initState();
    _score1Ctrl = TextEditingController(
      text: widget.match.myConfirmation?.score1.toString() ?? '',
    );
    _score2Ctrl = TextEditingController(
      text: widget.match.myConfirmation?.score2.toString() ?? '',
    );
  }

  @override
  void dispose() {
    _score1Ctrl.dispose();
    _score2Ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Confirm Match Score'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${widget.match.player1.displayName} vs ${widget.match.player2.displayName}',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _score1Ctrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: '${widget.match.player1.displayName} score',
              ),
              validator: _scoreValidator,
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _score2Ctrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: '${widget.match.player2.displayName} score',
              ),
              validator: _scoreValidator,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        SizedBox(
          width: 150,
          child: SrrSplitActionButton(
            label: 'Submit',
            variant: SrrSplitActionButtonVariant.filled,
            leadingIcon: Icons.check_rounded,
            onPressed: () {
              if (!(_formKey.currentState?.validate() ?? false)) return;
              Navigator.pop(
                context,
                _ScoreSubmission(
                  score1: int.parse(_score1Ctrl.text.trim()),
                  score2: int.parse(_score2Ctrl.text.trim()),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  String? _scoreValidator(String? value) {
    final text = (value ?? '').trim();
    if (text.isEmpty) return 'Required';
    final parsed = int.tryParse(text);
    if (parsed == null) return 'Number required';
    if (parsed < 0) return 'Score cannot be negative';
    if (parsed > 999) return 'Score too high';
    return null;
  }
}
