// ---------------------------------------------------------------------------
// srr_app/lib/src/ui/srr_round_matchup_page.dart
// ---------------------------------------------------------------------------
//
// Purpose:
// - Generates and manages group-scoped round match-ups with multi-group controls.
// Architecture:
// - Feature page coordinating tournament selection, batch generation, and per-group matchup views.
// - Delegates generation/deletion and tournament data access to repository and API layers.
// Author: Neil Khatu
// Copyright (c) The Khatu Family Trust
//
import 'package:catu_framework/catu_framework.dart';
import 'package:flutter/material.dart';

import '../../auth/srr_auth_service.dart';
import '../../models/srr_models.dart';
import '../../repositories/srr_dashboard_repository.dart';
import '../../repositories/srr_tournament_repository.dart';
import '../../services/srr_country_iso.dart';
import '../../services/srr_tournament_labels.dart';
import '../helpers/srr_page_scaffold.dart';
import '../routes/srr_routes.dart';
import '../helpers/srr_split_action_button.dart';
import 'srr_match_score_entry_page.dart';

class SrrRoundMatchupPageArguments {
  const SrrRoundMatchupPageArguments({this.tournamentId});

  final int? tournamentId;
}

class SrrRoundMatchupPage extends StatefulWidget {
  const SrrRoundMatchupPage({
    super.key,
    required this.appState,
    required this.authService,
    required this.dashboardRepository,
    required this.tournamentRepository,
    this.initialTournamentId,
  });

  final AppState appState;
  final SrrAuthService authService;
  final SrrDashboardRepository dashboardRepository;
  final SrrTournamentRepository tournamentRepository;
  final int? initialTournamentId;

  @override
  State<SrrRoundMatchupPage> createState() => _SrrRoundMatchupPageState();
}

class _SrrRoundMatchupPageState extends State<SrrRoundMatchupPage> {
  static const _roundOneMethods = <String, String>{
    'adjacent': '1 vs 2, 3 vs 4',
    'top_vs_top': 'Top Half vs Top Bottom Half',
    'top_vs_bottom': 'Top Half vs Bottom Bottom Half',
  };

  static const double _srColumnWidth = 70;
  static const double _playerColumnWidth = 240;
  static const double _flagColumnWidth = 90;
  static const double _vsColumnWidth = 70;
  static const double _venueColumnWidth = 150;

  bool _loading = true;
  bool _busy = false;
  String? _error;

  List<SrrTournamentRecord> _tournaments = const [];
  int? _selectedTournamentId;
  String _roundOneMethod = 'adjacent';

  SrrTournamentGroupsSnapshot? _groupsSnapshot;
  Map<int, List<SrrMatch>> _matchesByGroup = const {};

  Set<int> _selectedGroupNumbers = <int>{};
  Set<int> _expandedGroupNumbers = <int>{};
  bool _groupSelectionInitialized = false;

  SrrTournamentRecord? get _selectedTournament {
    final id = _selectedTournamentId;
    if (id == null) return null;
    for (final tournament in _tournaments) {
      if (tournament.id == id) return tournament;
    }
    return null;
  }

  List<int> get _availableGroups {
    final rows = _groupsSnapshot?.rows ?? const <SrrTournamentGroupRow>[];
    final set = <int>{};
    for (final row in rows) {
      if (row.groupNumber > 0) {
        set.add(row.groupNumber);
      }
    }
    final groups = set.toList()..sort((a, b) => a - b);
    return groups;
  }

  bool get _allGroupsSelected {
    final available = _availableGroups;
    if (available.isEmpty) return false;
    return available.every(_selectedGroupNumbers.contains);
  }

  bool get _canGenerateForSelectedGroups {
    if (_busy || _selectedTournamentId == null) return false;
    if (_selectedGroupNumbers.isEmpty) return false;
    if (!(_groupsSnapshot?.rows.isNotEmpty ?? false)) return false;
    return _selectedGroupNumbers.any(_canGenerateForGroup);
  }

  int get _maxRounds {
    final metadata = _selectedTournament?.metadata;
    return metadata == null ? 7 : metadata.srrRounds;
  }

  @override
  void initState() {
    super.initState();
    _loadContext(preferredTournamentId: widget.initialTournamentId);
  }

  Map<int, List<SrrMatch>> _indexMatchesByGroup(List<SrrRound> rounds) {
    final grouped = <int, List<SrrMatch>>{};
    for (final round in rounds) {
      for (final match in round.matches) {
        final groupNumber = match.groupNumber;
        if (groupNumber == null || groupNumber <= 0) continue;
        final bucket = grouped[groupNumber] ?? <SrrMatch>[];
        bucket.add(match);
        grouped[groupNumber] = bucket;
      }
    }
    for (final bucket in grouped.values) {
      bucket.sort((left, right) {
        final byRound = left.roundNumber.compareTo(right.roundNumber);
        if (byRound != 0) return byRound;
        return left.tableNumber.compareTo(right.tableNumber);
      });
    }
    return grouped;
  }

  int _playerCountForGroup(int groupNumber) {
    final rows = _groupsSnapshot?.rows ?? const <SrrTournamentGroupRow>[];
    var count = 0;
    for (final row in rows) {
      if (row.groupNumber == groupNumber) count += 1;
    }
    return count;
  }

  int _currentRoundForGroup(int groupNumber) {
    final matches = _matchesByGroup[groupNumber] ?? const <SrrMatch>[];
    if (matches.isEmpty) return 0;
    var maxRound = 0;
    for (final match in matches) {
      if (match.roundNumber > maxRound) {
        maxRound = match.roundNumber;
      }
    }
    return maxRound;
  }

  List<SrrMatch> _currentRoundMatchesForGroup(int groupNumber) {
    final matches = _matchesByGroup[groupNumber] ?? const <SrrMatch>[];
    final currentRound = _currentRoundForGroup(groupNumber);
    if (currentRound == 0) return const <SrrMatch>[];
    return matches
        .where((match) => match.roundNumber == currentRound)
        .toList(growable: false)
      ..sort((a, b) => a.tableNumber.compareTo(b.tableNumber));
  }

  bool _isCurrentRoundCompleteForGroup(int groupNumber) {
    final matches = _currentRoundMatchesForGroup(groupNumber);
    if (matches.isEmpty) return true;
    return matches.every((match) => match.isConfirmed);
  }

  bool _canGenerateForGroup(int groupNumber) {
    final playerCount = _playerCountForGroup(groupNumber);
    if (playerCount < 2 || playerCount.isOdd) return false;

    final currentRound = _currentRoundForGroup(groupNumber);
    if (currentRound >= _maxRounds) return false;
    if (currentRound > 0 && !_isCurrentRoundCompleteForGroup(groupNumber)) {
      return false;
    }
    return true;
  }

  Future<void> _loadContext({int? preferredTournamentId}) async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final tournaments = await widget.tournamentRepository.fetchTournaments();
      int? tournamentId =
          preferredTournamentId ??
          _selectedTournamentId ??
          widget.initialTournamentId;
      if (tournamentId != null &&
          tournaments.every((entry) => entry.id != tournamentId)) {
        tournamentId = null;
      }
      if (tournamentId == null && widget.initialTournamentId == null) {
        tournamentId = tournaments.isEmpty ? null : tournaments.first.id;
      }

      SrrTournamentGroupsSnapshot? groupsSnapshot;
      List<SrrRound> rounds = const <SrrRound>[];
      if (tournamentId != null) {
        final results = await Future.wait<dynamic>([
          widget.tournamentRepository.fetchTournamentGroups(
            tournamentId: tournamentId,
          ),
          widget.dashboardRepository.fetchRounds(tournamentId: tournamentId),
        ]);
        groupsSnapshot = results[0] as SrrTournamentGroupsSnapshot;
        rounds = results[1] as List<SrrRound>;
      }

      final indexedMatches = _indexMatchesByGroup(rounds);
      final groupSet = <int>{};
      if (groupsSnapshot != null) {
        for (final row in groupsSnapshot.rows) {
          if (row.groupNumber > 0) groupSet.add(row.groupNumber);
        }
      }
      final availableGroups = groupSet.toList()..sort((a, b) => a - b);

      final tournamentChanged = tournamentId != _selectedTournamentId;
      Set<int> nextSelectedGroups;
      if (!_groupSelectionInitialized || tournamentChanged) {
        nextSelectedGroups = {...availableGroups};
      } else {
        nextSelectedGroups = _selectedGroupNumbers.intersection(
          availableGroups.toSet(),
        );
      }
      final nextExpandedGroups = _expandedGroupNumbers.intersection(
        availableGroups.toSet(),
      );

      if (!mounted) return;
      setState(() {
        _tournaments = tournaments;
        _selectedTournamentId = tournamentId;
        _groupsSnapshot = groupsSnapshot;
        _matchesByGroup = indexedMatches;
        _selectedGroupNumbers = nextSelectedGroups;
        _expandedGroupNumbers = nextExpandedGroups;
        _groupSelectionInitialized = true;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.toString();
      });
    }
  }

  Future<void> _onTournamentChanged(int? tournamentId) async {
    if (tournamentId == null || tournamentId == _selectedTournamentId) return;
    setState(() {
      _selectedGroupNumbers = <int>{};
      _expandedGroupNumbers = <int>{};
      _groupSelectionInitialized = false;
    });
    await _loadContext(preferredTournamentId: tournamentId);
  }

  void _toggleSelectAllGroups(bool? selected) {
    if (_busy) return;
    final availableGroups = _availableGroups;
    if (availableGroups.isEmpty) return;
    final shouldSelect = selected ?? false;
    setState(() {
      _selectedGroupNumbers = shouldSelect ? {...availableGroups} : <int>{};
    });
  }

  void _toggleGroupSelection(int groupNumber, bool? selected) {
    if (_busy) return;
    final shouldSelect = selected ?? false;
    setState(() {
      final next = {..._selectedGroupNumbers};
      if (shouldSelect) {
        next.add(groupNumber);
      } else {
        next.remove(groupNumber);
      }
      _selectedGroupNumbers = next;
    });
  }

  void _toggleExpandedGroup(int groupNumber) {
    setState(() {
      final next = {..._expandedGroupNumbers};
      if (next.contains(groupNumber)) {
        next.remove(groupNumber);
      } else {
        next.add(groupNumber);
      }
      _expandedGroupNumbers = next;
    });
  }

  Future<_GroupGenerateAttempt> _generateForGroup(int groupNumber) async {
    final tournamentId = _selectedTournamentId;
    if (tournamentId == null) {
      return _GroupGenerateAttempt(
        groupNumber: groupNumber,
        success: false,
        error: 'Tournament is not selected.',
      );
    }
    try {
      final result = await widget.tournamentRepository
          .generateTournamentGroupMatchups(
            tournamentId: tournamentId,
            groupNumber: groupNumber,
            roundOneMethod: _roundOneMethod,
          );
      return _GroupGenerateAttempt(
        groupNumber: groupNumber,
        success: true,
        roundNumber: result.roundNumber,
        matchesCreated: result.matchesCreated,
      );
    } catch (error) {
      return _GroupGenerateAttempt(
        groupNumber: groupNumber,
        success: false,
        error: error.toString(),
      );
    }
  }

  Future<void> _generateSelectedGroupsInParallel() async {
    final tournamentId = _selectedTournamentId;
    if (!_canGenerateForSelectedGroups || tournamentId == null) return;

    final selectedGroups = _selectedGroupNumbers.toList()
      ..sort((a, b) => a - b);
    final eligibleGroups = <int>[];
    final skippedReasons = <String>[];

    for (final groupNumber in selectedGroups) {
      final playerCount = _playerCountForGroup(groupNumber);
      if (playerCount < 2) {
        skippedReasons.add('Group $groupNumber skipped: less than 2 players.');
        continue;
      }
      if (playerCount.isOdd) {
        skippedReasons.add(
          'Group $groupNumber skipped: odd player count ($playerCount).',
        );
        continue;
      }
      final currentRound = _currentRoundForGroup(groupNumber);
      if (currentRound >= _maxRounds) {
        skippedReasons.add(
          'Group $groupNumber skipped: max rounds ($_maxRounds) already generated.',
        );
        continue;
      }
      if (currentRound > 0 && !_isCurrentRoundCompleteForGroup(groupNumber)) {
        skippedReasons.add(
          'Group $groupNumber skipped: current round $currentRound has pending scores.',
        );
        continue;
      }
      eligibleGroups.add(groupNumber);
    }

    if (eligibleGroups.isEmpty) {
      setState(() {
        _error = skippedReasons.isEmpty
            ? 'No selected groups are eligible for match-up generation.'
            : skippedReasons.join('\n');
      });
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    final attempts = await Future.wait(eligibleGroups.map(_generateForGroup));

    if (!mounted) return;

    final successGroups = attempts
        .where((attempt) => attempt.success)
        .map((attempt) => attempt.groupNumber)
        .toSet();
    final failedAttempts = attempts
        .where((attempt) => !attempt.success)
        .toList(growable: false);

    await _loadContext(preferredTournamentId: tournamentId);
    if (!mounted) return;

    setState(() {
      _busy = false;
      _expandedGroupNumbers = {..._expandedGroupNumbers, ...successGroups};
      if (failedAttempts.isNotEmpty || skippedReasons.isNotEmpty) {
        final messages = <String>[
          ...failedAttempts.map(
            (attempt) =>
                'Group ${attempt.groupNumber} failed: ${attempt.error ?? 'Unknown error'}',
          ),
          ...skippedReasons,
        ];
        _error = messages.join('\n');
      }
    });

    final successCount = successGroups.length;
    final failedCount = failedAttempts.length;
    final skippedCount = skippedReasons.length;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Generated match-ups for $successCount group(s). Failed: $failedCount. Skipped: $skippedCount.',
        ),
      ),
    );
  }

  Future<bool> _confirmDeleteCurrentRound({
    required int groupNumber,
    required int currentRound,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete Current Round Match-ups'),
          content: Text(
            'Delete round $currentRound match-ups for Group $groupNumber only?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            SizedBox(
              width: 170,
              child: SrrSplitActionButton(
                label: 'Delete',
                leadingIcon: Icons.delete_forever,
                variant: SrrSplitActionButtonVariant.filled,
                onPressed: () => Navigator.of(context).pop(true),
              ),
            ),
          ],
        );
      },
    );
    return result == true;
  }

  Future<void> _deleteCurrentRoundForGroup(int groupNumber) async {
    final tournamentId = _selectedTournamentId;
    final currentRound = _currentRoundForGroup(groupNumber);
    if (_busy || tournamentId == null || currentRound <= 0) return;

    final confirmed = await _confirmDeleteCurrentRound(
      groupNumber: groupNumber,
      currentRound: currentRound,
    );
    if (!confirmed || !mounted) return;

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final result = await widget.tournamentRepository
          .deleteCurrentTournamentGroupMatchups(
            tournamentId: tournamentId,
            groupNumber: groupNumber,
          );
      if (!mounted) return;
      await _loadContext(preferredTournamentId: result.tournament.id);
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Deleted round ${result.deletedRoundNumber} for Group ${result.groupNumber} (${result.deletedMatches} matches).',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = error.toString();
      });
    }
  }

  Future<void> _openBoardEntryForMatch(SrrMatch match) async {
    final tournamentId = _selectedTournamentId ?? match.tournamentId;
    final selectedTournament = _selectedTournament;
    await Navigator.pushNamed(
      context,
      SrrRoutes.matchScoreEntry,
      arguments: SrrMatchScoreEntryPageArguments(
        matchId: match.id,
        tournamentId: tournamentId,
        tournamentName: selectedTournament == null
            ? null
            : srrTournamentDropdownLabel(selectedTournament),
      ),
    );
    await _loadContext(preferredTournamentId: _selectedTournamentId);
  }

  Widget _buildMethodToggle() {
    const keys = <String>['adjacent', 'top_vs_top', 'top_vs_bottom'];
    final isSelected = keys.map((key) => _roundOneMethod == key).toList();
    return ToggleButtons(
      isSelected: isSelected,
      onPressed: _busy
          ? null
          : (index) {
              setState(() {
                _roundOneMethod = keys[index];
              });
            },
      constraints: const BoxConstraints(minWidth: 170, minHeight: 48),
      borderRadius: BorderRadius.circular(12),
      children: const [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 8),
          child: Text('Round1: 1v2'),
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 8),
          child: Text('Round1: Top-Top'),
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 8),
          child: Text('Round1: Top-Bottom'),
        ),
      ],
    );
  }

  Widget _buildGroupSelectionPanel() {
    final availableGroups = _availableGroups;
    if (availableGroups.isEmpty) {
      return const Text(
        'No groups found. Create tournament groups first.',
        textAlign: TextAlign.center,
      );
    }

    final borderColor = Theme.of(context).dividerColor.withValues(alpha: 0.55);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: borderColor),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Checkbox(
                value: _allGroupsSelected,
                onChanged: _busy ? null : _toggleSelectAllGroups,
              ),
              const Text('Select all groups'),
              const SizedBox(width: 16),
              Text(
                'Selected: ${_selectedGroupNumbers.length}/${availableGroups.length}',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 10,
            runSpacing: 8,
            children: availableGroups
                .map((groupNumber) {
                  final selected = _selectedGroupNumbers.contains(groupNumber);
                  return InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: _busy
                        ? null
                        : () => _toggleGroupSelection(groupNumber, !selected),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Checkbox(
                            value: selected,
                            onChanged: _busy
                                ? null
                                : (value) =>
                                      _toggleGroupSelection(groupNumber, value),
                          ),
                          Text('Group $groupNumber'),
                        ],
                      ),
                    ),
                  );
                })
                .toList(growable: false),
          ),
        ],
      ),
    );
  }

  List<_GroupRoundSummary> _groupSummaries() {
    final summaries = _availableGroups
        .map((groupNumber) {
          final currentRound = _currentRoundForGroup(groupNumber);
          final currentRoundMatches = _currentRoundMatchesForGroup(groupNumber);
          final pendingMatches = currentRoundMatches
              .where(
                (match) =>
                    match.confirmedScore1 == null ||
                    match.confirmedScore2 == null,
              )
              .length;
          final completedMatches = currentRoundMatches.length - pendingMatches;
          return _GroupRoundSummary(
            groupNumber: groupNumber,
            playerCount: _playerCountForGroup(groupNumber),
            currentRound: currentRound,
            pendingMatches: pendingMatches,
            completedMatches: completedMatches,
            maxRounds: _maxRounds,
          );
        })
        .toList(growable: false);
    summaries.sort(
      (left, right) => left.groupNumber.compareTo(right.groupNumber),
    );
    return summaries;
  }

  Widget _buildSummaryHeaderCell({
    required String label,
    required double width,
    bool isLast = false,
  }) {
    final dividerColor = Theme.of(context).dividerColor.withValues(alpha: 0.6);
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        border: Border(
          right: isLast ? BorderSide.none : BorderSide(color: dividerColor),
        ),
      ),
      child: Text(
        label,
        textAlign: TextAlign.left,
        style: Theme.of(
          context,
        ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
      ),
    );
  }

  Widget _buildSummaryValueCell({
    required Widget child,
    required double width,
    bool isLast = false,
  }) {
    final dividerColor = Theme.of(context).dividerColor.withValues(alpha: 0.45);
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        border: Border(
          right: isLast ? BorderSide.none : BorderSide(color: dividerColor),
        ),
      ),
      child: child,
    );
  }

  Widget _buildGroupSummarySection() {
    final summaries = _groupSummaries();
    if (summaries.isEmpty) {
      return const Center(
        child: Text(
          'No groups found. Generate groups before creating match-ups.',
        ),
      );
    }

    const groupWidth = 130.0;
    const playersWidth = 110.0;
    const roundWidth = 150.0;
    const pendingWidth = 110.0;
    const completedWidth = 120.0;
    const tableWidth =
        groupWidth + playersWidth + roundWidth + pendingWidth + completedWidth;

    final scheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          'Groups (${summaries.length}) - Tap a row to show/hide match-ups',
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        LayoutBuilder(
          builder: (context, constraints) {
            final effectiveWidth = constraints.maxWidth > tableWidth
                ? constraints.maxWidth
                : tableWidth;
            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: effectiveWidth,
                child: Column(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerHighest.withValues(
                          alpha: 0.7,
                        ),
                        border: Border.all(
                          color: Theme.of(
                            context,
                          ).dividerColor.withValues(alpha: 0.6),
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          _buildSummaryHeaderCell(
                            label: 'Group',
                            width: groupWidth,
                          ),
                          _buildSummaryHeaderCell(
                            label: 'Players',
                            width: playersWidth,
                          ),
                          _buildSummaryHeaderCell(
                            label: 'Current Round',
                            width: roundWidth,
                          ),
                          _buildSummaryHeaderCell(
                            label: 'Pending',
                            width: pendingWidth,
                          ),
                          _buildSummaryHeaderCell(
                            label: 'Completed',
                            width: completedWidth,
                            isLast: true,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...summaries.map((summary) {
                      final expanded = _expandedGroupNumbers.contains(
                        summary.groupNumber,
                      );
                      final rowColor = expanded
                          ? scheme.primaryContainer.withValues(alpha: 0.3)
                          : scheme.surface;
                      return Column(
                        children: [
                          Material(
                            color: rowColor,
                            borderRadius: BorderRadius.circular(10),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(10),
                              onTap: () =>
                                  _toggleExpandedGroup(summary.groupNumber),
                              child: Container(
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: Theme.of(
                                      context,
                                    ).dividerColor.withValues(alpha: 0.45),
                                  ),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Row(
                                  children: [
                                    _buildSummaryValueCell(
                                      width: groupWidth,
                                      child: Row(
                                        children: [
                                          Icon(
                                            expanded
                                                ? Icons.keyboard_arrow_up
                                                : Icons.keyboard_arrow_down,
                                            size: 18,
                                          ),
                                          const SizedBox(width: 4),
                                          Text('Group ${summary.groupNumber}'),
                                        ],
                                      ),
                                    ),
                                    _buildSummaryValueCell(
                                      width: playersWidth,
                                      child: Text('${summary.playerCount}'),
                                    ),
                                    _buildSummaryValueCell(
                                      width: roundWidth,
                                      child: Text(
                                        '${summary.currentRound} / ${summary.maxRounds}',
                                      ),
                                    ),
                                    _buildSummaryValueCell(
                                      width: pendingWidth,
                                      child: Text('${summary.pendingMatches}'),
                                    ),
                                    _buildSummaryValueCell(
                                      width: completedWidth,
                                      child: Text(
                                        '${summary.completedMatches}',
                                      ),
                                      isLast: true,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          if (expanded) ...[
                            const SizedBox(height: 8),
                            _buildMatchupTableForGroup(summary.groupNumber),
                          ],
                          const SizedBox(height: 8),
                        ],
                      );
                    }),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildMatchupTableHeaderCell({
    required String label,
    required double width,
    bool isLast = false,
  }) {
    final dividerColor = Theme.of(context).dividerColor.withValues(alpha: 0.6);
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        border: Border(
          right: isLast ? BorderSide.none : BorderSide(color: dividerColor),
        ),
      ),
      child: Text(
        label,
        textAlign: TextAlign.left,
        style: Theme.of(
          context,
        ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
      ),
    );
  }

  Widget _buildMatchupTableValueCell({
    required Widget child,
    required double width,
    bool isLast = false,
  }) {
    final dividerColor = Theme.of(context).dividerColor.withValues(alpha: 0.45);
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        border: Border(
          right: isLast ? BorderSide.none : BorderSide(color: dividerColor),
        ),
      ),
      child: child,
    );
  }

  Widget _buildMatchupTableForGroup(int groupNumber) {
    final matches = _currentRoundMatchesForGroup(groupNumber);
    final currentRound = _currentRoundForGroup(groupNumber);
    final canDeleteRound = !_busy && currentRound > 0;

    final tableWidth =
        _srColumnWidth +
        _playerColumnWidth +
        _flagColumnWidth +
        _vsColumnWidth +
        _playerColumnWidth +
        _flagColumnWidth +
        _venueColumnWidth;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        border: Border.all(
          color: Theme.of(context).dividerColor.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 10,
            runSpacing: 8,
            children: [
              Text(
                currentRound == 0
                    ? 'Group $groupNumber: no round generated yet.'
                    : 'Group $groupNumber: round $currentRound match-ups',
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
              SizedBox(
                width: 220,
                child: SrrSplitActionButton(
                  label: _busy ? 'Working...' : 'Delete Current Round',
                  leadingIcon: Icons.delete_forever,
                  variant: SrrSplitActionButtonVariant.outlined,
                  onPressed: canDeleteRound
                      ? () => _deleteCurrentRoundForGroup(groupNumber)
                      : null,
                ),
              ),
            ],
          ),
          if (matches.isEmpty) ...[
            const SizedBox(height: 8),
            const Text(
              'No match-ups in current round for this group.',
              textAlign: TextAlign.center,
            ),
          ] else ...[
            const SizedBox(height: 8),
            LayoutBuilder(
              builder: (context, constraints) {
                final effectiveWidth = constraints.maxWidth > tableWidth
                    ? constraints.maxWidth
                    : tableWidth;
                return SizedBox(
                  height: 380,
                  child: SingleChildScrollView(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: SizedBox(
                        width: effectiveWidth,
                        child: Column(
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                color: Theme.of(context)
                                    .colorScheme
                                    .surfaceContainerHighest
                                    .withValues(alpha: 0.75),
                                border: Border.all(
                                  color: Theme.of(
                                    context,
                                  ).dividerColor.withValues(alpha: 0.6),
                                ),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                children: [
                                  _buildMatchupTableHeaderCell(
                                    label: 'Sr No',
                                    width: _srColumnWidth,
                                  ),
                                  _buildMatchupTableHeaderCell(
                                    label: 'Player 1',
                                    width: _playerColumnWidth,
                                  ),
                                  _buildMatchupTableHeaderCell(
                                    label: 'Player 1 Flag',
                                    width: _flagColumnWidth,
                                  ),
                                  _buildMatchupTableHeaderCell(
                                    label: 'V/s',
                                    width: _vsColumnWidth,
                                  ),
                                  _buildMatchupTableHeaderCell(
                                    label: 'Player 2',
                                    width: _playerColumnWidth,
                                  ),
                                  _buildMatchupTableHeaderCell(
                                    label: 'Player 2 Flag',
                                    width: _flagColumnWidth,
                                  ),
                                  _buildMatchupTableHeaderCell(
                                    label: 'Venue/Table #',
                                    width: _venueColumnWidth,
                                    isLast: true,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 6),
                            ...matches.asMap().entries.map((entry) {
                              final index = entry.key;
                              final match = entry.value;
                              final player1Flag = srrCountryFlagEmoji(
                                match.player1.country ?? '',
                              );
                              final player2Flag = srrCountryFlagEmoji(
                                match.player2.country ?? '',
                              );
                              final rowColor = index.isEven
                                  ? Theme.of(context).colorScheme.surface
                                  : Theme.of(
                                      context,
                                    ).colorScheme.surfaceContainerLow;

                              return Container(
                                margin: const EdgeInsets.only(bottom: 6),
                                decoration: BoxDecoration(
                                  color: rowColor,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: Theme.of(
                                      context,
                                    ).dividerColor.withValues(alpha: 0.45),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    _buildMatchupTableValueCell(
                                      width: _srColumnWidth,
                                      child: Text('${index + 1}'),
                                    ),
                                    _buildMatchupTableValueCell(
                                      width: _playerColumnWidth,
                                      child: Text(
                                        match.player1.displayName,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    _buildMatchupTableValueCell(
                                      width: _flagColumnWidth,
                                      child: Text(
                                        player1Flag.isEmpty ? '-' : player1Flag,
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(fontSize: 20),
                                      ),
                                    ),
                                    _buildMatchupTableValueCell(
                                      width: _vsColumnWidth,
                                      child: const Text(
                                        'V/s',
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                    _buildMatchupTableValueCell(
                                      width: _playerColumnWidth,
                                      child: Text(
                                        match.player2.displayName,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    _buildMatchupTableValueCell(
                                      width: _flagColumnWidth,
                                      child: Text(
                                        player2Flag.isEmpty ? '-' : player2Flag,
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(fontSize: 20),
                                      ),
                                    ),
                                    _buildMatchupTableValueCell(
                                      width: _venueColumnWidth,
                                      isLast: true,
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        children: [
                                          Text(
                                            'Table ${match.tableNumber}',
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodyMedium
                                                ?.copyWith(
                                                  fontWeight: FontWeight.w700,
                                                ),
                                          ),
                                          const SizedBox(height: 6),
                                          SizedBox(
                                            width: 140,
                                            child: SrrSplitActionButton(
                                              label: 'Edit Boards',
                                              variant:
                                                  SrrSplitActionButtonVariant
                                                      .outlined,
                                              leadingIcon:
                                                  Icons.table_chart_outlined,
                                              onPressed: _busy
                                                  ? null
                                                  : () =>
                                                        _openBoardEntryForMatch(
                                                          match,
                                                        ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.authService.currentAccount;
    final isAdmin = user?.isAdmin ?? false;
    final selectedTournament = _selectedTournament;
    final isTournamentSelectionLocked = widget.initialTournamentId != null;

    return SrrPageScaffold(
      title: 'Round Matchup',
      appState: widget.appState,
      actions: [
        IconButton(
          tooltip: 'Refresh',
          onPressed: _busy
              ? null
              : () =>
                    _loadContext(preferredTournamentId: _selectedTournamentId),
          icon: const Icon(Icons.refresh),
        ),
        if (isAdmin)
          IconButton(
            tooltip: 'Tournament Setup',
            onPressed: () {
              Navigator.pushReplacementNamed(
                context,
                SrrRoutes.tournamentSetup,
              );
            },
            icon: const Icon(Icons.construction),
          ),
      ],
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    user == null
                        ? 'Session is not loaded.'
                        : 'Signed in as ${user.displayName} (${user.role})',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    selectedTournament == null
                        ? 'Tournament: not selected'
                        : 'Tournament: ${srrTournamentDropdownLabel(selectedTournament)}',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Generate match-ups for selected groups in parallel. Table numbers are randomized per generated round.',
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (!isAdmin)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Round matchup is available only for admin accounts.',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          else if (_loading)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              ),
            )
          else
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        if (!isTournamentSelectionLocked)
                          SizedBox(
                            width: 380,
                            child: DropdownButtonFormField<int>(
                              initialValue: _selectedTournamentId,
                              decoration: const InputDecoration(
                                labelText: 'Tournament',
                              ),
                              items: _tournaments
                                  .map(
                                    (entry) => DropdownMenuItem<int>(
                                      value: entry.id,
                                      child: Text(
                                        srrTournamentDropdownLabel(entry),
                                      ),
                                    ),
                                  )
                                  .toList(growable: false),
                              onChanged: _busy ? null : _onTournamentChanged,
                            ),
                          ),
                        _buildMethodToggle(),
                        SizedBox(
                          width: 280,
                          child: SrrSplitActionButton(
                            label: _busy ? 'Working...' : 'Generate Match-Ups',
                            leadingIcon: Icons.auto_awesome,
                            variant: SrrSplitActionButtonVariant.filled,
                            onPressed: _canGenerateForSelectedGroups
                                ? _generateSelectedGroupsInParallel
                                : null,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildGroupSelectionPanel(),
                    const SizedBox(height: 10),
                    Text(
                      'Round 1 method: ${_roundOneMethods[_roundOneMethod] ?? _roundOneMethod}',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    _buildGroupSummarySection(),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _GroupRoundSummary {
  const _GroupRoundSummary({
    required this.groupNumber,
    required this.playerCount,
    required this.currentRound,
    required this.pendingMatches,
    required this.completedMatches,
    required this.maxRounds,
  });

  final int groupNumber;
  final int playerCount;
  final int currentRound;
  final int pendingMatches;
  final int completedMatches;
  final int maxRounds;
}

class _GroupGenerateAttempt {
  const _GroupGenerateAttempt({
    required this.groupNumber,
    required this.success,
    this.roundNumber,
    this.matchesCreated,
    this.error,
  });

  final int groupNumber;
  final bool success;
  final int? roundNumber;
  final int? matchesCreated;
  final String? error;
}
