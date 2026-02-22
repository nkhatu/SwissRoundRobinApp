// ---------------------------------------------------------------------------
// srr_app/lib/src/ui/tournament/srr_match_score_entry_page.dart
// ---------------------------------------------------------------------------
//
// Purpose:
// - Lets a player or admin submit per-board scores for a match.
// Architecture:
// - Fetches the match via the dashboard repository, renders a score-sheet style grid,
//   and posts a carrom payload back to the confirm API.
// - Keeps entry logic in a local board model so future score forms can reuse the pattern.
// Author: Neil Khatu
// Copyright (c) The Khatu Family Trust
//
import 'package:flutter/material.dart';

import '../../api/api_exceptions.dart';
import '../../models/srr_enums.dart';
import '../../models/srr_match_models.dart';
import '../../repositories/srr_dashboard_repository.dart';
import '../../services/srr_country_iso.dart';
import '../helpers/srr_split_action_button.dart';

const _minBoards = 1;
const _maxBoards = 9;
const _maxCoinsPerColor = 9;
const _queenPoints = 3;
const _maxBoardScore = 13;
const _targetGameScore = 25;

class SrrMatchScoreEntryPageArguments {
  const SrrMatchScoreEntryPageArguments({
    required this.matchId,
    this.tournamentId,
    this.tournamentName,
  });

  final int matchId;
  final int? tournamentId;
  final String? tournamentName;
}

class SrrMatchScoreEntryPage extends StatefulWidget {
  const SrrMatchScoreEntryPage({
    super.key,
    required this.dashboardRepository,
    required this.matchId,
    this.tournamentId,
    this.tournamentName,
  });

  final SrrDashboardRepository dashboardRepository;
  final int matchId;
  final int? tournamentId;
  final String? tournamentName;

  @override
  State<SrrMatchScoreEntryPage> createState() => _SrrMatchScoreEntryPageState();
}

class _SrrMatchScoreEntryPageState extends State<SrrMatchScoreEntryPage> {
  static const double _actionColumnWidth = 64;
  static const double _queenColumnWidth = 76;
  static const double _coinsColumnWidth = 76;
  static const double _boardScoreColumnWidth = 112;
  static const double _runningTotalColumnWidth = 122;
  static const double _boardNumberColumnWidth = 84;
  static const double _rowHeight = 44;
  static const double _headerRowHeight = 42;

  bool _loading = true;
  bool _submitting = false;
  String? _error;
  SrrMatch? _match;
  final List<_BoardEntry> _boardEntries = <_BoardEntry>[];
  bool _winnerConfirmed = false;
  int? _confirmedWinnerPlayerId;

  @override
  void initState() {
    super.initState();
    _loadMatch();
  }

  @override
  void dispose() {
    for (final entry in _boardEntries) {
      entry.dispose();
    }
    super.dispose();
  }

  Future<void> _loadMatch() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rounds = await widget.dashboardRepository.fetchRounds(
        tournamentId: widget.tournamentId,
      );
      final match = rounds
          .expand((round) => round.matches)
          .firstWhere(
            (entry) => entry.id == widget.matchId,
            orElse: () => throw Exception('Match not found.'),
          );
      if (!mounted) return;
      _populateBoards(match);
      setState(() => _match = match);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _populateBoards(SrrMatch match) {
    for (final entry in _boardEntries) {
      entry.dispose();
    }
    _boardEntries.clear();

    if (match.boards.isEmpty) {
      _boardEntries.add(_BoardEntry(boardNumber: 1));
      return;
    }

    final sortedBoards = [...match.boards]
      ..sort((left, right) => left.boardNumber - right.boardNumber);
    for (final board in sortedBoards.take(_maxBoards)) {
      _boardEntries.add(_BoardEntry.fromBoard(board));
    }
    if (_boardEntries.isEmpty) {
      _boardEntries.add(_BoardEntry(boardNumber: 1));
    }
    _reindexBoards();

    final confirmedScore1 = match.confirmedScore1;
    final confirmedScore2 = match.confirmedScore2;
    if (confirmedScore1 != null &&
        confirmedScore2 != null &&
        confirmedScore1 != confirmedScore2) {
      _winnerConfirmed = true;
      _confirmedWinnerPlayerId = confirmedScore1 > confirmedScore2
          ? match.player1.id
          : match.player2.id;
    } else {
      _winnerConfirmed = false;
      _confirmedWinnerPlayerId = null;
    }
  }

  void _reindexBoards() {
    for (var index = 0; index < _boardEntries.length; index++) {
      _boardEntries[index].boardNumber = index + 1;
    }
  }

  void _addBoardAfter(int index) {
    if (_boardEntries.length >= _maxBoards) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Maximum 9 boards are supported.')),
      );
      return;
    }
    setState(() {
      _boardEntries.insert(index + 1, _BoardEntry(boardNumber: 0));
      _reindexBoards();
      _error = null;
      _winnerConfirmed = false;
      _confirmedWinnerPlayerId = null;
    });
  }

  void _removeBoardAt(int index) {
    if (_boardEntries.length <= _minBoards) return;
    setState(() {
      final removed = _boardEntries.removeAt(index);
      removed.dispose();
      _reindexBoards();
      _error = null;
      _winnerConfirmed = false;
      _confirmedWinnerPlayerId = null;
    });
  }

  bool _isWinningThresholdReached(int total1, int total2) {
    return total1 >= _targetGameScore || total2 >= _targetGameScore;
  }

  bool _isRowEditable(int index) {
    return !_winnerConfirmed && index == _boardEntries.length - 1;
  }

  void _confirmWinner(int playerId) {
    setState(() {
      _winnerConfirmed = true;
      _confirmedWinnerPlayerId = playerId;
      _error = null;
    });
  }

  void _unlockWinner() {
    setState(() {
      _winnerConfirmed = false;
      _confirmedWinnerPlayerId = null;
      _error = null;
    });
  }

  void _onBoardFieldChanged([VoidCallback? mutate]) {
    setState(() {
      mutate?.call();
      _error = null;
      _winnerConfirmed = false;
      _confirmedWinnerPlayerId = null;
    });
  }

  String _resolveWinnerName(SrrMatch match, String computedWinnerLabel) {
    if (_confirmedWinnerPlayerId == match.player1.id) {
      return _playerLabel(match.player1);
    }
    if (_confirmedWinnerPlayerId == match.player2.id) {
      return _playerLabel(match.player2);
    }
    return computedWinnerLabel;
  }

  String _playerLabel(SrrPlayerLite player) {
    final country = (player.country ?? '').trim();
    if (country.isEmpty) return player.displayName;
    final flag = srrCountryFlagEmoji(country);
    if (flag.isEmpty) return player.displayName;
    return '$flag ${player.displayName}';
  }

  String _resolveTournamentTitle(SrrMatch match) {
    final provided = widget.tournamentName?.trim() ?? '';
    if (provided.isNotEmpty) {
      return provided;
    }
    if (match.tournamentId != null) {
      return 'Tournament ${match.tournamentId}';
    }
    return 'Tournament';
  }

  List<_BoardRowState> _buildRowStates() {
    var runningTotal1 = 0;
    var runningTotal2 = 0;
    final states = <_BoardRowState>[];
    for (final entry in _boardEntries) {
      final state = entry.evaluate();
      if (state.errorMessage == null) {
        runningTotal1 = (runningTotal1 + state.score1).clamp(
          0,
          _targetGameScore,
        );
        runningTotal2 = (runningTotal2 + state.score2).clamp(
          0,
          _targetGameScore,
        );
      }
      states.add(
        state.copyWith(
          runningTotal1: runningTotal1,
          runningTotal2: runningTotal2,
        ),
      );
    }
    return states;
  }

  Future<void> _submit() async {
    final match = _match;
    if (match == null) return;
    final rowStates = _buildRowStates();
    final total1 = rowStates.isEmpty ? 0 : rowStates.last.runningTotal1;
    final total2 = rowStates.isEmpty ? 0 : rowStates.last.runningTotal2;

    if (_isWinningThresholdReached(total1, total2) && !_winnerConfirmed) {
      setState(() {
        _error =
            'Confirm the winner after reaching 25 points before submitting.';
      });
      return;
    }

    final boards = <Map<String, dynamic>>[];
    try {
      for (final entry in _boardEntries) {
        final payload = entry.toPayload();
        if (payload != null) boards.add(payload);
      }
    } on FormatException catch (error) {
      if (!mounted) return;
      setState(() => _error = error.message);
      return;
    }

    if (boards.isEmpty) {
      setState(() => _error = 'Add at least one board row with score data.');
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await widget.dashboardRepository.confirmMatchScore(
        matchId: match.id,
        carrom: {'boards': boards},
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Board scores submitted.')));
      Navigator.of(context).pop();
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _error = error.message);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final match = _match;
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (match == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Board Score Entry')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              _error ?? 'Match information could not be loaded.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    final rowStates = _buildRowStates();
    final total1 = rowStates.isEmpty ? 0 : rowStates.last.runningTotal1;
    final total2 = rowStates.isEmpty ? 0 : rowStates.last.runningTotal2;
    final winnerLabel = total1 == total2
        ? 'Tie'
        : (total1 > total2
              ? _playerLabel(match.player1)
              : _playerLabel(match.player2));
    final resolvedWinnerLabel = _resolveWinnerName(match, winnerLabel);
    final thresholdReached = _isWinningThresholdReached(total1, total2);
    final tournamentName = _resolveTournamentTitle(match);
    final matchLabel =
        'Match ${match.id} • Round ${match.roundNumber} • Table ${match.tableNumber}';

    return Scaffold(
      appBar: AppBar(title: const Text('Board Score Entry')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: Column(
              children: [
                Text(
                  tournamentName,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  matchLabel,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${_playerLabel(match.player1)} vs ${_playerLabel(match.player2)}',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ],
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: Text(
                _error!,
                textAlign: TextAlign.center,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          if (thresholdReached)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: _buildWinnerConfirmationCard(
                match: match,
                total1: total1,
                total2: total2,
              ),
            ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(12),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: _buildScoreSheet(
                  match: match,
                  rowStates: rowStates,
                  total1: total1,
                  total2: total2,
                  winnerLabel: resolvedWinnerLabel,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: SrrSplitActionButton(
              label: _submitting ? 'Submitting...' : 'Submit Score Sheet',
              variant: SrrSplitActionButtonVariant.filled,
              leadingIcon: Icons.save_outlined,
              onPressed: _submitting ? null : _submit,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScoreSheet({
    required SrrMatch match,
    required List<_BoardRowState> rowStates,
    required int total1,
    required int total2,
    required String winnerLabel,
  }) {
    final theme = Theme.of(context);
    final headerColor = theme.colorScheme.surfaceContainerHighest;
    final darkHeaderColor = theme.colorScheme.inverseSurface.withValues(
      alpha: 0.78,
    );
    final boardColumnColor = theme.colorScheme.inverseSurface.withValues(
      alpha: 0.62,
    );
    final tableWidth =
        (_actionColumnWidth * 2) +
        (_queenColumnWidth * 2) +
        (_coinsColumnWidth * 2) +
        (_boardScoreColumnWidth * 2) +
        (_runningTotalColumnWidth * 2) +
        _boardNumberColumnWidth;

    return SizedBox(
      width: tableWidth,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildTableRow(
            cells: [
              _tableCell(
                width: tableWidth,
                height: _headerRowHeight,
                color: darkHeaderColor,
                child: Text(
                  '${_playerLabel(match.player1)} vs ${_playerLabel(match.player2)}',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.onInverseSurface,
                    fontSize: 18,
                  ),
                ),
              ),
            ],
          ),
          _buildTableRow(
            cells: [
              _tableCell(
                width: tableWidth / 2,
                color: headerColor,
                child: Text('Round ${match.roundNumber}'),
              ),
              _tableCell(
                width: tableWidth / 2,
                color: headerColor,
                child: Text('Table ${match.tableNumber}'),
              ),
            ],
          ),
          _buildTableRow(
            cells: [
              _tableCell(
                width:
                    _actionColumnWidth +
                    _queenColumnWidth +
                    _coinsColumnWidth +
                    _boardScoreColumnWidth +
                    _runningTotalColumnWidth,
                color: darkHeaderColor,
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Text(
                    _playerLabel(match.player1),
                    style: TextStyle(
                      color: theme.colorScheme.onInverseSurface,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              _tableCell(
                width: _boardNumberColumnWidth,
                color: boardColumnColor,
                child: const SizedBox.shrink(),
              ),
              _tableCell(
                width:
                    _queenColumnWidth +
                    _coinsColumnWidth +
                    _boardScoreColumnWidth +
                    _runningTotalColumnWidth +
                    _actionColumnWidth,
                color: darkHeaderColor,
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Text(
                    _playerLabel(match.player2),
                    style: TextStyle(
                      color: theme.colorScheme.onInverseSurface,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
          _buildTableRow(
            cells: [
              _tableCell(
                width: _actionColumnWidth,
                color: darkHeaderColor,
                child: const SizedBox.shrink(),
              ),
              _tableCell(
                width: _queenColumnWidth,
                color: darkHeaderColor,
                child: _headerText(theme, 'Queen'),
              ),
              _tableCell(
                width: _coinsColumnWidth,
                color: darkHeaderColor,
                child: _headerText(theme, 'Coins'),
              ),
              _tableCell(
                width: _boardScoreColumnWidth,
                color: darkHeaderColor,
                child: _headerText(theme, 'Board Score'),
              ),
              _tableCell(
                width: _runningTotalColumnWidth,
                color: darkHeaderColor,
                child: _headerText(theme, 'Running Total'),
              ),
              _tableCell(
                width: _boardNumberColumnWidth,
                color: boardColumnColor,
                child: _headerText(theme, 'Board #'),
              ),
              _tableCell(
                width: _queenColumnWidth,
                color: darkHeaderColor,
                child: _headerText(theme, 'Queen'),
              ),
              _tableCell(
                width: _coinsColumnWidth,
                color: darkHeaderColor,
                child: _headerText(theme, 'Coins'),
              ),
              _tableCell(
                width: _boardScoreColumnWidth,
                color: darkHeaderColor,
                child: _headerText(theme, 'Board Score'),
              ),
              _tableCell(
                width: _runningTotalColumnWidth,
                color: darkHeaderColor,
                child: _headerText(theme, 'Running Total'),
              ),
              _tableCell(
                width: _actionColumnWidth,
                color: darkHeaderColor,
                child: const SizedBox.shrink(),
              ),
            ],
          ),
          for (int index = 0; index < _boardEntries.length; index++)
            _buildBoardDataRow(
              index: index,
              entry: _boardEntries[index],
              state: rowStates[index],
              boardColumnColor: boardColumnColor,
              thresholdReached: _isWinningThresholdReached(total1, total2),
            ),
          _buildTableRow(
            cells: [
              _tableCell(
                width:
                    _actionColumnWidth + _queenColumnWidth + _coinsColumnWidth,
                color: darkHeaderColor,
                child: _headerText(theme, 'Game Total'),
              ),
              _tableCell(
                width: _boardScoreColumnWidth + _runningTotalColumnWidth,
                child: Text(
                  '$total1',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              _tableCell(
                width: _boardNumberColumnWidth,
                color: boardColumnColor,
                child: const SizedBox.shrink(),
              ),
              _tableCell(
                width: _queenColumnWidth + _coinsColumnWidth,
                color: darkHeaderColor,
                child: _headerText(theme, 'Game Total'),
              ),
              _tableCell(
                width:
                    _boardScoreColumnWidth +
                    _runningTotalColumnWidth +
                    _actionColumnWidth,
                child: Text(
                  '$total2',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          _buildTableRow(
            cells: [
              _tableCell(
                width:
                    _actionColumnWidth + _queenColumnWidth + _coinsColumnWidth,
                color: darkHeaderColor,
                child: _headerText(theme, 'Winner'),
              ),
              _tableCell(
                width:
                    tableWidth -
                    (_actionColumnWidth +
                        _queenColumnWidth +
                        _coinsColumnWidth),
                color: theme.colorScheme.tertiaryContainer.withValues(
                  alpha: 0.72,
                ),
                child: Text(
                  winnerLabel,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBoardDataRow({
    required int index,
    required _BoardEntry entry,
    required _BoardRowState state,
    required Color boardColumnColor,
    required bool thresholdReached,
  }) {
    final theme = Theme.of(context);
    final hasError = state.errorMessage != null;
    final canEditRow = _isRowEditable(index) && !_submitting;
    final leftColor = hasError
        ? theme.colorScheme.errorContainer.withValues(alpha: 0.55)
        : state.score1 > 0
        ? theme.colorScheme.tertiaryContainer.withValues(alpha: 0.55)
        : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.42);
    final rightColor = hasError
        ? theme.colorScheme.errorContainer.withValues(alpha: 0.55)
        : state.score2 > 0
        ? theme.colorScheme.tertiaryContainer.withValues(alpha: 0.55)
        : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.42);

    return _buildTableRow(
      cells: [
        _tableCell(
          width: _actionColumnWidth,
          color: leftColor,
          child: _buildAddAction(
            index: index,
            canEditRow: canEditRow,
            state: state,
            thresholdReached: thresholdReached,
          ),
        ),
        _tableCell(
          width: _queenColumnWidth,
          color: leftColor,
          child: Checkbox(
            value: entry.player1Queen,
            onChanged:
                !canEditRow || (entry.player2Queen && !entry.player1Queen)
                ? null
                : (value) {
                    if (value == null) return;
                    _onBoardFieldChanged(() {
                      entry.player1Queen = value;
                      if (value) {
                        entry.player2Queen = false;
                      }
                    });
                  },
            visualDensity: VisualDensity.compact,
          ),
        ),
        _tableCell(
          width: _coinsColumnWidth,
          color: leftColor,
          child: _coinsField(entry.player1CoinsController, enabled: canEditRow),
        ),
        _tableCell(
          width: _boardScoreColumnWidth,
          color: leftColor,
          child: Text('${state.score1}'),
        ),
        _tableCell(
          width: _runningTotalColumnWidth,
          color: leftColor,
          child: Text('${state.runningTotal1}'),
        ),
        _tableCell(
          width: _boardNumberColumnWidth,
          color: boardColumnColor,
          child: Text(
            '${entry.boardNumber}',
            style: TextStyle(
              color: theme.colorScheme.onInverseSurface,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        _tableCell(
          width: _queenColumnWidth,
          color: rightColor,
          child: Checkbox(
            value: entry.player2Queen,
            onChanged:
                !canEditRow || (entry.player1Queen && !entry.player2Queen)
                ? null
                : (value) {
                    if (value == null) return;
                    _onBoardFieldChanged(() {
                      entry.player2Queen = value;
                      if (value) {
                        entry.player1Queen = false;
                      }
                    });
                  },
            visualDensity: VisualDensity.compact,
          ),
        ),
        _tableCell(
          width: _coinsColumnWidth,
          color: rightColor,
          child: _coinsField(entry.player2CoinsController, enabled: canEditRow),
        ),
        _tableCell(
          width: _boardScoreColumnWidth,
          color: rightColor,
          child: Text('${state.score2}'),
        ),
        _tableCell(
          width: _runningTotalColumnWidth,
          color: rightColor,
          child: Text('${state.runningTotal2}'),
        ),
        _tableCell(
          width: _actionColumnWidth,
          color: rightColor,
          child: _buildRemoveAction(index: index, canEditRow: canEditRow),
        ),
      ],
    );
  }

  Widget _buildAddAction({
    required int index,
    required bool canEditRow,
    required _BoardRowState state,
    required bool thresholdReached,
  }) {
    if (!canEditRow) return const SizedBox.shrink();

    if (state.errorMessage != null) {
      return Tooltip(
        message: state.errorMessage!,
        child: const Icon(Icons.error_outline, size: 18),
      );
    }

    final canAddNextRow =
        !thresholdReached && _boardEntries.length < _maxBoards;
    if (!canAddNextRow) {
      if (state.hasInput) {
        return const Icon(Icons.check_circle, size: 18);
      }
      return const SizedBox.shrink();
    }

    final hasEnteredScore = state.hasInput;
    return IconButton(
      padding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
      tooltip: hasEnteredScore
          ? 'Save board and add next board row'
          : 'Add next board row',
      icon: Icon(
        hasEnteredScore ? Icons.check_circle_outline : Icons.add_circle_outline,
        size: 18,
      ),
      onPressed: () => _addBoardAfter(index),
    );
  }

  Widget _buildRemoveAction({required int index, required bool canEditRow}) {
    if (!canEditRow || _boardEntries.length <= _minBoards) {
      return const SizedBox.shrink();
    }
    return IconButton(
      padding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
      tooltip: 'Delete this row',
      icon: const Icon(Icons.remove_circle_outline, size: 18),
      onPressed: () => _removeBoardAt(index),
    );
  }

  Widget _coinsField(
    TextEditingController controller, {
    required bool enabled,
  }) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      textAlign: TextAlign.center,
      enabled: enabled,
      onChanged: (_) => _onBoardFieldChanged(),
      decoration: const InputDecoration(
        isDense: true,
        border: InputBorder.none,
        contentPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 10),
      ),
    );
  }

  Widget _buildTableRow({required List<Widget> cells}) {
    return Row(crossAxisAlignment: CrossAxisAlignment.center, children: cells);
  }

  Widget _tableCell({
    required double width,
    required Widget child,
    Color? color,
    Alignment alignment = Alignment.center,
    double height = _rowHeight,
  }) {
    return Container(
      width: width,
      height: height,
      alignment: alignment,
      decoration: BoxDecoration(
        color: color,
        border: Border.all(color: Colors.black54, width: 0.8),
      ),
      child: child,
    );
  }

  Widget _headerText(ThemeData theme, String text) {
    return Text(
      text,
      textAlign: TextAlign.center,
      style: TextStyle(
        color: theme.colorScheme.onInverseSurface,
        fontWeight: FontWeight.w700,
        fontSize: 13,
      ),
    );
  }

  Widget _buildWinnerConfirmationCard({
    required SrrMatch match,
    required int total1,
    required int total2,
  }) {
    final theme = Theme.of(context);
    final confirmedLabel = _resolveWinnerName(
      match,
      total1 == total2 ? 'Tie' : '',
    );
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.42,
        ),
        border: Border.all(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _winnerConfirmed
                ? 'Winner confirmed: $confirmedLabel'
                : '25 points reached. Confirm match winner.',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _winnerConfirmed
                      ? null
                      : () => _confirmWinner(match.player1.id),
                  icon: const Icon(Icons.emoji_events_outlined, size: 16),
                  label: Text('${_playerLabel(match.player1)} ($total1)'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _winnerConfirmed
                      ? null
                      : () => _confirmWinner(match.player2.id),
                  icon: const Icon(Icons.emoji_events_outlined, size: 16),
                  label: Text('${_playerLabel(match.player2)} ($total2)'),
                ),
              ),
            ],
          ),
          if (_winnerConfirmed)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: _submitting ? null : _unlockWinner,
                icon: const Icon(Icons.edit_outlined, size: 16),
                label: const Text('Edit Winner'),
              ),
            ),
        ],
      ),
    );
  }
}

class _BoardEntry {
  _BoardEntry({
    required this.boardNumber,
    int? player1Coins,
    int? player2Coins,
    this.player1Queen = false,
    this.player2Queen = false,
  }) : player1CoinsController = TextEditingController(
         text: player1Coins == null ? '' : '$player1Coins',
       ),
       player2CoinsController = TextEditingController(
         text: player2Coins == null ? '' : '$player2Coins',
       );

  factory _BoardEntry.fromBoard(SrrCarromBoard board) {
    final player1Queen = board.queenPocketedBy == SrrQueenPocketedBy.striker;
    final player2Queen = board.queenPocketedBy == SrrQueenPocketedBy.nonStriker;
    final player1Coins =
        (board.pointsPlayer1 - (player1Queen ? _queenPoints : 0)).clamp(
          0,
          _maxCoinsPerColor,
        );
    final player2Coins =
        (board.pointsPlayer2 - (player2Queen ? _queenPoints : 0)).clamp(
          0,
          _maxCoinsPerColor,
        );
    return _BoardEntry(
      boardNumber: board.boardNumber,
      player1Coins: player1Coins,
      player2Coins: player2Coins,
      player1Queen: player1Queen,
      player2Queen: player2Queen,
    );
  }

  int boardNumber;
  final TextEditingController player1CoinsController;
  final TextEditingController player2CoinsController;
  bool player1Queen;
  bool player2Queen;

  void dispose() {
    player1CoinsController.dispose();
    player2CoinsController.dispose();
  }

  _BoardRowState evaluate() {
    int? parseCoins(TextEditingController controller) {
      final text = controller.text.trim();
      if (text.isEmpty) return null;
      return int.tryParse(text);
    }

    final player1RawText = player1CoinsController.text.trim();
    final player2RawText = player2CoinsController.text.trim();
    final player1Coins = parseCoins(player1CoinsController);
    final player2Coins = parseCoins(player2CoinsController);
    final hasInput =
        player1RawText.isNotEmpty ||
        player2RawText.isNotEmpty ||
        player1Queen ||
        player2Queen;

    if (player1RawText.isNotEmpty && player1Coins == null) {
      return _BoardRowState(
        hasInput: hasInput,
        score1: 0,
        score2: 0,
        runningTotal1: 0,
        runningTotal2: 0,
        errorMessage: 'Board $boardNumber: Player 1 coins must be numeric.',
      );
    }
    if (player2RawText.isNotEmpty && player2Coins == null) {
      return _BoardRowState(
        hasInput: hasInput,
        score1: 0,
        score2: 0,
        runningTotal1: 0,
        runningTotal2: 0,
        errorMessage: 'Board $boardNumber: Player 2 coins must be numeric.',
      );
    }

    final resolvedPlayer1Coins = player1Coins ?? 0;
    final resolvedPlayer2Coins = player2Coins ?? 0;
    if (resolvedPlayer1Coins < 0 || resolvedPlayer1Coins > _maxCoinsPerColor) {
      return _BoardRowState(
        hasInput: hasInput,
        score1: 0,
        score2: 0,
        runningTotal1: 0,
        runningTotal2: 0,
        errorMessage: 'Board $boardNumber: Player 1 coins must be 0..9.',
      );
    }
    if (resolvedPlayer2Coins < 0 || resolvedPlayer2Coins > _maxCoinsPerColor) {
      return _BoardRowState(
        hasInput: hasInput,
        score1: 0,
        score2: 0,
        runningTotal1: 0,
        runningTotal2: 0,
        errorMessage: 'Board $boardNumber: Player 2 coins must be 0..9.',
      );
    }
    if (player1Queen && player2Queen) {
      return _BoardRowState(
        hasInput: hasInput,
        score1: 0,
        score2: 0,
        runningTotal1: 0,
        runningTotal2: 0,
        errorMessage:
            'Board $boardNumber: Queen cannot be selected for both players.',
      );
    }

    final score1 = resolvedPlayer1Coins + (player1Queen ? _queenPoints : 0);
    final score2 = resolvedPlayer2Coins + (player2Queen ? _queenPoints : 0);
    if (score1 > _maxBoardScore || score2 > _maxBoardScore) {
      return _BoardRowState(
        hasInput: hasInput,
        score1: 0,
        score2: 0,
        runningTotal1: 0,
        runningTotal2: 0,
        errorMessage: 'Board $boardNumber: Board score cannot exceed 13.',
      );
    }

    return _BoardRowState(
      hasInput: hasInput,
      score1: score1,
      score2: score2,
      runningTotal1: 0,
      runningTotal2: 0,
      errorMessage: null,
    );
  }

  Map<String, dynamic>? toPayload() {
    final state = evaluate();
    if (state.errorMessage != null) {
      throw FormatException(state.errorMessage!);
    }
    if (!state.hasInput) return null;

    final payload = <String, dynamic>{
      'board_number': boardNumber,
      'player1_points': state.score1,
      'player2_points': state.score2,
    };
    if (player1Queen) {
      payload['queen_pocketed_by'] = 'striker';
    } else if (player2Queen) {
      payload['queen_pocketed_by'] = 'non_striker';
    }
    return payload;
  }
}

class _BoardRowState {
  const _BoardRowState({
    required this.hasInput,
    required this.score1,
    required this.score2,
    required this.runningTotal1,
    required this.runningTotal2,
    required this.errorMessage,
  });

  final bool hasInput;
  final int score1;
  final int score2;
  final int runningTotal1;
  final int runningTotal2;
  final String? errorMessage;

  _BoardRowState copyWith({int? runningTotal1, int? runningTotal2}) {
    return _BoardRowState(
      hasInput: hasInput,
      score1: score1,
      score2: score2,
      runningTotal1: runningTotal1 ?? this.runningTotal1,
      runningTotal2: runningTotal2 ?? this.runningTotal2,
      errorMessage: errorMessage,
    );
  }
}
