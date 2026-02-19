// ---------------------------------------------------------------------------
// srr_app/lib/src/ui/srr_round_matchup_page.dart
// ---------------------------------------------------------------------------
//
// Purpose:
// - Generates and manages group-scoped round match-ups for Swiss rounds.
// Architecture:
// - Feature page coordinating matchup controls, round state, and per-group fixtures.
// - Delegates generation/deletion and tournament data access to repository and API layers.
// Author: Neil Khatu
// Copyright (c) The Khatu Family Trust
//
import 'package:catu_framework/catu_framework.dart';
import 'package:flutter/material.dart';

import '../api/srr_api_client.dart';
import '../models/srr_models.dart';
import '../repositories/srr_tournament_repository.dart';
import 'srr_page_scaffold.dart';
import 'srr_routes.dart';
import 'srr_split_action_button.dart';

class SrrRoundMatchupPage extends StatefulWidget {
  const SrrRoundMatchupPage({
    super.key,
    required this.appState,
    required this.apiClient,
    required this.tournamentRepository,
  });

  final AppState appState;
  final SrrApiClient apiClient;
  final SrrTournamentRepository tournamentRepository;

  @override
  State<SrrRoundMatchupPage> createState() => _SrrRoundMatchupPageState();
}

class _SrrRoundMatchupPageState extends State<SrrRoundMatchupPage> {
  static const _roundOneMethods = <String, String>{
    'adjacent': '1 vs 2, 3 vs 4',
    'top_vs_top': 'Top Half vs Top Bottom Half',
    'top_vs_bottom': 'Top Half vs Bottom Bottom Half',
  };

  bool _loading = true;
  bool _busy = false;
  String? _error;

  List<SrrTournamentRecord> _tournaments = const [];
  int? _selectedTournamentId;
  int? _selectedGroupNumber;
  String _roundOneMethod = 'adjacent';

  SrrTournamentGroupsSnapshot? _groupsSnapshot;
  List<SrrRound> _rounds = const [];

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

  List<SrrMatch> get _groupMatches {
    final groupNumber = _selectedGroupNumber;
    if (groupNumber == null) return const [];
    final matches = <SrrMatch>[];
    for (final round in _rounds) {
      for (final match in round.matches) {
        if (match.groupNumber == groupNumber) {
          matches.add(match);
        }
      }
    }
    matches.sort((a, b) {
      final byRound = a.roundNumber.compareTo(b.roundNumber);
      if (byRound != 0) return byRound;
      return a.tableNumber.compareTo(b.tableNumber);
    });
    return matches;
  }

  int get _maxRounds {
    final metadata = _selectedTournament?.metadata;
    return metadata == null ? 7 : metadata.srrRounds;
  }

  int get _currentRound {
    final matches = _groupMatches;
    if (matches.isEmpty) return 0;
    var maxRound = 0;
    for (final match in matches) {
      if (match.roundNumber > maxRound) {
        maxRound = match.roundNumber;
      }
    }
    return maxRound;
  }

  List<SrrMatch> get _currentRoundMatches {
    final currentRound = _currentRound;
    if (currentRound == 0) return const [];
    return _groupMatches
        .where((match) => match.roundNumber == currentRound)
        .toList(growable: false);
  }

  bool get _currentRoundComplete {
    final matches = _currentRoundMatches;
    if (matches.isEmpty) return true;
    return matches.every((match) => match.isConfirmed);
  }

  bool get _canGenerate {
    if (_busy) return false;
    if (_selectedTournamentId == null || _selectedGroupNumber == null) {
      return false;
    }
    final groupsGenerated = (_groupsSnapshot?.rows.isNotEmpty ?? false);
    if (!groupsGenerated) return false;
    final currentRound = _currentRound;
    if (currentRound >= _maxRounds) return false;
    if (currentRound > 0 && !_currentRoundComplete) return false;
    return true;
  }

  bool get _canDeleteCurrentRound {
    if (_busy) return false;
    if (_selectedTournamentId == null || _selectedGroupNumber == null) {
      return false;
    }
    return _currentRound > 0;
  }

  @override
  void initState() {
    super.initState();
    _loadContext();
  }

  Future<void> _loadContext({int? preferredTournamentId}) async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final tournaments = await widget.tournamentRepository.fetchTournaments();
      int? tournamentId = preferredTournamentId ?? _selectedTournamentId;
      if (tournamentId != null &&
          tournaments.every((entry) => entry.id != tournamentId)) {
        tournamentId = null;
      }
      tournamentId ??= tournaments.isEmpty ? null : tournaments.first.id;

      SrrTournamentGroupsSnapshot? groupsSnapshot;
      List<SrrRound> rounds = const [];
      if (tournamentId != null) {
        final results = await Future.wait<dynamic>([
          widget.tournamentRepository.fetchTournamentGroups(
            tournamentId: tournamentId,
          ),
          widget.apiClient.fetchRounds(tournamentId: tournamentId),
        ]);
        groupsSnapshot = results[0] as SrrTournamentGroupsSnapshot;
        rounds = results[1] as List<SrrRound>;
      }

      final availableGroups = (() {
        if (groupsSnapshot == null) return <int>[];
        final set = <int>{};
        for (final row in groupsSnapshot.rows) {
          if (row.groupNumber > 0) {
            set.add(row.groupNumber);
          }
        }
        final values = set.toList()..sort((a, b) => a - b);
        return values;
      })();

      int? selectedGroupNumber = _selectedGroupNumber;
      if (selectedGroupNumber != null &&
          !availableGroups.contains(selectedGroupNumber)) {
        selectedGroupNumber = null;
      }
      selectedGroupNumber ??= availableGroups.isEmpty
          ? null
          : availableGroups.first;

      if (!mounted) return;
      setState(() {
        _tournaments = tournaments;
        _selectedTournamentId = tournamentId;
        _groupsSnapshot = groupsSnapshot;
        _rounds = rounds;
        _selectedGroupNumber = selectedGroupNumber;
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
    _selectedGroupNumber = null;
    await _loadContext(preferredTournamentId: tournamentId);
  }

  void _onGroupChanged(int? groupNumber) {
    if (groupNumber == null || groupNumber == _selectedGroupNumber) return;
    setState(() {
      _selectedGroupNumber = groupNumber;
    });
  }

  Future<void> _generateNextRound() async {
    final tournamentId = _selectedTournamentId;
    final groupNumber = _selectedGroupNumber;
    if (!_canGenerate || tournamentId == null || groupNumber == null) return;

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final result = await widget.tournamentRepository
          .generateTournamentGroupMatchups(
            tournamentId: tournamentId,
            groupNumber: groupNumber,
            roundOneMethod: _roundOneMethod,
          );
      if (!mounted) return;
      await _loadContext(preferredTournamentId: result.tournament.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Group ${result.groupNumber}: round ${result.roundNumber} generated (${result.matchesCreated} matches).',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<bool> _confirmDeleteCurrentRound() async {
    final groupNumber = _selectedGroupNumber;
    if (groupNumber == null) return false;
    final currentRound = _currentRound;
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

  Future<void> _deleteCurrentRound() async {
    final tournamentId = _selectedTournamentId;
    final groupNumber = _selectedGroupNumber;
    if (!_canDeleteCurrentRound ||
        tournamentId == null ||
        groupNumber == null) {
      return;
    }

    final confirmed = await _confirmDeleteCurrentRound();
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Deleted round ${result.deletedRoundNumber} for Group ${result.groupNumber} (${result.deletedMatches} matches).',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
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
      constraints: const BoxConstraints(minWidth: 180, minHeight: 48),
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

  Widget _buildCurrentRoundTable() {
    final matches = _currentRoundMatches;
    if (_selectedGroupNumber == null) {
      return const Center(child: Text('Select a group to view match-ups.'));
    }
    if (matches.isEmpty) {
      return const Center(
        child: Text('No match-ups generated yet for this group.'),
      );
    }

    return ListView.separated(
      itemCount: matches.length,
      separatorBuilder: (_, index) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final match = matches[index];
        final scoreLabel =
            match.confirmedScore1 == null || match.confirmedScore2 == null
            ? 'Pending'
            : '${match.confirmedScore1} - ${match.confirmedScore2}';
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
            color: Theme.of(context).colorScheme.surfaceContainerLow,
          ),
          child: Row(
            children: [
              SizedBox(
                width: 80,
                child: Text(
                  'T${match.tableNumber}',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              Expanded(
                child: Text(
                  '${match.player1.displayName} vs ${match.player2.displayName}',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 120,
                child: Text(
                  scoreLabel,
                  textAlign: TextAlign.right,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.apiClient.currentUserSnapshot;
    final isAdmin = user?.isAdmin ?? false;
    final selectedTournament = _selectedTournament;
    final groupCount = _availableGroups.length;
    final currentRound = _currentRound;

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
        padding: const EdgeInsets.all(16),
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
                        : 'Tournament: ${selectedTournament.name} (${selectedTournament.status})',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'When match-ups are generated, tournament setup is locked and status becomes Active.',
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
                        SizedBox(
                          width: 360,
                          child: DropdownButtonFormField<int>(
                            initialValue: _selectedTournamentId,
                            decoration: const InputDecoration(
                              labelText: 'Tournament',
                            ),
                            items: _tournaments
                                .map(
                                  (entry) => DropdownMenuItem<int>(
                                    value: entry.id,
                                    child: Text(entry.name),
                                  ),
                                )
                                .toList(growable: false),
                            onChanged: _busy ? null : _onTournamentChanged,
                          ),
                        ),
                        SizedBox(
                          width: 220,
                          child: DropdownButtonFormField<int>(
                            initialValue: _selectedGroupNumber,
                            decoration: const InputDecoration(
                              labelText: 'Group',
                            ),
                            items: _availableGroups
                                .map(
                                  (groupNumber) => DropdownMenuItem<int>(
                                    value: groupNumber,
                                    child: Text('Group $groupNumber'),
                                  ),
                                )
                                .toList(growable: false),
                            onChanged: _busy ? null : _onGroupChanged,
                          ),
                        ),
                        _buildMethodToggle(),
                        SizedBox(
                          width: 220,
                          child: SrrSplitActionButton(
                            label: _busy ? 'Working...' : 'Generate Next Round',
                            leadingIcon: Icons.auto_awesome,
                            variant: SrrSplitActionButtonVariant.filled,
                            onPressed: _canGenerate ? _generateNextRound : null,
                          ),
                        ),
                        SizedBox(
                          width: 220,
                          child: SrrSplitActionButton(
                            label: _busy
                                ? 'Working...'
                                : 'Delete Current Round',
                            leadingIcon: Icons.delete_forever,
                            variant: SrrSplitActionButtonVariant.outlined,
                            onPressed: _canDeleteCurrentRound
                                ? _deleteCurrentRound
                                : null,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Groups available: $groupCount | Current group round: $currentRound / $_maxRounds',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _currentRoundComplete
                          ? 'Current group round is complete.'
                          : 'Current group round has pending matches. Next round generation is disabled.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Round 1 method selected: ${_roundOneMethods[_roundOneMethod] ?? _roundOneMethod}',
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
                    SizedBox(height: 520, child: _buildCurrentRoundTable()),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
