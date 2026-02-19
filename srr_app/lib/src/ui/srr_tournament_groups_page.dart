// ---------------------------------------------------------------------------
// srr_app/lib/src/ui/srr_tournament_groups_page.dart
// ---------------------------------------------------------------------------
//
// Purpose:
// - Generates and displays tournament groups from seeded players using interleaved or snake distribution.
// Architecture:
// - Feature page coordinating grouping method selection, generation actions, and grouped table rendering.
// - Delegates persistence and workflow state changes to tournament repository APIs.
// Author: Neil Khatu
// Copyright (c) The Khatu Family Trust
//
import 'package:catu_framework/catu_framework.dart';
import 'package:flutter/material.dart';

import '../api/srr_api_client.dart';
import '../models/srr_models.dart';
import '../repositories/srr_tournament_repository.dart';
import '../services/srr_country_iso.dart';
import '../services/srr_tournament_labels.dart';
import '../theme/srr_display_preferences_controller.dart';
import 'srr_page_scaffold.dart';
import 'srr_routes.dart';
import 'srr_split_action_button.dart';

class SrrTournamentGroupsPageArguments {
  const SrrTournamentGroupsPageArguments({this.tournamentId});

  final int? tournamentId;
}

class SrrTournamentGroupsPage extends StatefulWidget {
  const SrrTournamentGroupsPage({
    super.key,
    required this.appState,
    required this.apiClient,
    required this.tournamentRepository,
    required this.displayPreferencesController,
    this.initialTournamentId,
  });

  final AppState appState;
  final SrrApiClient apiClient;
  final SrrTournamentRepository tournamentRepository;
  final SrrDisplayPreferencesController displayPreferencesController;
  final int? initialTournamentId;

  @override
  State<SrrTournamentGroupsPage> createState() =>
      _SrrTournamentGroupsPageState();
}

class _SrrTournamentGroupsPageState extends State<SrrTournamentGroupsPage> {
  static const double _groupColumnWidth = 270;

  bool _loading = true;
  bool _busy = false;
  String? _loadError;

  List<SrrTournamentRecord> _tournaments = const [];
  int? _selectedTournamentId;
  SrrTournamentGroupsSnapshot? _snapshot;
  String _selectedMethod = SrrTournamentGroupingMethod.interleaved;

  SrrTournamentRecord? get _selectedTournament {
    final tournamentId = _selectedTournamentId;
    if (tournamentId == null) return null;
    for (final tournament in _tournaments) {
      if (tournament.id == tournamentId) return tournament;
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _loadContext(preferredTournamentId: widget.initialTournamentId);
  }

  Future<void> _loadContext({int? preferredTournamentId}) async {
    setState(() {
      _loading = true;
      _loadError = null;
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

      SrrTournamentGroupsSnapshot? snapshot;
      String? error;
      if (tournamentId != null) {
        try {
          snapshot = await widget.tournamentRepository.fetchTournamentGroups(
            tournamentId: tournamentId,
          );
        } catch (innerError) {
          error = innerError.toString();
        }
      }

      if (!mounted) return;
      setState(() {
        _tournaments = tournaments;
        _selectedTournamentId = tournamentId;
        _snapshot = snapshot;
        _selectedMethod =
            snapshot?.method ?? SrrTournamentGroupingMethod.interleaved;
        _loadError = error;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = error.toString();
      });
    }
  }

  Future<void> _onTournamentChanged(int? tournamentId) async {
    if (tournamentId == null || tournamentId == _selectedTournamentId) return;
    setState(() {
      _selectedTournamentId = tournamentId;
      _snapshot = null;
      _selectedMethod = SrrTournamentGroupingMethod.interleaved;
      _loadError = null;
      _loading = true;
    });

    try {
      final snapshot = await widget.tournamentRepository.fetchTournamentGroups(
        tournamentId: tournamentId,
      );
      if (!mounted) return;
      setState(() {
        _snapshot = snapshot;
        _selectedMethod = snapshot.method ?? _selectedMethod;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = error.toString();
      });
    }
  }

  Future<void> _generateGroups() async {
    final tournamentId = _selectedTournamentId;
    if (_busy || tournamentId == null) return;

    setState(() {
      _busy = true;
      _loadError = null;
    });

    try {
      if (_snapshot?.rows.isNotEmpty ?? false) {
        await widget.tournamentRepository.deleteTournamentGroups(
          tournamentId: tournamentId,
        );
      }
      final snapshot = await widget.tournamentRepository
          .generateTournamentGroups(
            tournamentId: tournamentId,
            method: _selectedMethod,
          );
      if (!mounted) return;
      setState(() {
        _snapshot = snapshot;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Created ${snapshot.groupCount} groups for ${snapshot.tournament.name}.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _loadError = error.toString());
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<bool> _confirmDeleteGroups() async {
    final tournamentName = _selectedTournament?.name ?? 'this tournament';
    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete Tournament Groups'),
          content: Text(
            'Delete generated groups for "$tournamentName" and reset this workflow step?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            SizedBox(
              width: 170,
              child: SrrSplitActionButton(
                label: 'Delete Groups',
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

  Future<void> _deleteGroups() async {
    final tournamentId = _selectedTournamentId;
    if (_busy || tournamentId == null) return;
    final confirmed = await _confirmDeleteGroups();
    if (!confirmed || !mounted) return;

    setState(() {
      _busy = true;
      _loadError = null;
    });
    try {
      final result = await widget.tournamentRepository.deleteTournamentGroups(
        tournamentId: tournamentId,
      );
      if (!mounted) return;
      await _loadContext(preferredTournamentId: result.tournament.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Deleted ${result.deletedRows} grouped row(s) for ${result.tournament.name}.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _loadError = error.toString());
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  String _nationalRankLabel(SrrTournamentGroupRow row) {
    if (row.sourceType == 'national' &&
        row.rankingRank != null &&
        row.rankingRank! > 0) {
      return '${row.rankingRank}';
    }
    return 'Un-Seeded';
  }

  String _tournamentSeedingLabel(SrrTournamentGroupRow row) {
    final rankLabel = _nationalRankLabel(row);
    return rankLabel == 'Un-Seeded'
        ? 'TS ${row.seed} (US Rank : Un-Seeded)'
        : 'TS ${row.seed} (US Rank : $rankLabel)';
  }

  String _methodLabel(String method) {
    switch (method) {
      case SrrTournamentGroupingMethod.snake:
        return 'Snake';
      case SrrTournamentGroupingMethod.interleaved:
      default:
        return 'Interleaved';
    }
  }

  String _generatedAtLabel() {
    final generatedAt = _snapshot?.generatedAt;
    if (generatedAt == null) {
      return 'Groups not generated yet';
    }
    return widget.displayPreferencesController.formatDateTime(
      generatedAt,
      fallbackLocale: Localizations.localeOf(context),
    );
  }

  List<List<SrrTournamentGroupRow?>> _groupMatrixRows() {
    final snapshot = _snapshot;
    if (snapshot == null || snapshot.rows.isEmpty) {
      return const [];
    }

    final groupCount = snapshot.groupCount;
    final groupedRows = <int, List<SrrTournamentGroupRow>>{};
    for (var groupNumber = 1; groupNumber <= groupCount; groupNumber += 1) {
      groupedRows[groupNumber] = <SrrTournamentGroupRow>[];
    }
    for (final row in snapshot.rows) {
      final bucket = groupedRows[row.groupNumber] ?? <SrrTournamentGroupRow>[];
      bucket.add(row);
      groupedRows[row.groupNumber] = bucket;
    }
    for (final bucket in groupedRows.values) {
      bucket.sort((a, b) => a.seed.compareTo(b.seed));
    }

    var maxRows = 0;
    for (final bucket in groupedRows.values) {
      if (bucket.length > maxRows) maxRows = bucket.length;
    }

    final matrix = <List<SrrTournamentGroupRow?>>[];
    for (var index = 0; index < maxRows; index += 1) {
      final row = <SrrTournamentGroupRow?>[];
      for (var groupNumber = 1; groupNumber <= groupCount; groupNumber += 1) {
        final bucket =
            groupedRows[groupNumber] ?? const <SrrTournamentGroupRow>[];
        row.add(index < bucket.length ? bucket[index] : null);
      }
      matrix.add(row);
    }
    return matrix;
  }

  Widget _buildHeaderCell({required String label, required bool isLast}) {
    final dividerColor = Theme.of(context).dividerColor.withValues(alpha: 0.6);
    return Container(
      width: _groupColumnWidth,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
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

  Widget _buildGroupCell({
    required SrrTournamentGroupRow? row,
    required bool isLast,
  }) {
    final dividerColor = Theme.of(context).dividerColor.withValues(alpha: 0.45);
    final rankLabel = row == null ? '-' : _nationalRankLabel(row);
    final seedingLabel = row == null ? '-' : _tournamentSeedingLabel(row);
    final flag = row == null ? '' : srrCountryFlagEmoji(row.country);

    return Container(
      width: _groupColumnWidth,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        border: Border(
          right: isLast ? BorderSide.none : BorderSide(color: dividerColor),
        ),
      ),
      child: row == null
          ? const Text('-', textAlign: TextAlign.left)
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  row.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 3),
                Text(
                  seedingLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: rankLabel == 'Un-Seeded'
                        ? Theme.of(context).colorScheme.error
                        : Theme.of(context).colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    if (flag.isNotEmpty)
                      Text(flag, style: const TextStyle(fontSize: 15))
                    else
                      Icon(
                        Icons.public,
                        size: 14,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        row.country.trim().isEmpty
                            ? 'Unknown'
                            : row.country.trim(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ],
            ),
    );
  }

  Widget _buildGroupTable() {
    final matrixRows = _groupMatrixRows();
    final snapshot = _snapshot;
    if (snapshot == null || matrixRows.isEmpty) {
      return const Center(
        child: Text(
          'No groups generated yet. Select method and click Create Groups.',
        ),
      );
    }

    final groupCount = snapshot.groupCount;
    final tableWidth = _groupColumnWidth * groupCount;
    final scheme = Theme.of(context).colorScheme;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SizedBox(
        width: tableWidth,
        child: Column(
          children: [
            Container(
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest.withValues(alpha: 0.7),
                border: Border.all(
                  color: Theme.of(context).dividerColor.withValues(alpha: 0.6),
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: List<Widget>.generate(groupCount, (index) {
                  return _buildHeaderCell(
                    label: 'Group ${index + 1}',
                    isLast: index == groupCount - 1,
                  );
                }),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                itemCount: matrixRows.length,
                itemBuilder: (context, rowIndex) {
                  final row = matrixRows[rowIndex];
                  final surfaceColor = rowIndex.isEven
                      ? scheme.surface
                      : scheme.surfaceContainerLow;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    decoration: BoxDecoration(
                      color: surfaceColor,
                      border: Border.all(
                        color: Theme.of(
                          context,
                        ).dividerColor.withValues(alpha: 0.45),
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: List<Widget>.generate(groupCount, (colIndex) {
                        return _buildGroupCell(
                          row: row[colIndex],
                          isLast: colIndex == groupCount - 1,
                        );
                      }),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.apiClient.currentUserSnapshot;
    final isAdmin = user?.isAdmin ?? false;
    final selectedTournament = _selectedTournament;
    final isTournamentSelectionLocked = widget.initialTournamentId != null;

    return SrrPageScaffold(
      title: 'Create Groups',
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
                    'Last generated: ${_generatedAtLabel()}',
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
                  'Create Groups is available only for admin accounts.',
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
                                      child: Text(
                                        srrTournamentDropdownLabel(entry),
                                      ),
                                    ),
                                  )
                                  .toList(growable: false),
                              onChanged: _busy ? null : _onTournamentChanged,
                            ),
                          ),
                        SizedBox(
                          width: 460,
                          child: ToggleButtons(
                            isSelected: <bool>[
                              _selectedMethod ==
                                  SrrTournamentGroupingMethod.interleaved,
                              _selectedMethod ==
                                  SrrTournamentGroupingMethod.snake,
                            ],
                            onPressed: _busy
                                ? null
                                : (index) {
                                    setState(() {
                                      _selectedMethod = index == 0
                                          ? SrrTournamentGroupingMethod
                                                .interleaved
                                          : SrrTournamentGroupingMethod.snake;
                                    });
                                  },
                            constraints: const BoxConstraints(
                              minWidth: 220,
                              minHeight: 50,
                            ),
                            borderRadius: BorderRadius.circular(12),
                            children: const [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.drag_indicator, size: 18),
                                  SizedBox(width: 8),
                                  Text('Interleaved'),
                                ],
                              ),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.swap_horiz, size: 18),
                                  SizedBox(width: 8),
                                  Text('Snake'),
                                ],
                              ),
                            ],
                          ),
                        ),
                        SizedBox(
                          width: 220,
                          child: SrrSplitActionButton(
                            label: _busy ? 'Working...' : 'Create Groups',
                            leadingIcon: Icons.group_work,
                            variant: SrrSplitActionButtonVariant.filled,
                            onPressed: _busy || _selectedTournamentId == null
                                ? null
                                : _generateGroups,
                          ),
                        ),
                        SizedBox(
                          width: 220,
                          child: SrrSplitActionButton(
                            label: _busy ? 'Working...' : 'Delete Groups',
                            leadingIcon: Icons.delete_forever,
                            variant: SrrSplitActionButtonVariant.outlined,
                            onPressed:
                                _busy || (_snapshot?.rows.isEmpty ?? true)
                                ? null
                                : _deleteGroups,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      selectedTournament == null
                          ? 'No tournament selected.'
                          : 'Tournament: ${srrTournamentDropdownLabel(selectedTournament)}',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Grouping method: ${_methodLabel(_selectedMethod)} | Group count: ${_snapshot?.groupCount ?? selectedTournament?.metadata?.numberOfGroups ?? 4}',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _selectedMethod == SrrTournamentGroupingMethod.snake
                          ? 'Snake: direction alternates each row of seeds.'
                          : 'Interleaved: seeds fill Group 1..N repeatedly.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Create Groups replaces any existing groups for the selected tournament.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    if (_loadError != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        _loadError!,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    SizedBox(height: 620, child: _buildGroupTable()),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
