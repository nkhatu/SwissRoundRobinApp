// ---------------------------------------------------------------------------
// srr_app/lib/src/ui/srr_tournament_seeding_page.dart
// ---------------------------------------------------------------------------
//
// Purpose:
// - Builds and edits tournament seeding order, including drag-reorder workflows.
// Architecture:
// - Feature page that manages seeding UI state, generation, and update actions.
// - Delegates seeding data retrieval and persistence to tournament repository APIs.
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
import 'srr_upload_page.dart';

class SrrTournamentSeedingPageArguments {
  const SrrTournamentSeedingPageArguments({this.tournamentId});

  final int? tournamentId;
}

class SrrTournamentSeedingPage extends StatefulWidget {
  const SrrTournamentSeedingPage({
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
  State<SrrTournamentSeedingPage> createState() =>
      _SrrTournamentSeedingPageState();
}

class _SrrTournamentSeedingPageState extends State<SrrTournamentSeedingPage> {
  static const double _nameColumnWidth = 360;
  static const double _countryColumnWidth = 240;
  static const double _rankColumnWidth = 190;
  static const double _seedingColumnWidth = 220;

  bool _loading = true;
  bool _busy = false;
  String? _loadError;

  List<SrrTournamentRecord> _tournaments = const [];
  int? _selectedTournamentId;
  SrrTournamentSeedingSnapshot? _snapshot;
  List<SrrTournamentSeedingRow> _rows = const [];
  bool _hasUnsavedOrder = false;

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

      SrrTournamentSeedingSnapshot? snapshot;
      String? error;
      if (tournamentId != null) {
        try {
          snapshot = await widget.tournamentRepository.fetchTournamentSeeding(
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
        _rows = _normalizedRows(snapshot?.rows ?? const []);
        _hasUnsavedOrder = false;
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
      _rows = const [];
      _hasUnsavedOrder = false;
      _loadError = null;
      _loading = true;
    });
    try {
      final snapshot = await widget.tournamentRepository.fetchTournamentSeeding(
        tournamentId: tournamentId,
      );
      if (!mounted) return;
      setState(() {
        _snapshot = snapshot;
        _rows = _normalizedRows(snapshot.rows);
        _hasUnsavedOrder = false;
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

  List<SrrTournamentSeedingRow> _normalizedRows(
    List<SrrTournamentSeedingRow> rows,
  ) {
    final sorted = [...rows]..sort((a, b) => a.seed.compareTo(b.seed));
    for (var index = 0; index < sorted.length; index += 1) {
      sorted[index] = sorted[index].copyWith(seed: index + 1);
    }
    return sorted;
  }

  Future<void> _generateSeeding() async {
    final tournamentId = _selectedTournamentId;
    if (_busy || tournamentId == null) return;
    setState(() {
      _busy = true;
      _loadError = null;
    });
    try {
      final snapshot = await widget.tournamentRepository
          .generateTournamentSeeding(tournamentId: tournamentId);
      if (!mounted) return;
      setState(() {
        _snapshot = snapshot;
        _rows = _normalizedRows(snapshot.rows);
        _hasUnsavedOrder = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Generated seeding for ${snapshot.tournament.name} (${snapshot.rows.length} players).',
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

  Future<void> _saveOrder() async {
    final tournamentId = _selectedTournamentId;
    if (_busy || tournamentId == null || !_hasUnsavedOrder || _rows.isEmpty) {
      return;
    }
    setState(() {
      _busy = true;
      _loadError = null;
    });
    try {
      if (!(_snapshot?.seeded ?? false)) {
        await widget.tournamentRepository.generateTournamentSeeding(
          tournamentId: tournamentId,
        );
      }
      final updated = await widget.tournamentRepository
          .reorderTournamentSeeding(
            tournamentId: tournamentId,
            orderedPlayerIds: _rows
                .map((row) => row.playerId)
                .toList(growable: false),
          );
      if (!mounted) return;
      setState(() {
        _snapshot = updated;
        _rows = _normalizedRows(updated.rows);
        _hasUnsavedOrder = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tournament seeding order saved.')),
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

  Future<bool> _confirmDeleteSeeding() async {
    final selected = _selectedTournament;
    final tournamentName = selected?.name ?? 'this tournament';
    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete Tournament Seeding'),
          content: Text(
            'Delete all saved seeding rows for "$tournamentName"? This resets step 4 to pending.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            SizedBox(
              width: 170,
              child: SrrSplitActionButton(
                label: 'Delete Seeding',
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

  Future<void> _deleteSeeding() async {
    final tournamentId = _selectedTournamentId;
    if (_busy || tournamentId == null) return;
    final confirmed = await _confirmDeleteSeeding();
    if (!confirmed || !mounted) return;

    setState(() {
      _busy = true;
      _loadError = null;
    });
    try {
      final result = await widget.tournamentRepository.deleteTournamentSeeding(
        tournamentId: tournamentId,
      );
      if (!mounted) return;
      await _loadContext(preferredTournamentId: result.tournament.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Deleted ${result.deletedRows} saved seeding row(s) for ${result.tournament.name}.',
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

  void _reorderRows(int oldIndex, int newIndex) {
    if (_busy || _rows.isEmpty) return;
    setState(() {
      var target = newIndex;
      if (oldIndex < target) target -= 1;
      final nextRows = [..._rows];
      final moved = nextRows.removeAt(oldIndex);
      nextRows.insert(target, moved);
      for (var index = 0; index < nextRows.length; index += 1) {
        nextRows[index] = nextRows[index].copyWith(seed: index + 1);
      }
      _rows = nextRows;
      _hasUnsavedOrder = true;
    });
  }

  String _nationalRankLabel(SrrTournamentSeedingRow row) {
    if (row.isNational && row.rankingRank != null && row.rankingRank! > 0) {
      return '${row.rankingRank}';
    }
    return 'Un-Seeded';
  }

  Widget _buildSummaryLine(SrrTournamentSeedingSummary summary) {
    return Text(
      'National: ${summary.nationalPlayers} | International: ${summary.internationalPlayers} | New: ${summary.newPlayers} | Total: ${_rows.length}',
      textAlign: TextAlign.center,
      style: Theme.of(context).textTheme.bodyMedium,
    );
  }

  Widget _buildHeaderCell({
    required String label,
    required double width,
    bool isLast = false,
  }) {
    final dividerColor = Theme.of(context).dividerColor.withValues(alpha: 0.6);
    return Container(
      width: width,
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

  Widget _buildValueCell({
    required Widget child,
    required double width,
    bool isLast = false,
  }) {
    final dividerColor = Theme.of(context).dividerColor.withValues(alpha: 0.45);
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        border: Border(
          right: isLast ? BorderSide.none : BorderSide(color: dividerColor),
        ),
      ),
      child: child,
    );
  }

  String _generatedAtLabel() {
    final generatedAt = _snapshot?.generatedAt;
    if (generatedAt == null) {
      return 'Seeding not saved yet';
    }
    return widget.displayPreferencesController.formatDateTime(
      generatedAt,
      fallbackLocale: Localizations.localeOf(context),
    );
  }

  Widget _buildReorderList() {
    if (_rows.isEmpty) {
      return const Center(
        child: Text('No players available for seeding in this tournament.'),
      );
    }
    final tableWidth =
        _nameColumnWidth +
        _countryColumnWidth +
        _rankColumnWidth +
        _seedingColumnWidth;
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
                children: [
                  _buildHeaderCell(label: 'Name', width: _nameColumnWidth),
                  _buildHeaderCell(
                    label: 'Country',
                    width: _countryColumnWidth,
                  ),
                  _buildHeaderCell(
                    label: 'National Rank',
                    width: _rankColumnWidth,
                  ),
                  _buildHeaderCell(
                    label: 'Tournament Seeding',
                    width: _seedingColumnWidth,
                    isLast: true,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ReorderableListView.builder(
                buildDefaultDragHandles: false,
                onReorder: _busy ? (oldIndex, newIndex) {} : _reorderRows,
                itemCount: _rows.length,
                itemBuilder: (context, index) {
                  final row = _rows[index];
                  final flag = srrCountryFlagEmoji(row.country);
                  final countryLabel = row.country.trim().isEmpty
                      ? 'Unknown'
                      : row.country.trim();
                  final surfaceColor = index.isEven
                      ? scheme.surface
                      : scheme.surfaceContainerLow;
                  return Container(
                    key: ValueKey(row.playerId),
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
                      children: [
                        _buildValueCell(
                          width: _nameColumnWidth,
                          child: Text(
                            row.displayName,
                            textAlign: TextAlign.left,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                        ),
                        _buildValueCell(
                          width: _countryColumnWidth,
                          child: Row(
                            children: [
                              if (flag.isNotEmpty)
                                Text(flag, style: const TextStyle(fontSize: 20))
                              else
                                Icon(
                                  Icons.public,
                                  size: 18,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  countryLabel,
                                  textAlign: TextAlign.left,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                        _buildValueCell(
                          width: _rankColumnWidth,
                          child: Text(
                            _nationalRankLabel(row),
                            textAlign: TextAlign.left,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: _nationalRankLabel(row) == 'Un-Seeded'
                                      ? Theme.of(context).colorScheme.error
                                      : null,
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                        ),
                        _buildValueCell(
                          width: _seedingColumnWidth,
                          isLast: true,
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  '${row.seed}',
                                  textAlign: TextAlign.left,
                                  style: Theme.of(context).textTheme.bodyLarge
                                      ?.copyWith(fontWeight: FontWeight.w700),
                                ),
                              ),
                              _busy
                                  ? const Icon(Icons.drag_indicator)
                                  : ReorderableDragStartListener(
                                      index: index,
                                      child: const Icon(Icons.drag_indicator),
                                    ),
                            ],
                          ),
                        ),
                      ],
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
    final rankingLabel = _snapshot == null
        ? '-'
        : '${_snapshot!.rankingYear} - ${_snapshot!.rankingDescription}';

    return SrrPageScaffold(
      title: 'Tournament Seeding',
      appState: widget.appState,
      actions: [
        if (isAdmin) ...[
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
          IconButton(
            tooltip: 'Player Upload',
            onPressed: () {
              Navigator.pushNamed(
                context,
                SrrRoutes.genericUpload,
                arguments: SrrUploadPageArguments(
                  context: SrrUploadContext.players,
                  tournamentId: _selectedTournamentId,
                ),
              );
            },
            icon: const Icon(Icons.upload_file),
          ),
        ],
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
                  'Tournament seeding is available only for admin accounts.',
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
                          width: 220,
                          child: SrrSplitActionButton(
                            label: _busy ? 'Processing...' : 'Generate Seeding',
                            leadingIcon: Icons.auto_graph,
                            variant: SrrSplitActionButtonVariant.filled,
                            onPressed: _busy || _selectedTournamentId == null
                                ? null
                                : _generateSeeding,
                          ),
                        ),
                        SizedBox(
                          width: 220,
                          child: SrrSplitActionButton(
                            label: _busy ? 'Saving...' : 'Save Order',
                            leadingIcon: Icons.save,
                            variant: _hasUnsavedOrder
                                ? SrrSplitActionButtonVariant.filled
                                : SrrSplitActionButtonVariant.outlined,
                            onPressed: _busy || !_hasUnsavedOrder
                                ? null
                                : _saveOrder,
                          ),
                        ),
                        SizedBox(
                          width: 220,
                          child: SrrSplitActionButton(
                            label: _busy ? 'Working...' : 'Delete Seeding',
                            leadingIcon: Icons.delete_forever,
                            variant: SrrSplitActionButtonVariant.outlined,
                            onPressed:
                                _busy ||
                                    _selectedTournamentId == null ||
                                    _rows.isEmpty
                                ? null
                                : _deleteSeeding,
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
                      'Selected ranking: $rankingLabel',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    if ((_snapshot?.nationalCountry ?? '').isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        'National country inferred from ranking: ${_snapshot!.nationalCountry}',
                        textAlign: TextAlign.center,
                      ),
                    ],
                    const SizedBox(height: 10),
                    if (_snapshot != null)
                      _buildSummaryLine(_snapshot!.summary),
                    if (!(_snapshot?.seeded ?? false)) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Preview is shown. Generate seeding to persist to database.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ],
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
                    SizedBox(height: 620, child: _buildReorderList()),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
