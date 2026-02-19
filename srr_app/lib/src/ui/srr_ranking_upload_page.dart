// ---------------------------------------------------------------------------
// srr_app/lib/src/ui/srr_ranking_upload_page.dart
// ---------------------------------------------------------------------------
// 
// Purpose:
// - Parses, validates, previews, and persists national ranking upload records.
// Architecture:
// - Feature page with ranking selection, validation, and upload workflow handling.
// - Delegates ranking persistence and retrieval to repository and API abstractions.
// Author: Neil Khatu
// Copyright (c) The Khatu Family Trust
// 
import 'package:catu_framework/catu_framework.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../api/srr_api_client.dart';
import '../models/srr_models.dart';
import '../repositories/srr_tournament_repository.dart';
import '../services/ranking_upload_parser.dart';
import '../theme/srr_display_preferences_controller.dart';
import 'srr_generic_upload_card.dart';
import 'srr_page_scaffold.dart';
import 'srr_routes.dart';
import 'srr_split_action_button.dart';
import 'srr_upload_page.dart';

class SrrRankingUploadPage extends StatefulWidget {
  const SrrRankingUploadPage({
    super.key,
    required this.appState,
    required this.apiClient,
    required this.displayPreferencesController,
    this.tournamentRepository,
    this.initialTournamentId,
    this.readOnly = false,
  });

  final AppState appState;
  final SrrApiClient apiClient;
  final SrrDisplayPreferencesController displayPreferencesController;
  final SrrTournamentRepository? tournamentRepository;
  final int? initialTournamentId;
  final bool readOnly;

  @override
  State<SrrRankingUploadPage> createState() => _SrrRankingUploadPageState();
}

class _SrrRankingUploadPageState extends State<SrrRankingUploadPage> {
  bool _loadingContext = true;
  bool _uploading = false;
  bool _applying = false;
  bool _selectingRanking = false;
  bool _deletingRanking = false;

  String? _fileName;
  String? _loadError;
  String? _uploadError;
  String? _applyError;
  String? _selectionError;
  String? _dbRowsError;
  DateTime? _lastApplyAt;
  bool _loadingDbRows = false;

  List<SrrTournamentRecord> _tournaments = const [];
  int? _selectedTournamentId;

  List<SrrNationalRankingOption> _rankingOptions = const [];
  String? _selectedRankingOptionKey;
  List<SrrNationalRankingRecord> _dbRankingRows = const [];
  int _dbRowsRequestToken = 0;

  List<RankingUploadRow> _uploadedRows = const [];
  int? _editingInvalidRowIndex;

  final TextEditingController _editRankController = TextEditingController();

  static String _rankingOptionKey({
    required int rankingYear,
    required String rankingDescription,
  }) {
    return '$rankingYear::${rankingDescription.trim().toLowerCase()}';
  }

  static String _rankingOptionKeyOf(SrrNationalRankingOption option) {
    return _rankingOptionKey(
      rankingYear: option.rankingYear,
      rankingDescription: option.rankingDescription,
    );
  }

  List<RankingUploadRow> get _validRows =>
      _uploadedRows.where((entry) => entry.isValid).toList(growable: false);

  int get _invalidRowsCount =>
      _uploadedRows.where((entry) => !entry.isValid).length;

  RankingUploadRow? get _editingInvalidRow {
    final rowIndex = _editingInvalidRowIndex;
    if (rowIndex == null || rowIndex < 0 || rowIndex >= _uploadedRows.length) {
      return null;
    }
    final row = _uploadedRows[rowIndex];
    if (row.isValid) return null;
    return row;
  }

  SrrTournamentRecord? get _selectedTournament {
    final tournamentId = _selectedTournamentId;
    if (tournamentId == null) return null;
    for (final tournament in _tournaments) {
      if (tournament.id == tournamentId) {
        return tournament;
      }
    }
    return null;
  }

  SrrNationalRankingOption? get _selectedRankingOption {
    final selectionKey = _selectedRankingOptionKey;
    if (selectionKey == null) return null;
    for (final option in _rankingOptions) {
      if (_rankingOptionKeyOf(option) == selectionKey) {
        return option;
      }
    }
    return null;
  }

  SrrNationalRankingOption? _findTournamentSelectedRankingOption(
    SrrTournamentRecord? tournament,
    List<SrrNationalRankingOption> rankingOptions,
  ) {
    if (tournament == null || rankingOptions.isEmpty) return null;
    final selectedYear = tournament.selectedRankingYear;
    if (selectedYear == null) return null;
    final selectedDescription = tournament.selectedRankingDescription?.trim();
    if (selectedDescription != null && selectedDescription.isNotEmpty) {
      for (final option in rankingOptions) {
        if (option.rankingYear != selectedYear) continue;
        if (option.rankingDescription.trim().toLowerCase() ==
            selectedDescription.toLowerCase()) {
          return option;
        }
      }
    }
    for (final option in rankingOptions) {
      if (option.rankingYear == selectedYear) return option;
    }
    return null;
  }

  Future<void> _loadDbRowsForOption(
    SrrNationalRankingOption? option, {
    bool clearUploadedPreview = false,
  }) async {
    final repository = widget.tournamentRepository;
    final requestToken = ++_dbRowsRequestToken;
    if (clearUploadedPreview) {
      setState(() {
        _uploadedRows = const [];
        _editingInvalidRowIndex = null;
        _fileName = null;
      });
    }
    if (repository == null || option == null) {
      if (!mounted || requestToken != _dbRowsRequestToken) return;
      setState(() {
        _loadingDbRows = false;
        _dbRowsError = null;
        _dbRankingRows = const [];
      });
      return;
    }

    setState(() {
      _loadingDbRows = true;
      _dbRowsError = null;
    });
    try {
      final rows = await repository.fetchNationalRankingRows(
        rankingYear: option.rankingYear,
        rankingDescription: option.rankingDescription,
      );
      if (!mounted || requestToken != _dbRowsRequestToken) return;
      setState(() {
        _loadingDbRows = false;
        _dbRowsError = null;
        _dbRankingRows = rows;
      });
    } catch (error) {
      if (!mounted || requestToken != _dbRowsRequestToken) return;
      setState(() {
        _loadingDbRows = false;
        _dbRowsError = error.toString();
        _dbRankingRows = const [];
      });
    }
  }

  List<SrrUploadPreviewRow> get _rankingPreviewRows {
    final locale = Localizations.maybeLocaleOf(context);
    if (_uploadedRows.isNotEmpty) {
      return _uploadedRows
          .asMap()
          .entries
          .map((entry) {
            final row = entry.value;
            return SrrUploadPreviewRow(
              isValid: row.isValid,
              editableRowIndex: entry.key,
              values: [
                row.rank,
                row.playerName,
                row.state,
                row.country,
                row.emailId,
                row.rankingPoints,
                row.rankingYear,
                widget.displayPreferencesController.formatIsoDateTime(
                  row.lastUpdated,
                  fallbackLocale: locale,
                ),
              ],
              errors: row.validationErrors,
            );
          })
          .toList(growable: false);
    }
    return _dbRankingRows
        .map(
          (row) => SrrUploadPreviewRow(
            isValid: true,
            values: [
              row.rank > 0 ? '${row.rank}' : '',
              row.playerName,
              row.state,
              row.country,
              row.emailId,
              row.rankingPoints == null
                  ? ''
                  : row.rankingPoints!.toStringAsFixed(2),
              '${row.rankingYear}',
              widget.displayPreferencesController.formatIsoDateTime(
                row.lastUpdated,
                fallbackLocale: locale,
              ),
            ],
          ),
        )
        .toList(growable: false);
  }

  @override
  void initState() {
    super.initState();
    _loadContext(preferredTournamentId: widget.initialTournamentId);
  }

  @override
  void dispose() {
    _editRankController.dispose();
    super.dispose();
  }

  String? _resolveRankingSelectionKey({
    required List<SrrNationalRankingOption> rankingOptions,
    required SrrTournamentRecord? tournament,
    String? preferredKey,
  }) {
    if (rankingOptions.isEmpty) {
      return null;
    }

    if (preferredKey != null) {
      for (final option in rankingOptions) {
        if (_rankingOptionKeyOf(option) == preferredKey) {
          return preferredKey;
        }
      }
    }

    final selectedRankingYear = tournament?.selectedRankingYear;
    final selectedRankingDescription = tournament?.selectedRankingDescription
        ?.trim();

    if (selectedRankingYear != null &&
        selectedRankingDescription != null &&
        selectedRankingDescription.isNotEmpty) {
      final desiredKey = _rankingOptionKey(
        rankingYear: selectedRankingYear,
        rankingDescription: selectedRankingDescription,
      );
      for (final option in rankingOptions) {
        if (_rankingOptionKeyOf(option) == desiredKey) {
          return desiredKey;
        }
      }
    }

    if (selectedRankingYear != null) {
      for (final option in rankingOptions) {
        if (option.rankingYear == selectedRankingYear) {
          return _rankingOptionKeyOf(option);
        }
      }
    }

    return _rankingOptionKeyOf(rankingOptions.first);
  }

  Future<void> _loadContext({
    int? preferredTournamentId,
    String? preferredRankingOptionKey,
    bool showLoading = true,
  }) async {
    final repository = widget.tournamentRepository;
    if (repository == null) {
      setState(() {
        _loadingContext = false;
        _loadError = 'Ranking repository is unavailable. Reload and retry.';
      });
      return;
    }

    if (showLoading) {
      setState(() {
        _loadingContext = true;
        _loadError = null;
      });
    }

    try {
      final currentUser = widget.apiClient.currentUserSnapshot;
      final canManageTournamentContext =
          (currentUser?.isAdmin ?? false) && !widget.readOnly;
      final rankingOptions = await repository.fetchNationalRankingOptions();
      final tournaments = canManageTournamentContext
          ? await repository.fetchTournaments()
          : const <SrrTournamentRecord>[];

      int? selectedTournamentId = canManageTournamentContext
          ? preferredTournamentId ?? _selectedTournamentId
          : null;
      if (canManageTournamentContext) {
        if (selectedTournamentId != null &&
            tournaments.every((entry) => entry.id != selectedTournamentId)) {
          selectedTournamentId = null;
        }
        if (selectedTournamentId == null &&
            widget.initialTournamentId != null &&
            tournaments.isNotEmpty) {
          selectedTournamentId = tournaments.first.id;
        }
      }

      SrrTournamentRecord? selectedTournament;
      if (selectedTournamentId != null) {
        for (final tournament in tournaments) {
          if (tournament.id == selectedTournamentId) {
            selectedTournament = tournament;
            break;
          }
        }
      }

      final selectedRankingKey = _resolveRankingSelectionKey(
        rankingOptions: rankingOptions,
        tournament: selectedTournament,
        preferredKey: preferredRankingOptionKey ?? _selectedRankingOptionKey,
      );
      SrrNationalRankingOption? selectedRankingOption;
      if (selectedRankingKey != null) {
        for (final option in rankingOptions) {
          if (_rankingOptionKeyOf(option) == selectedRankingKey) {
            selectedRankingOption = option;
            break;
          }
        }
      }
      final tournamentSelectedOption = _findTournamentSelectedRankingOption(
        selectedTournament,
        rankingOptions,
      );
      final optionForDisplay =
          tournamentSelectedOption ?? selectedRankingOption;

      if (!mounted) return;
      setState(() {
        _tournaments = tournaments;
        _rankingOptions = rankingOptions;
        _selectedTournamentId = selectedTournamentId;
        _selectedRankingOptionKey = selectedRankingKey;
        _loadingContext = false;
        _loadError = null;
      });

      await _loadDbRowsForOption(optionForDisplay);
      if (!mounted) return;
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadingContext = false;
        _loadError = error.toString();
      });
    }
  }

  void _onTournamentSelected(int? tournamentId) {
    SrrTournamentRecord? selectedTournament;
    if (tournamentId != null) {
      for (final tournament in _tournaments) {
        if (tournament.id == tournamentId) {
          selectedTournament = tournament;
          break;
        }
      }
    }

    final selectedKey = _resolveRankingSelectionKey(
      rankingOptions: _rankingOptions,
      tournament: selectedTournament,
      preferredKey: null,
    );

    setState(() {
      _selectedTournamentId = tournamentId;
      _selectedRankingOptionKey = selectedKey;
      _selectionError = null;
      _applyError = null;
    });

    SrrNationalRankingOption? selectedOption;
    if (selectedKey != null) {
      for (final option in _rankingOptions) {
        if (_rankingOptionKeyOf(option) == selectedKey) {
          selectedOption = option;
          break;
        }
      }
    }
    final tournamentSelectedOption = _findTournamentSelectedRankingOption(
      selectedTournament,
      _rankingOptions,
    );
    final optionForDisplay = tournamentSelectedOption ?? selectedOption;
    _loadDbRowsForOption(optionForDisplay, clearUploadedPreview: true);
  }

  void _onRankingOptionSelected(String? key) {
    setState(() {
      _selectedRankingOptionKey = key;
      _selectionError = null;
    });
    SrrNationalRankingOption? selectedOption;
    if (key != null) {
      for (final option in _rankingOptions) {
        if (_rankingOptionKeyOf(option) == key) {
          selectedOption = option;
          break;
        }
      }
    }
    _loadDbRowsForOption(selectedOption, clearUploadedPreview: true);
  }

  Future<void> _selectRankingForTournament() async {
    final repository = widget.tournamentRepository;
    final tournamentId = _selectedTournamentId;
    final selectedRanking = _selectedRankingOption;

    if (repository == null) {
      setState(() {
        _selectionError =
            'Ranking repository is unavailable. Reload and retry.';
      });
      return;
    }

    if (tournamentId == null) {
      setState(() {
        _selectionError = 'Select a tournament first.';
      });
      return;
    }

    if (selectedRanking == null) {
      setState(() {
        _selectionError = 'Select a ranking description first.';
      });
      return;
    }

    setState(() {
      _selectingRanking = true;
      _selectionError = null;
      _applyError = null;
    });

    try {
      final updated = await repository.selectTournamentRanking(
        tournamentId: tournamentId,
        rankingYear: selectedRanking.rankingYear,
        rankingDescription: selectedRanking.rankingDescription,
      );
      if (!mounted) return;
      final selectedKey = _rankingOptionKeyOf(selectedRanking);
      setState(() {
        _tournaments = _tournaments
            .map((entry) => entry.id == updated.id ? updated : entry)
            .toList(growable: false);
        _selectedTournamentId = updated.id;
        _selectedRankingOptionKey = selectedKey;
        _lastApplyAt = DateTime.now();
      });
      await _loadDbRowsForOption(selectedRanking, clearUploadedPreview: true);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Selected ${selectedRanking.rankingYear} - ${selectedRanking.rankingDescription} for ${updated.name}.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _selectionError = error.toString());
    } finally {
      if (mounted) {
        setState(() => _selectingRanking = false);
      }
    }
  }

  Future<bool?> _confirmDeleteRanking(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete Ranking List'),
          content: const Text(
            'This removes the selected ranking rows from the database and clears tournament selections using it. Continue?',
            textAlign: TextAlign.center,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            SizedBox(
              width: 170,
              child: SrrSplitActionButton(
                label: 'Delete',
                leadingIcon: Icons.delete_forever,
                variant: SrrSplitActionButtonVariant.outlined,
                onPressed: () => Navigator.of(dialogContext).pop(true),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteSelectedRanking() async {
    final repository = widget.tournamentRepository;
    final selected = _selectedRankingOption;
    if (repository == null || selected == null || _deletingRanking) return;

    final confirmed = await _confirmDeleteRanking(context);
    if (confirmed != true || !mounted) return;

    setState(() {
      _deletingRanking = true;
      _selectionError = null;
      _applyError = null;
      _uploadError = null;
    });
    try {
      final result = await repository.deleteNationalRankingList(
        rankingYear: selected.rankingYear,
        rankingDescription: selected.rankingDescription,
      );
      if (!mounted) return;
      await _loadContext(
        preferredTournamentId: _selectedTournamentId,
        showLoading: false,
      );
      if (!mounted) return;
      setState(() {
        _lastApplyAt = DateTime.now();
        _uploadedRows = const [];
        _editingInvalidRowIndex = null;
        _fileName = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Deleted ${result.deletedRows} ranking row(s) for ${result.rankingYear} - ${result.rankingDescription}.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _selectionError = error.toString());
    } finally {
      if (mounted) {
        setState(() => _deletingRanking = false);
      }
    }
  }

  Future<void> _pickUploadFile() async {
    setState(() {
      _uploading = true;
      _uploadError = null;
      _applyError = null;
      _editingInvalidRowIndex = null;
    });

    try {
      final picked = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['csv', 'xlsx', 'xls'],
        withData: true,
      );
      if (picked == null || picked.files.isEmpty) return;

      final file = picked.files.first;
      final fileBytes = file.bytes;
      if (fileBytes == null) {
        throw const FormatException(
          'File content could not be read. Please retry with a local file.',
        );
      }

      final rows = RankingUploadParser.parse(
        fileName: file.name,
        bytes: fileBytes,
      );
      if (!mounted) return;
      setState(() {
        _fileName = file.name;
        _uploadedRows = rows;
        _editingInvalidRowIndex = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _uploadError = error.toString());
    } finally {
      if (mounted) {
        setState(() => _uploading = false);
      }
    }
  }

  void _openInlineEditorForInvalidRow(int rowIndex) {
    if (rowIndex < 0 || rowIndex >= _uploadedRows.length) return;
    final row = _uploadedRows[rowIndex];
    if (row.isValid) return;
    setState(() {
      _editingInvalidRowIndex = rowIndex;
      _editRankController.text = row.rank;
      _uploadError = null;
      _applyError = null;
    });
  }

  void _cancelInlineEdit() {
    setState(() {
      _editingInvalidRowIndex = null;
    });
  }

  void _applyInlineEdit() {
    final rowIndex = _editingInvalidRowIndex;
    if (rowIndex == null || rowIndex < 0 || rowIndex >= _uploadedRows.length) {
      return;
    }
    final currentRow = _uploadedRows[rowIndex];
    final nextRows = List<RankingUploadRow>.from(_uploadedRows);
    nextRows[rowIndex] = RankingUploadParser.buildRow(
      rank: _editRankController.text,
      playerName: currentRow.playerName,
      state: currentRow.state,
      country: currentRow.country,
      emailId: currentRow.emailId,
      rankingPoints: currentRow.rankingPoints,
      rankingYear: currentRow.rankingYear,
      lastUpdated: currentRow.lastUpdated,
    );
    final revalidatedRows = RankingUploadParser.revalidateRows(nextRows);
    final editedRow = revalidatedRows[rowIndex];
    setState(() {
      _uploadedRows = revalidatedRows;
      _editingInvalidRowIndex = editedRow.isValid ? null : rowIndex;
    });

    if (editedRow.isValid) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Row ${rowIndex + 1} updated successfully.')),
      );
    }
  }

  Future<String?> _promptRankingDescriptionForUpload() async {
    final selectedOption = _selectedRankingOption;
    final tournamentDescription = _selectedTournament
        ?.selectedRankingDescription
        ?.trim();
    final initialValue =
        selectedOption?.rankingDescription ??
        ((tournamentDescription == null || tournamentDescription.isEmpty)
            ? 'Current Year National Ranking'
            : tournamentDescription);
    final controller = TextEditingController(text: initialValue);
    final value = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Ranking Description'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Description',
              hintText: 'Example: 2026 National Final',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            SizedBox(
              width: 160,
              child: SrrSplitActionButton(
                label: 'Continue',
                leadingIcon: Icons.check,
                variant: SrrSplitActionButtonVariant.filled,
                onPressed: () =>
                    Navigator.of(dialogContext).pop(controller.text.trim()),
              ),
            ),
          ],
        );
      },
    );
    controller.dispose();
    if (value == null || value.trim().isEmpty) return null;
    return value.trim();
  }

  Future<void> _applyUpload() async {
    if (_uploadedRows.isEmpty) return;
    final validRows = _validRows;
    if (validRows.isEmpty) {
      setState(() {
        _applyError = 'No valid ranking rows to apply. Red rows are skipped.';
      });
      return;
    }

    final rankingDescription = await _promptRankingDescriptionForUpload();
    if (rankingDescription == null || rankingDescription.isEmpty) {
      setState(() {
        _applyError = 'Ranking description is required.';
      });
      return;
    }

    final repository = widget.tournamentRepository;
    if (repository == null) {
      setState(() {
        _applyError = 'Ranking repository is unavailable. Reload and retry.';
      });
      return;
    }

    final now = DateTime.now().toUtc();
    final payload = <SrrNationalRankingInput>[];
    var nonNumericRankRows = 0;
    for (final row in validRows) {
      final rank = int.tryParse(row.rank.trim());
      if (rank == null || rank < 1) {
        nonNumericRankRows += 1;
        continue;
      }
      final parsedYear = int.tryParse(row.rankingYear.trim());
      final rankingYear = parsedYear == null || parsedYear < 1900
          ? now.year
          : parsedYear;
      final points = double.tryParse(row.rankingPoints.trim());
      payload.add(
        SrrNationalRankingInput(
          rank: rank,
          playerName: row.playerName.trim(),
          rankingDescription: rankingDescription,
          state: row.state.trim().isEmpty ? null : row.state.trim(),
          country: row.country.trim().isEmpty ? null : row.country.trim(),
          emailId: row.emailId.trim().isEmpty
              ? null
              : row.emailId.trim().toLowerCase(),
          rankingPoints: points,
          rankingYear: rankingYear,
          lastUpdated: row.lastUpdated.trim().isEmpty
              ? null
              : row.lastUpdated.trim(),
        ),
      );
    }
    if (payload.isEmpty) {
      setState(() {
        _applyError =
            'No valid ranking rows to apply. Rank must be a positive number.';
      });
      return;
    }

    setState(() {
      _applying = true;
      _applyError = null;
    });
    try {
      final result = await repository.uploadNationalRankings(
        rows: payload,
        rankingDescription: rankingDescription,
      );
      if (!mounted) return;
      final uploadedKey = _rankingOptionKey(
        rankingYear: payload.first.rankingYear,
        rankingDescription: rankingDescription,
      );
      await _loadContext(
        preferredTournamentId: _selectedTournamentId,
        preferredRankingOptionKey: uploadedKey,
        showLoading: false,
      );
      if (!mounted) return;
      setState(() {
        _lastApplyAt = DateTime.now();
        _uploadedRows = const [];
        _editingInvalidRowIndex = null;
        _fileName = null;
      });
      final skipped = _uploadedRows.length - validRows.length;
      final numericSkipped = nonNumericRankRows;
      final totalSkipped = skipped + numericSkipped;
      final yearsLabel = result.years.isEmpty
          ? ''
          : ' Years: ${result.years.join(', ')}.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Uploaded ${result.uploadedRows} ranking row(s) for "$rankingDescription".'
            '${totalSkipped > 0 ? ' Skipped $totalSkipped row(s).' : ''}'
            '$yearsLabel',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _applyError = error.toString());
    } finally {
      if (mounted) {
        setState(() => _applying = false);
      }
    }
  }

  Widget? _buildInlineEditor(BuildContext context) {
    final rowIndex = _editingInvalidRowIndex;
    final row = _editingInvalidRow;
    if (rowIndex == null || row == null) return null;

    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            'Edit row ${rowIndex + 1}',
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium,
          ),
          if (row.validationErrors.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              row.validationErrors.join(' '),
              textAlign: TextAlign.center,
              style: TextStyle(color: theme.colorScheme.error),
            ),
          ],
          const SizedBox(height: 10),
          SizedBox(
            width: 260,
            child: TextField(
              controller: _editRankController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Rank',
                hintText: 'Enter unique rank',
                isDense: true,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 10,
            runSpacing: 10,
            children: [
              SizedBox(
                width: 220,
                child: SrrSplitActionButton(
                  label: 'Save Row',
                  leadingIcon: Icons.save,
                  variant: SrrSplitActionButtonVariant.filled,
                  onPressed: _applyInlineEdit,
                ),
              ),
              SizedBox(
                width: 220,
                child: SrrSplitActionButton(
                  label: 'Cancel',
                  leadingIcon: Icons.close,
                  variant: SrrSplitActionButtonVariant.outlined,
                  onPressed: _cancelInlineEdit,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _currentTournamentRankingLabel() {
    final tournament = _selectedTournament;
    if (tournament == null) {
      return 'Current tournament selection: not set.';
    }
    if (tournament.selectedRankingYear == null) {
      final selected = _selectedRankingOption;
      if (selected != null) {
        return 'Current tournament selection: not set in DB. Selected in form: ${selected.label}. Tap Select Ranking.';
      }
      return 'Current tournament selection: not set. Select ranking and tap Select Ranking.';
    }
    final description = tournament.selectedRankingDescription?.trim();
    if (description == null || description.isEmpty) {
      return 'Current tournament selection: ${tournament.selectedRankingYear}.';
    }
    return 'Current tournament selection: ${tournament.selectedRankingYear} - $description.';
  }

  String _currentTournamentLabel() {
    final tournament = _selectedTournament;
    if (tournament == null) return 'Tournament: Not selected';
    return 'Tournament: ${tournament.name}';
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.apiClient.currentUserSnapshot;
    final isAdmin = user?.isAdmin ?? false;
    final canManageRanking = isAdmin && !widget.readOnly;
    final canViewRanking = canManageRanking || widget.readOnly;
    final showTournamentSelectionControls =
        canManageRanking &&
        (widget.initialTournamentId != null || _selectedTournamentId != null);
    final showTournamentContextSummary =
        canManageRanking &&
        showTournamentSelectionControls &&
        _selectedTournament != null;
    final validRowsCount = _validRows.length;
    final invalidRowsCount = _invalidRowsCount;
    final dbRowsCount = _dbRankingRows.length;
    final emptyPreviewMessage = _loadingDbRows
        ? 'Loading ranking rows from database...'
        : (_selectedTournament?.selectedRankingYear != null ||
                  _selectedRankingOption != null
              ? 'No ranking rows found for selected ranking.'
              : 'No upload parsed yet.');
    final rankingStats = _fileName == null
        ? const <SrrUploadStatItem>[]
        : <SrrUploadStatItem>[
            SrrUploadStatItem(
              label: 'Rows in file',
              value: '${_uploadedRows.length}',
            ),
            SrrUploadStatItem(
              label: 'Error records',
              value: '$invalidRowsCount',
            ),
            SrrUploadStatItem(label: 'Saved to db', value: '$validRowsCount'),
          ];
    final lastApplyLabel = _lastApplyAt == null
        ? 'No ranking upload action yet'
        : widget.displayPreferencesController.formatDateTime(
            _lastApplyAt!,
            fallbackLocale: Localizations.localeOf(context),
          );

    final rankingSelectionItems = _rankingOptions
        .map(
          (entry) => DropdownMenuItem<String>(
            value: _rankingOptionKeyOf(entry),
            child: Text(entry.label),
          ),
        )
        .toList(growable: false);

    return SrrPageScaffold(
      title: canManageRanking
          ? 'Ranking List Upload'
          : 'Current National Ranking',
      appState: widget.appState,
      actions: [
        if (canManageRanking) ...[
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
              Navigator.pushReplacementNamed(
                context,
                SrrRoutes.genericUpload,
                arguments: const SrrUploadPageArguments(
                  context: SrrUploadContext.players,
                ),
              );
            },
            icon: const Icon(Icons.upload_file),
          ),
          IconButton(
            tooltip: 'Round Matchup',
            onPressed: () {
              Navigator.pushNamed(context, SrrRoutes.roundMatchup);
            },
            icon: const Icon(Icons.grid_view),
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
                    'Last ranking upload action: $lastApplyLabel',
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
          if (isAdmin &&
              !_loadingContext &&
              _loadError == null &&
              showTournamentContextSummary) ...[
            const SizedBox(height: 10),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      _currentTournamentLabel(),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _currentTournamentRankingLabel(),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          if (!canViewRanking)
            const _AdminAccessRequiredCard(featureName: 'Ranking List Upload')
          else if (_loadingContext)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              ),
            )
          else if (_loadError != null)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      'Failed to load ranking context: $_loadError',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: 220,
                      child: SrrSplitActionButton(
                        label: 'Retry',
                        leadingIcon: Icons.refresh,
                        variant: SrrSplitActionButtonVariant.filled,
                        onPressed: _loadContext,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            SrrGenericUploadCard(
              title: canManageRanking
                  ? 'Current Year Ranking Upload'
                  : 'Current National Ranking',
              subtitle: canManageRanking
                  ? 'Select an available ranking, upload CSV/XLSX, then save to database. A ranking description is prompted on save.'
                  : 'Select an available ranking list to view it.',
              subtitleAsTitleTooltip: true,
              templateHeadersAsUploadTooltip: true,
              inlineActionsWithContext: true,
              showActionButtons: canManageRanking,
              contextFields: [
                if (showTournamentSelectionControls)
                  SizedBox(
                    width: 340,
                    child: DropdownButtonFormField<int>(
                      key: ValueKey<int?>(_selectedTournamentId),
                      initialValue: _selectedTournamentId,
                      decoration: const InputDecoration(
                        labelText: 'Tournament',
                      ),
                      items: _tournaments
                          .map(
                            (tournament) => DropdownMenuItem<int>(
                              value: tournament.id,
                              child: Text(
                                '${tournament.name} (${tournament.status})',
                              ),
                            ),
                          )
                          .toList(growable: false),
                      onChanged:
                          _uploading ||
                              _applying ||
                              _selectingRanking ||
                              _deletingRanking
                          ? null
                          : _onTournamentSelected,
                    ),
                  ),
                SizedBox(
                  width: 340,
                  child: DropdownButtonFormField<String>(
                    key: ValueKey<String?>(_selectedRankingOptionKey),
                    initialValue: _selectedRankingOptionKey,
                    decoration: const InputDecoration(
                      labelText: 'Available ranking',
                    ),
                    items: rankingSelectionItems,
                    onChanged:
                        _uploading ||
                            _applying ||
                            _selectingRanking ||
                            _deletingRanking ||
                            rankingSelectionItems.isEmpty
                        ? null
                        : _onRankingOptionSelected,
                  ),
                ),
                if (showTournamentSelectionControls)
                  SizedBox(
                    width: 240,
                    child: SrrSplitActionButton(
                      label: _selectingRanking
                          ? 'Selecting...'
                          : 'Select Ranking',
                      variant: SrrSplitActionButtonVariant.filled,
                      leadingIcon: Icons.check_circle_outline,
                      onPressed:
                          _selectingRanking ||
                              _uploading ||
                              _applying ||
                              _deletingRanking ||
                              _rankingOptions.isEmpty
                          ? null
                          : _selectRankingForTournament,
                    ),
                  ),
                if (canManageRanking)
                  SizedBox(
                    width: 240,
                    child: SrrSplitActionButton(
                      label: _deletingRanking
                          ? 'Deleting...'
                          : 'Delete From Db',
                      variant: SrrSplitActionButtonVariant.outlined,
                      leadingIcon: Icons.delete_forever,
                      onPressed:
                          _uploading ||
                              _applying ||
                              _selectingRanking ||
                              _deletingRanking ||
                              _selectedRankingOption == null
                          ? null
                          : _deleteSelectedRanking,
                    ),
                  ),
              ],
              uploading: _uploading,
              applying: _applying,
              onUploadPressed:
                  canManageRanking &&
                      !_uploading &&
                      !_applying &&
                      !_selectingRanking &&
                      !_deletingRanking
                  ? _pickUploadFile
                  : null,
              onApplyPressed:
                  canManageRanking &&
                      _uploadedRows.isNotEmpty &&
                      validRowsCount > 0 &&
                      !_uploading &&
                      !_applying &&
                      !_selectingRanking &&
                      !_deletingRanking
                  ? _applyUpload
                  : null,
              uploadButtonLabel: 'Upload CSV/XLSX',
              applyButtonLabel: 'Save To Database',
              templateHeadersText:
                  'Template headers: Rank, Player Name, State, Country, Email_Id, Ranking Points, Ranking Year, Last Updated',
              fileName: _fileName,
              stats: rankingStats,
              notes: [
                if (canManageRanking &&
                    _fileName != null &&
                    invalidRowsCount > 0)
                  'Rows with blank rank or duplicate rank are highlighted in red and skipped on save.',
                if (_uploadedRows.isEmpty && dbRowsCount > 0)
                  'Showing $dbRowsCount ranking row(s) from database.',
                if (_rankingOptions.isEmpty)
                  canManageRanking
                      ? 'No ranking lists exist yet. Upload a file and provide a ranking description to create one.'
                      : 'No ranking lists exist yet.',
                if (showTournamentContextSummary)
                  _currentTournamentRankingLabel(),
              ],
              notesErrorStyle: true,
              uploadError: _uploadError,
              applyError: canManageRanking ? _applyError : null,
              emptyPreviewMessage: emptyPreviewMessage,
              columns: const [
                'Rank',
                'Player Name',
                'State',
                'Country',
                'Email_Id',
                'Ranking Points',
                'Ranking Year',
                'Last Updated',
              ],
              previewRows: _rankingPreviewRows,
              onInvalidRowTap: canManageRanking
                  ? _openInlineEditorForInvalidRow
                  : null,
              selectedPreviewRowIndex: canManageRanking
                  ? _editingInvalidRowIndex
                  : null,
              inlineEditor: canManageRanking
                  ? _buildInlineEditor(context)
                  : null,
              footer: _selectionError == null && _dbRowsError == null
                  ? (_loadingDbRows
                        ? const LinearProgressIndicator(minHeight: 2)
                        : null)
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        if (_selectionError != null)
                          Text(
                            _selectionError!,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        if (_dbRowsError != null)
                          Text(
                            _dbRowsError!,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                      ],
                    ),
            ),
        ],
      ),
    );
  }
}

class _AdminAccessRequiredCard extends StatelessWidget {
  const _AdminAccessRequiredCard({required this.featureName});

  final String featureName;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          '$featureName is available only for admin accounts.',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
