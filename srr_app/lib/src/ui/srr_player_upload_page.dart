// ---------------------------------------------------------------------------
// srr_app/lib/src/ui/srr_player_upload_page.dart
// ---------------------------------------------------------------------------
//
// Purpose:
// - Parses, validates, previews, and persists tournament player upload records.
// Architecture:
// - Feature page with inline validation/editing and upload workflow state.
// - Delegates file parsing and database operations to parser and repository layers.
// Author: Neil Khatu
// Copyright (c) The Khatu Family Trust
//
import 'package:catu_framework/catu_framework.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../api/srr_api_client.dart';
import '../models/srr_models.dart';
import '../repositories/srr_player_repository.dart';
import '../repositories/srr_tournament_repository.dart';
import '../services/player_upload_parser.dart';
import '../services/srr_tournament_labels.dart';
import '../theme/srr_display_preferences_controller.dart';
import 'srr_generic_upload_card.dart';
import 'srr_page_scaffold.dart';
import 'srr_round_matchup_page.dart';
import 'srr_routes.dart';
import 'srr_split_action_button.dart';
import 'srr_upload_page.dart';

class SrrPlayerUploadPage extends StatefulWidget {
  const SrrPlayerUploadPage({
    super.key,
    required this.appState,
    required this.apiClient,
    required this.playerRepository,
    required this.tournamentRepository,
    required this.displayPreferencesController,
    this.initialTournamentId,
  });

  final AppState appState;
  final SrrApiClient apiClient;
  final SrrPlayerRepository playerRepository;
  final SrrTournamentRepository tournamentRepository;
  final SrrDisplayPreferencesController displayPreferencesController;
  final int? initialTournamentId;

  @override
  State<SrrPlayerUploadPage> createState() => _SrrPlayerUploadPageState();
}

class _SrrPlayerUploadPageState extends State<SrrPlayerUploadPage> {
  static final RegExp _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  bool _loadingTournaments = true;
  bool _loadingTournamentPlayers = false;
  bool _uploading = false;
  bool _submitting = false;
  bool _deleting = false;

  String? _loadError;
  String? _uploadError;
  String? _submitError;
  String? _fileName;

  DateTime? _lastRefresh;
  List<SrrTournamentRecord> _tournaments = const [];
  int? _selectedTournamentId;

  List<SrrPlayerLite> _currentTournamentPlayers = const [];
  List<TournamentUploadPlayerRow> _uploadedPlayers = const [];
  int? _editingInvalidRowIndex;

  final TextEditingController _editDisplayNameController =
      TextEditingController();
  final TextEditingController _editStateController = TextEditingController();
  final TextEditingController _editCountryController = TextEditingController();
  final TextEditingController _editEmailController = TextEditingController();
  final TextEditingController _editPhoneController = TextEditingController();

  List<TournamentUploadPlayerRow> get _validUploadedPlayers =>
      _uploadedPlayers.where((row) => row.isValid).toList(growable: false);

  int get _invalidUploadedPlayersCount =>
      _uploadedPlayers.where((row) => !row.isValid).length;

  List<SrrUploadPreviewRow> get _combinedPreviewRows {
    final uploadedRows = _uploadedPlayers
        .asMap()
        .entries
        .map((entry) {
          final row = entry.value;
          return SrrUploadPreviewRow(
            isValid: row.isValid,
            isNew: true,
            editableRowIndex: entry.key,
            values: [
              row.displayName,
              row.state,
              row.country,
              row.emailId,
              row.registeredFlag ? 'Yes' : 'No',
              row.tshirtSize,
              row.feesPaidFlag ? 'Yes' : 'No',
              row.phoneNumber,
            ],
            errors: row.validationErrors,
          );
        })
        .toList(growable: false);

    final existingRows = _currentTournamentPlayers
        .map(
          (player) => SrrUploadPreviewRow(
            isValid: true,
            values: [
              player.displayName,
              player.state ?? '',
              player.country ?? '',
              player.emailId ?? '',
              (player.registeredFlag ?? false) ? 'Yes' : 'No',
              player.tshirtSize?.trim().isNotEmpty == true
                  ? player.tshirtSize!.trim()
                  : 'L',
              (player.feesPaidFlag ?? false) ? 'Yes' : 'No',
              player.phoneNumber ?? '',
            ],
          ),
        )
        .toList(growable: false);

    final combined = uploadedRows.isEmpty
        ? existingRows
        : [...uploadedRows, ...existingRows];
    final invalidRows = combined
        .where((row) => !row.isValid)
        .toList(growable: false);
    final validRows = combined
        .where((row) => row.isValid)
        .toList(growable: false);
    return [...invalidRows, ...validRows];
  }

  TournamentUploadPlayerRow? get _editingInvalidRow {
    final rowIndex = _editingInvalidRowIndex;
    if (rowIndex == null ||
        rowIndex < 0 ||
        rowIndex >= _uploadedPlayers.length) {
      return null;
    }
    final row = _uploadedPlayers[rowIndex];
    if (row.isValid) return null;
    return row;
  }

  SrrTournamentRecord? get _selectedTournament {
    final selectedId = _selectedTournamentId;
    if (selectedId == null) return null;
    for (final tournament in _tournaments) {
      if (tournament.id == selectedId) return tournament;
    }
    return null;
  }

  int? get _selectedTournamentParticipantLimit {
    final metadata = _selectedTournament?.metadata;
    if (metadata == null) return null;
    return metadata.subType == 'singles'
        ? metadata.singlesMaxParticipants
        : metadata.doublesMaxTeams;
  }

  @override
  void initState() {
    super.initState();
    _loadTournaments(preferredTournamentId: widget.initialTournamentId);
  }

  @override
  void dispose() {
    _editDisplayNameController.dispose();
    _editStateController.dispose();
    _editCountryController.dispose();
    _editEmailController.dispose();
    _editPhoneController.dispose();
    super.dispose();
  }

  Future<void> _loadTournaments({int? preferredTournamentId}) async {
    setState(() {
      _loadingTournaments = true;
      _loadError = null;
    });
    try {
      final tournaments = await widget.tournamentRepository.fetchTournaments();
      int? nextSelectedTournamentId =
          preferredTournamentId ?? _selectedTournamentId;
      if (nextSelectedTournamentId != null &&
          tournaments.every(
            (tournament) => tournament.id != nextSelectedTournamentId,
          )) {
        nextSelectedTournamentId = null;
      }
      final shouldLoadPlayers =
          nextSelectedTournamentId != null &&
          (nextSelectedTournamentId != _selectedTournamentId ||
              _currentTournamentPlayers.isEmpty);
      if (!mounted) return;
      setState(() {
        _tournaments = tournaments;
        _selectedTournamentId = nextSelectedTournamentId;
        _loadingTournaments = false;
      });
      final selectedTournamentIdForLoad = nextSelectedTournamentId;
      if (shouldLoadPlayers && selectedTournamentIdForLoad != null) {
        await _loadTournamentPlayers(selectedTournamentIdForLoad);
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadingTournaments = false;
        _loadError = error.toString();
      });
    }
  }

  Future<void> _onTournamentSelected(int? tournamentId) async {
    setState(() {
      _selectedTournamentId = tournamentId;
      _uploadedPlayers = const [];
      _editingInvalidRowIndex = null;
      _fileName = null;
      _uploadError = null;
      _submitError = null;
    });
    if (tournamentId == null) {
      setState(() => _currentTournamentPlayers = const []);
      return;
    }
    await _loadTournamentPlayers(tournamentId);
  }

  Future<void> _loadTournamentPlayers(int tournamentId) async {
    setState(() {
      _loadingTournamentPlayers = true;
      _submitError = null;
    });
    try {
      final players = await widget.playerRepository.fetchTournamentPlayers(
        tournamentId,
      );
      if (!mounted) return;
      setState(() => _currentTournamentPlayers = players);
    } catch (error) {
      if (!mounted) return;
      setState(() => _submitError = error.toString());
    } finally {
      if (mounted) {
        setState(() => _loadingTournamentPlayers = false);
      }
    }
  }

  Future<void> _pickUploadFile() async {
    if (_selectedTournamentId == null) {
      setState(() {
        _uploadError = 'Select a tournament before uploading players.';
      });
      return;
    }

    setState(() {
      _uploading = true;
      _uploadError = null;
      _submitError = null;
      _editingInvalidRowIndex = null;
    });

    try {
      final picked = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['csv', 'xlsx', 'xls'],
        withData: true,
      );
      if (picked == null || picked.files.isEmpty) {
        return;
      }

      final file = picked.files.first;
      final fileName = file.name;
      final fileBytes = file.bytes;
      if (fileBytes == null) {
        throw const FormatException(
          'File content could not be read. Please retry with a local file.',
        );
      }

      final parsedPlayers = PlayerUploadParser.parse(
        fileName: fileName,
        bytes: fileBytes,
      );
      if (!mounted) return;

      setState(() {
        _fileName = fileName;
        _uploadedPlayers = parsedPlayers;
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
    if (rowIndex < 0 || rowIndex >= _uploadedPlayers.length) return;
    final row = _uploadedPlayers[rowIndex];
    if (row.isValid) return;
    setState(() {
      _editingInvalidRowIndex = rowIndex;
      _editDisplayNameController.text = row.displayName;
      _editStateController.text = row.state;
      _editCountryController.text = row.country;
      _editEmailController.text = row.emailId;
      _editPhoneController.text = row.phoneNumber;
      _uploadError = null;
      _submitError = null;
    });
  }

  void _cancelInlineEdit() {
    setState(() {
      _editingInvalidRowIndex = null;
    });
  }

  void _applyInlineEdit() {
    final rowIndex = _editingInvalidRowIndex;
    if (rowIndex == null ||
        rowIndex < 0 ||
        rowIndex >= _uploadedPlayers.length) {
      return;
    }
    final currentRow = _uploadedPlayers[rowIndex];
    final updatedRow = PlayerUploadParser.buildRow(
      displayName: _editDisplayNameController.text,
      state: _editStateController.text,
      country: _editCountryController.text,
      emailId: _editEmailController.text,
      phoneNumber: _editPhoneController.text,
      registeredFlag: currentRow.registeredFlag,
      tshirtSize: currentRow.tshirtSize,
      feesPaidFlag: currentRow.feesPaidFlag,
    );
    final nextRows = List<TournamentUploadPlayerRow>.from(_uploadedPlayers);
    nextRows[rowIndex] = updatedRow;
    final revalidatedRows = PlayerUploadParser.revalidateRows(nextRows);
    final editedRow = revalidatedRows[rowIndex];

    setState(() {
      _uploadedPlayers = revalidatedRows;
      _editingInvalidRowIndex = editedRow.isValid ? null : rowIndex;
    });

    if (editedRow.isValid) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Row ${rowIndex + 1} updated successfully.')),
      );
    }
  }

  Future<void> _submitUpload() async {
    final tournamentId = _selectedTournamentId;
    if (tournamentId == null || _uploadedPlayers.isEmpty) return;
    final validRows = _validUploadedPlayers;
    var rowsToUpload = validRows;
    final participantLimit = _selectedTournamentParticipantLimit;
    if (participantLimit != null &&
        participantLimit > 0 &&
        rowsToUpload.length > participantLimit) {
      rowsToUpload = rowsToUpload
          .take(participantLimit)
          .toList(growable: false);
    }

    if (rowsToUpload.length < 2) {
      setState(() {
        _submitError =
            'Need at least 2 valid player rows. Red rows are skipped on save.';
      });
      return;
    }

    setState(() {
      _submitting = true;
      _submitError = null;
    });

    try {
      final result = await widget.playerRepository.uploadTournamentPlayers(
        tournamentId: tournamentId,
        players: rowsToUpload
            .map(
              (row) => SrrTournamentSetupPlayerInput(
                displayName: row.displayName,
                state: row.state,
                country: row.country,
                emailId: row.emailId,
                registeredFlag: row.registeredFlag,
                tshirtSize: row.tshirtSize,
                feesPaidFlag: row.feesPaidFlag,
                phoneNumber: row.phoneNumber,
              ),
            )
            .toList(growable: false),
      );

      if (!mounted) return;
      await widget.tournamentRepository.updateTournamentWorkflowStep(
        tournamentId: tournamentId,
        stepKey: 'load_registered_players',
        status: 'completed',
      );
      if (!mounted) return;
      final skippedRows = _uploadedPlayers.length - rowsToUpload.length;
      final overflowRows = validRows.length - rowsToUpload.length;
      setState(() {
        _currentTournamentPlayers = result.players;
        _lastRefresh = DateTime.now();
        _submitError = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Uploaded ${result.playersUploaded} players for ${result.tournament.name}.'
            '${skippedRows > 0 ? ' Skipped $skippedRows row(s).' : ''}'
            '${overflowRows > 0 && participantLimit != null ? ' Tournament limit: $participantLimit.' : ''}',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _submitError = error.toString());
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  Future<bool?> _confirmDeletePlayers(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete Tournament Players'),
          content: const Text(
            'This removes all player rows linked to the selected tournament. Continue?',
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

  Future<void> _deleteTournamentPlayers() async {
    final tournamentId = _selectedTournamentId;
    if (tournamentId == null || _deleting) return;
    final confirmed = await _confirmDeletePlayers(context);
    if (confirmed != true || !mounted) return;

    setState(() {
      _deleting = true;
      _submitError = null;
      _uploadError = null;
    });
    try {
      final result = await widget.playerRepository.deleteTournamentPlayers(
        tournamentId,
      );
      if (!mounted) return;
      setState(() {
        _currentTournamentPlayers = result.players;
        _uploadedPlayers = const [];
        _editingInvalidRowIndex = null;
        _fileName = null;
        _lastRefresh = DateTime.now();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Deleted ${result.playersDeleted} player row(s) for ${result.tournament.name}.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _submitError = error.toString());
    } finally {
      if (mounted) {
        setState(() => _deleting = false);
      }
    }
  }

  Widget? _buildInlineEditor(BuildContext context) {
    final rowIndex = _editingInvalidRowIndex;
    final row = _editingInvalidRow;
    if (rowIndex == null || row == null) return null;

    final needsDisplayName = row.displayName.trim().isEmpty;
    final needsState = row.state.trim().isEmpty;
    final needsCountry = row.country.trim().isEmpty;
    final emailTrimmed = row.emailId.trim();
    final needsEmail =
        emailTrimmed.isEmpty || !_emailPattern.hasMatch(emailTrimmed);
    final needsPhone = row.phoneNumber.trim().isEmpty;

    final fields = <Widget>[
      if (needsDisplayName)
        _InlineEditField(
          controller: _editDisplayNameController,
          label: 'Player Name',
          hint: 'Enter player name',
        ),
      if (needsState)
        _InlineEditField(
          controller: _editStateController,
          label: 'State',
          hint: 'Enter state',
        ),
      if (needsCountry)
        _InlineEditField(
          controller: _editCountryController,
          label: 'Country',
          hint: 'Enter country',
        ),
      if (needsEmail)
        _InlineEditField(
          controller: _editEmailController,
          label: 'Email_Id',
          hint: 'Enter valid email',
          keyboardType: TextInputType.emailAddress,
        ),
      if (needsPhone)
        _InlineEditField(
          controller: _editPhoneController,
          label: 'Phone Number',
          hint: 'Enter phone number',
          keyboardType: TextInputType.phone,
        ),
    ];

    if (fields.isEmpty) {
      fields.addAll([
        _InlineEditField(
          controller: _editDisplayNameController,
          label: 'Player Name',
          hint: 'Enter player name',
        ),
        _InlineEditField(
          controller: _editStateController,
          label: 'State',
          hint: 'Enter state',
        ),
        _InlineEditField(
          controller: _editCountryController,
          label: 'Country',
          hint: 'Enter country',
        ),
        _InlineEditField(
          controller: _editEmailController,
          label: 'Email_Id',
          hint: 'Enter valid email',
          keyboardType: TextInputType.emailAddress,
        ),
        _InlineEditField(
          controller: _editPhoneController,
          label: 'Phone Number',
          hint: 'Enter phone number',
          keyboardType: TextInputType.phone,
        ),
      ]);
    }

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
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 10,
            runSpacing: 10,
            children: fields,
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

  @override
  Widget build(BuildContext context) {
    final user = widget.apiClient.currentUserSnapshot;
    final isAdmin = user?.isAdmin ?? false;
    final isTournamentSelectionLocked = widget.initialTournamentId != null;
    final selectedTournament = _selectedTournament;
    final validPlayersCount = _validUploadedPlayers.length;
    final invalidPlayersCount = _invalidUploadedPlayersCount;
    final participantLimit = _selectedTournamentParticipantLimit;
    final effectivePlayersToApply = participantLimit == null
        ? validPlayersCount
        : validPlayersCount > participantLimit
        ? participantLimit
        : validPlayersCount;
    final overflowPlayersCount = participantLimit == null
        ? 0
        : (validPlayersCount - participantLimit).clamp(0, validPlayersCount);
    final uploadNotes = <String>[
      if (invalidPlayersCount > 0)
        'Invalid rows are highlighted in red and skipped when saving to database.',
      if (_uploadedPlayers.isNotEmpty)
        'Rows marked with the NEW icon are from the latest uploaded file.',
      if (overflowPlayersCount > 0)
        '$overflowPlayersCount valid row(s) exceed tournament limit and will be skipped on save.',
    ];
    final uploadStats = _fileName == null
        ? const <SrrUploadStatItem>[]
        : <SrrUploadStatItem>[
            SrrUploadStatItem(
              label: 'Tournament capacity',
              value: participantLimit?.toString() ?? 'Not set',
            ),
            SrrUploadStatItem(
              label: 'Players in file',
              value: '${_uploadedPlayers.length}',
            ),
            SrrUploadStatItem(
              label: 'Error records',
              value: '$invalidPlayersCount',
            ),
            SrrUploadStatItem(
              label: 'Saved to db',
              value: '$effectivePlayersToApply',
            ),
          ];
    final lastRefreshLabel = _lastRefresh == null
        ? 'No upload action yet'
        : widget.displayPreferencesController.formatDateTime(
            _lastRefresh!,
            fallbackLocale: Localizations.localeOf(context),
          );

    return SrrPageScaffold(
      title: 'Player Upload',
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
            tooltip: 'Round Matchup',
            onPressed: () {
              Navigator.pushNamed(
                context,
                SrrRoutes.roundMatchup,
                arguments: SrrRoundMatchupPageArguments(
                  tournamentId: _selectedTournamentId,
                ),
              );
            },
            icon: const Icon(Icons.grid_view),
          ),
          IconButton(
            tooltip: 'Ranking Upload',
            onPressed: () {
              Navigator.pushNamed(
                context,
                SrrRoutes.genericUpload,
                arguments: const SrrUploadPageArguments(
                  context: SrrUploadContext.ranking,
                ),
              );
            },
            icon: const Icon(Icons.leaderboard),
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
                    'Last player upload action: $lastRefreshLabel',
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (!isAdmin)
            const _AdminAccessRequiredCard(featureName: 'Player List Upload')
          else if (_loadingTournaments)
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
                      'Failed to load tournaments: $_loadError',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: 220,
                      child: SrrSplitActionButton(
                        label: 'Retry',
                        leadingIcon: Icons.refresh,
                        variant: SrrSplitActionButtonVariant.filled,
                        onPressed: _loadTournaments,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            SrrGenericUploadCard(
              title: 'Tournament Player Upload',
              subtitle:
                  'Select a tournament, upload player CSV/XLSX, then save the player list to that tournament.',
              subtitleAsTitleTooltip: true,
              templateHeadersAsUploadTooltip: true,
              inlineActionsWithContext: true,
              contextFields: [
                if (isTournamentSelectionLocked)
                  SizedBox(
                    width: 420,
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Tournament',
                      ),
                      child: Text(
                        selectedTournament == null
                            ? 'Not selected'
                            : srrTournamentDropdownLabel(selectedTournament),
                      ),
                    ),
                  ),
                if (!isTournamentSelectionLocked)
                  SizedBox(
                    width: 420,
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
                                srrTournamentDropdownLabel(tournament),
                              ),
                            ),
                          )
                          .toList(growable: false),
                      onChanged: _submitting || _uploading || _deleting
                          ? null
                          : _onTournamentSelected,
                    ),
                  ),
                SizedBox(
                  width: 240,
                  child: SrrSplitActionButton(
                    label: _deleting ? 'Deleting...' : 'Delete From Db',
                    leadingIcon: Icons.delete_forever,
                    variant: SrrSplitActionButtonVariant.outlined,
                    onPressed:
                        _selectedTournamentId == null ||
                            _submitting ||
                            _uploading ||
                            _deleting
                        ? null
                        : _deleteTournamentPlayers,
                  ),
                ),
              ],
              uploading: _uploading,
              applying: _submitting,
              onUploadPressed: _uploading || _submitting || _deleting
                  ? null
                  : _pickUploadFile,
              onApplyPressed:
                  _selectedTournamentId != null &&
                      effectivePlayersToApply >= 2 &&
                      !_submitting &&
                      !_uploading &&
                      !_deleting
                  ? _submitUpload
                  : null,
              uploadButtonLabel: 'Upload CSV/XLSX',
              applyButtonLabel: 'Save To Database',
              templateHeadersText:
                  'Template headers: Player Name, State, Country, Email_Id, Registered Flag, T-Shirt Size, Fees Paid Flag, Phone Number',
              fileName: _fileName,
              stats: uploadStats,
              notes: _fileName == null ? const [] : uploadNotes,
              notesErrorStyle: true,
              uploadError: _uploadError,
              applyError: _submitError,
              columns: const [
                'Player Name',
                'State',
                'Country',
                'Email_Id',
                'Registered Flag',
                'T-Shirt Size',
                'Fees Paid Flag',
                'Phone Number',
              ],
              previewRows: _combinedPreviewRows,
              onInvalidRowTap: _openInlineEditorForInvalidRow,
              selectedPreviewRowIndex: _editingInvalidRowIndex,
              inlineEditor: _buildInlineEditor(context),
              footer: _loadingTournamentPlayers
                  ? const LinearProgressIndicator(minHeight: 2)
                  : _CurrentPlayersSummary(players: _currentTournamentPlayers),
            ),
        ],
      ),
    );
  }
}

class _InlineEditField extends StatelessWidget {
  const _InlineEditField({
    required this.controller,
    required this.label,
    required this.hint,
    this.keyboardType,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 250,
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          isDense: true,
        ),
      ),
    );
  }
}

class _CurrentPlayersSummary extends StatelessWidget {
  const _CurrentPlayersSummary({required this.players});

  final List<SrrPlayerLite> players;

  @override
  Widget build(BuildContext context) {
    if (players.isEmpty) {
      return const Text('Current tournament players: none');
    }

    return Chip(label: Text('Current players: ${players.length}'));
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
