// ---------------------------------------------------------------------------
// srr_app/lib/src/ui/srr_tournament_setup_page.dart
// ---------------------------------------------------------------------------
//
// Purpose:
// - Manages tournament catalog, workflow steps, and setup/editing operations.
// Architecture:
// - Feature page orchestrating setup workflow state and admin actions.
// - Delegates tournament persistence and workflow updates to repository APIs.
// Author: Neil Khatu
// Copyright (c) The Khatu Family Trust
//
import 'package:catu_framework/catu_framework.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../api/srr_api_client.dart';
import '../models/srr_models.dart';
import '../repositories/srr_tournament_repository.dart';
import '../theme/srr_display_preferences_controller.dart';
import 'srr_page_scaffold.dart';
import 'srr_routes.dart';
import 'srr_split_action_button.dart';
import 'srr_tournament_editor_card.dart';
import 'srr_tournament_groups_page.dart';
import 'srr_tournament_seeding_page.dart';
import 'srr_upload_page.dart';

class SrrTournamentSetupPage extends StatefulWidget {
  const SrrTournamentSetupPage({
    super.key,
    required this.appState,
    required this.apiClient,
    required this.tournamentRepository,
    required this.displayPreferencesController,
  });

  final AppState appState;
  final SrrApiClient apiClient;
  final SrrTournamentRepository tournamentRepository;
  final SrrDisplayPreferencesController displayPreferencesController;

  @override
  State<SrrTournamentSetupPage> createState() => _SrrTournamentSetupPageState();
}

class _SrrTournamentSetupPageState extends State<SrrTournamentSetupPage> {
  static const List<_WorkflowStepDefinition> _workflowSteps =
      <_WorkflowStepDefinition>[
        _WorkflowStepDefinition(
          key: 'create_tournament',
          title: 'Create Tournament',
        ),
        _WorkflowStepDefinition(
          key: 'load_registered_players',
          title: 'Load Registered Player',
        ),
        _WorkflowStepDefinition(
          key: 'load_current_national_ranking',
          title: 'Select National Ranking',
        ),
        _WorkflowStepDefinition(
          key: 'create_tournament_seeding',
          title: 'Create Tournament Seeding',
        ),
        _WorkflowStepDefinition(
          key: 'create_tournament_groups',
          title: 'Create Groups',
        ),
        _WorkflowStepDefinition(
          key: 'generate_matchups_next_round',
          title: 'Generate Match-Ups',
        ),
        _WorkflowStepDefinition(
          key: 'create_final_srr_standings',
          title: 'Create Final SRR Standings',
        ),
        _WorkflowStepDefinition(
          key: 'generate_knockout_brackets',
          title: 'Generate Knockouts',
        ),
        _WorkflowStepDefinition(
          key: 'generate_final_tournament_standings',
          title: 'Generate Tournament Standings',
        ),
        _WorkflowStepDefinition(
          key: 'announce_winners',
          title: 'Announce Winners',
        ),
      ];
  static const Set<PointerDeviceKind> _dragDevices = <PointerDeviceKind>{
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse,
    PointerDeviceKind.stylus,
    PointerDeviceKind.invertedStylus,
    PointerDeviceKind.trackpad,
    PointerDeviceKind.unknown,
  };

  bool _loading = true;
  bool _busy = false;
  String? _loadError;
  DateTime? _lastRefresh;

  final ScrollController _catalogVerticalController = ScrollController();
  final ScrollController _catalogHorizontalController = ScrollController();
  final ScrollController _workflowVerticalController = ScrollController();
  final ScrollController _workflowHorizontalController = ScrollController();

  List<SrrTournamentRecord> _tournaments = const [];
  SrrTournamentRecord? _selectedTournament;
  bool _showInlineEditor = false;

  @override
  void initState() {
    super.initState();
    _loadTournaments();
  }

  @override
  void dispose() {
    _catalogVerticalController.dispose();
    _catalogHorizontalController.dispose();
    _workflowVerticalController.dispose();
    _workflowHorizontalController.dispose();
    super.dispose();
  }

  Future<void> _loadTournaments({
    int? preferredTournamentId,
    bool showLoading = true,
  }) async {
    final previousSelectedId = _selectedTournament?.id;
    if (showLoading) {
      setState(() {
        _loading = true;
        _loadError = null;
      });
    }

    try {
      final tournaments = await widget.tournamentRepository.fetchTournaments();
      final preferredId = preferredTournamentId ?? _selectedTournament?.id;
      final selected = preferredId == null
          ? null
          : (tournaments.where((entry) => entry.id == preferredId).isNotEmpty
                ? tournaments.firstWhere((entry) => entry.id == preferredId)
                : null);

      if (!mounted) return;
      setState(() {
        _tournaments = tournaments;
        _selectedTournament = selected;
        _showInlineEditor = previousSelectedId == selected?.id
            ? _showInlineEditor
            : false;
        _loading = false;
        _busy = false;
        _loadError = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _busy = false;
        _loadError = error.toString();
      });
    }
  }

  Future<String?> _promptCopyTournamentName(String sourceName) async {
    final controller = TextEditingController(text: '$sourceName Copy');
    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Copy Tournament'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'New tournament name'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            SizedBox(
              width: 140,
              child: SrrSplitActionButton(
                label: 'Create',
                variant: SrrSplitActionButtonVariant.filled,
                leadingIcon: Icons.add,
                onPressed: () {
                  Navigator.of(context).pop(controller.text.trim());
                },
              ),
            ),
          ],
        );
      },
    );
    controller.dispose();
    if (result == null || result.trim().isEmpty) return null;
    return result.trim();
  }

  Future<String?> _promptCreateTournamentName() async {
    final controller = TextEditingController(text: 'New Tournament');
    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Create Tournament'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Tournament name'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            SizedBox(
              width: 140,
              child: SrrSplitActionButton(
                label: 'Create',
                variant: SrrSplitActionButtonVariant.filled,
                leadingIcon: Icons.add,
                onPressed: () {
                  Navigator.of(context).pop(controller.text.trim());
                },
              ),
            ),
          ],
        );
      },
    );
    controller.dispose();
    if (result == null || result.trim().isEmpty) return null;
    return result.trim();
  }

  Future<void> _copyAndCreateNewSelectedTournament() async {
    final selected = _selectedTournament;
    if (selected == null || _busy) return;

    final name = await _promptCopyTournamentName(selected.name);
    if (name == null || !mounted) return;

    setState(() => _busy = true);
    try {
      final created = await widget.tournamentRepository.replicateTournament(
        tournamentId: selected.id,
        tournamentName: name,
      );
      await _loadTournaments(
        preferredTournamentId: created.id,
        showLoading: false,
      );
      if (!mounted) return;
      setState(() => _lastRefresh = DateTime.now());
      final tournamentForEditor = _tournaments.firstWhere(
        (entry) => entry.id == created.id,
        orElse: () => created,
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Copied tournament: ${created.name}')),
      );
      if (!mounted) return;
      setState(() {
        _selectedTournament = tournamentForEditor;
        _showInlineEditor = true;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  Future<void> _editSelectedTournament() async {
    final selected = _selectedTournament;
    if (selected == null || _busy) return;
    setState(() => _showInlineEditor = true);
  }

  Future<bool?> _promptDeleteTournament(String tournamentName) {
    return showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete Tournament'),
          content: Text(
            'Delete "$tournamentName" and all linked rounds, matches, scores, and player links?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            SizedBox(
              width: 140,
              child: SrrSplitActionButton(
                label: 'Delete',
                variant: SrrSplitActionButtonVariant.filled,
                leadingIcon: Icons.delete,
                onPressed: () => Navigator.of(context).pop(true),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteSelectedTournament() async {
    final selected = _selectedTournament;
    if (selected == null || _busy) return;
    final confirmed = await _promptDeleteTournament(selected.name);
    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);
    try {
      await widget.tournamentRepository.deleteTournament(selected.id);
      await _loadTournaments(showLoading: false);
      if (!mounted) return;
      setState(() => _lastRefresh = DateTime.now());
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Deleted tournament: ${selected.name}')),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  Future<int?> _promptGroupCount({
    required int initialValue,
    required int participantLimit,
  }) async {
    final controller = TextEditingController(text: '$initialValue');
    String? localError;
    final result = await showDialog<int>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Set No. of Groups'),
              content: SizedBox(
                width: 320,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Allowed range: 2 - 64 and cannot exceed participant limit ($participantLimit).',
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: controller,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'No. of groups',
                        hintText: '2 - 64',
                      ),
                    ),
                    if (localError != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        localError!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                SizedBox(
                  width: 140,
                  child: SrrSplitActionButton(
                    label: 'Apply',
                    variant: SrrSplitActionButtonVariant.filled,
                    leadingIcon: Icons.check,
                    onPressed: () {
                      final parsed = int.tryParse(controller.text.trim());
                      if (parsed == null || parsed < 2 || parsed > 64) {
                        setDialogState(() {
                          localError =
                              'No. of groups must be an integer between 2 and 64.';
                        });
                        return;
                      }
                      if (parsed > participantLimit) {
                        setDialogState(() {
                          localError =
                              'No. of groups cannot exceed participant limit ($participantLimit).';
                        });
                        return;
                      }
                      Navigator.of(context).pop(parsed);
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
    controller.dispose();
    return result;
  }

  Future<void> _setSelectedTournamentGroupCount() async {
    final selected = _selectedTournament;
    if (selected == null || _busy) return;
    final metadata = selected.metadata;
    if (metadata == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tournament metadata is unavailable.')),
      );
      return;
    }

    final participantLimit = metadata.subType == 'singles'
        ? metadata.singlesMaxParticipants
        : metadata.doublesMaxTeams;
    final requestedGroupCount = await _promptGroupCount(
      initialValue: metadata.numberOfGroups,
      participantLimit: participantLimit,
    );
    if (requestedGroupCount == null || !mounted) return;

    final updatedMetadata = SrrTournamentMetadata(
      type: metadata.type,
      subType: metadata.subType,
      strength: metadata.strength,
      startDateTime: metadata.startDateTime,
      endDateTime: metadata.endDateTime,
      srrRounds: metadata.srrRounds,
      numberOfGroups: requestedGroupCount,
      singlesMaxParticipants: metadata.singlesMaxParticipants,
      doublesMaxTeams: metadata.doublesMaxTeams,
      numberOfTables: metadata.numberOfTables,
      roundTimeLimitMinutes: metadata.roundTimeLimitMinutes,
      venueName: metadata.venueName,
      directorName: metadata.directorName,
      referees: metadata.referees,
      chiefReferee: metadata.chiefReferee,
      category: metadata.category,
      subCategory: metadata.subCategory,
    );

    setState(() => _busy = true);
    try {
      final updated = await widget.tournamentRepository.updateTournament(
        tournamentId: selected.id,
        tournamentName: selected.name,
        status: selected.status,
        metadata: updatedMetadata,
      );
      await _loadTournaments(
        preferredTournamentId: updated.id,
        showLoading: false,
      );
      if (!mounted) return;
      setState(() => _lastRefresh = DateTime.now());
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'No. of groups updated to $requestedGroupCount for ${updated.name}.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  Future<void> _createTournament() async {
    if (_busy) return;
    final name = await _promptCreateTournamentName();
    if (name == null || !mounted) return;

    setState(() => _busy = true);
    try {
      final created = await widget.tournamentRepository.createTournament(
        tournamentName: name,
      );
      await _loadTournaments(
        preferredTournamentId: created.id,
        showLoading: false,
      );
      if (!mounted) return;
      setState(() => _lastRefresh = DateTime.now());
      final tournamentForEditor = _tournaments.firstWhere(
        (entry) => entry.id == created.id,
        orElse: () => created,
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Created tournament: ${created.name}')),
      );
      if (!mounted) return;
      setState(() {
        _selectedTournament = tournamentForEditor;
        _showInlineEditor = true;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  Future<void> _handleWorkflowStepPressed({
    required _WorkflowStepDefinition step,
    required bool isCompleted,
  }) async {
    final selectedTournament = _selectedTournament;
    if (selectedTournament == null) return;
    final requiresEditPrompt =
        isCompleted && step.key != 'create_tournament_groups';
    if (requiresEditPrompt) {
      final shouldEdit = await _promptWorkflowEdit(step.title);
      if (shouldEdit != true || !mounted) return;
    }

    switch (step.key) {
      case 'create_tournament':
        setState(() => _showInlineEditor = true);
        return;
      case 'load_registered_players':
        await Navigator.pushNamed(
          context,
          SrrRoutes.genericUpload,
          arguments: SrrUploadPageArguments(
            context: SrrUploadContext.players,
            tournamentId: selectedTournament.id,
          ),
        );
        if (mounted) {
          await _loadTournaments(
            preferredTournamentId: selectedTournament.id,
            showLoading: false,
          );
        }
        return;
      case 'load_current_national_ranking':
        await Navigator.pushNamed(
          context,
          SrrRoutes.genericUpload,
          arguments: SrrUploadPageArguments(
            context: SrrUploadContext.ranking,
            tournamentId: selectedTournament.id,
          ),
        );
        if (mounted) {
          await _loadTournaments(
            preferredTournamentId: selectedTournament.id,
            showLoading: false,
          );
        }
        return;
      case 'create_tournament_seeding':
        await Navigator.pushNamed(
          context,
          SrrRoutes.tournamentSeeding,
          arguments: SrrTournamentSeedingPageArguments(
            tournamentId: selectedTournament.id,
          ),
        );
        if (mounted) {
          await _loadTournaments(
            preferredTournamentId: selectedTournament.id,
            showLoading: false,
          );
        }
        return;
      case 'create_tournament_groups':
        await Navigator.pushNamed(
          context,
          SrrRoutes.tournamentGroups,
          arguments: SrrTournamentGroupsPageArguments(
            tournamentId: selectedTournament.id,
          ),
        );
        if (mounted) {
          await _loadTournaments(
            preferredTournamentId: selectedTournament.id,
            showLoading: false,
          );
        }
        return;
      case 'generate_matchups_next_round':
        await Navigator.pushNamed(context, SrrRoutes.roundMatchup);
        if (mounted) {
          await _loadTournaments(
            preferredTournamentId: selectedTournament.id,
            showLoading: false,
          );
        }
        return;
      default:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${step.title} is coming soon.')),
        );
        return;
    }
  }

  Future<bool?> _promptWorkflowEdit(String stepTitle) {
    return showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Step already completed'),
          content: Text(
            '$stepTitle is marked completed. Do you want to edit this step?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            SizedBox(
              width: 120,
              child: SrrSplitActionButton(
                label: 'Edit',
                variant: SrrSplitActionButtonVariant.filled,
                leadingIcon: Icons.edit,
                onPressed: () => Navigator.of(context).pop(true),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _saveTournament({
    required int tournamentId,
    required String tournamentName,
    required String status,
    required SrrTournamentMetadata metadata,
  }) async {
    final updated = await widget.tournamentRepository.updateTournament(
      tournamentId: tournamentId,
      tournamentName: tournamentName,
      status: status,
      metadata: metadata,
    );
    await _loadTournaments(
      preferredTournamentId: updated.id,
      showLoading: false,
    );
    if (!mounted) return;
    setState(() {
      _lastRefresh = DateTime.now();
      _showInlineEditor = false;
    });
  }

  String _formatDate(BuildContext context, DateTime dateTime) {
    if (dateTime.millisecondsSinceEpoch <= 0) return '-';
    return widget.displayPreferencesController.formatDateTime(
      dateTime,
      fallbackLocale: Localizations.localeOf(context),
    );
  }

  String _toInitCap(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return '-';
    final normalized = trimmed.replaceAll(RegExp(r'[_-]+'), ' ').toLowerCase();
    return normalized
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .map((word) => '${word[0].toUpperCase()}${word.substring(1)}')
        .join(' ');
  }

  String _catalogNameLabel(SrrTournamentRecord tournament) {
    final rawName = tournament.name.trim();
    final name = rawName.isEmpty ? '-' : rawName;
    final subType = tournament.metadata?.subType.trim() ?? '';
    if (subType.isEmpty) return name;
    return '$name - ${_toInitCap(subType)}';
  }

  Widget _statusPill(BuildContext context, String rawStatus) {
    final status = rawStatus.trim().toLowerCase();
    final scheme = Theme.of(context).colorScheme;

    Color background;
    Color foreground;
    String label;

    switch (status) {
      case 'active':
        background = scheme.tertiaryContainer;
        foreground = scheme.onTertiaryContainer;
        label = 'Active';
        break;
      case 'completed':
        background = scheme.secondaryContainer;
        foreground = scheme.onSecondaryContainer;
        label = 'Completed';
        break;
      default:
        background = scheme.surfaceContainerHighest;
        foreground = scheme.onSurfaceVariant;
        label = 'Setup';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: foreground,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildHeaderCard(
    BuildContext context,
    SrrUser? user,
    String lastRefresh,
  ) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 0,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              scheme.primaryContainer.withValues(alpha: 0.5),
              scheme.surfaceContainerHigh,
            ],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              'Tournament Administration',
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              'Manage tournament templates, duplicate prior events, and update configuration.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Chip(
                  avatar: const Icon(Icons.verified_user, size: 16),
                  label: Text(
                    user == null
                        ? 'Session not loaded'
                        : '${user.displayName} (${user.role})',
                  ),
                ),
                Chip(
                  avatar: const Icon(Icons.schedule, size: 16),
                  label: Text('Last action: $lastRefresh'),
                ),
                Chip(
                  avatar: const Icon(Icons.inventory_2_outlined, size: 16),
                  label: Text('Tournaments: ${_tournaments.length}'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTournamentTable(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    const nameColumnWidth = 260.0;
    const typeColumnWidth = 140.0;
    const categoryColumnWidth = 140.0;
    const subCategoryColumnWidth = 160.0;
    const startColumnWidth = 220.0;
    const endColumnWidth = 220.0;
    const statusColumnWidth = 140.0;
    const tableMinWidth =
        nameColumnWidth +
        typeColumnWidth +
        categoryColumnWidth +
        subCategoryColumnWidth +
        startColumnWidth +
        endColumnWidth +
        statusColumnWidth +
        120;

    Widget headerCell(String label, double width) => SizedBox(
      width: width,
      child: Text(
        label,
        textAlign: TextAlign.left,
        style: theme.textTheme.labelMedium?.copyWith(
          fontWeight: FontWeight.w800,
          letterSpacing: 0.2,
        ),
      ),
    );

    Widget valueCell(
      String value, {
      required double width,
      FontWeight? weight,
    }) => SizedBox(
      width: width,
      child: Text(
        value,
        textAlign: TextAlign.left,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodySmall?.copyWith(fontWeight: weight),
      ),
    );

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1180),
        child: Card(
          clipBehavior: Clip.antiAlias,
          elevation: 0,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  scheme.primaryContainer.withValues(alpha: 0.5),
                  scheme.surfaceContainerHigh,
                ],
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text(
                            'Tournament Catalog',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Click a row to view workflow and actions.',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    IconButton.filledTonal(
                      onPressed: _busy || _loading
                          ? null
                          : () => _loadTournaments(showLoading: true),
                      tooltip: 'Refresh tournaments',
                      icon: const Icon(Icons.refresh),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (_tournaments.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(child: Text('No tournaments available yet.')),
                  )
                else
                  Container(
                    constraints: const BoxConstraints(maxHeight: 420),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: theme.colorScheme.outlineVariant,
                      ),
                    ),
                    child: ScrollConfiguration(
                      behavior: const MaterialScrollBehavior().copyWith(
                        dragDevices: _dragDevices,
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Scrollbar(
                          controller: _catalogVerticalController,
                          thumbVisibility: true,
                          trackVisibility: true,
                          interactive: true,
                          child: SingleChildScrollView(
                            controller: _catalogVerticalController,
                            physics: const AlwaysScrollableScrollPhysics(),
                            child: Scrollbar(
                              controller: _catalogHorizontalController,
                              thumbVisibility: true,
                              trackVisibility: true,
                              interactive: true,
                              notificationPredicate: (notification) =>
                                  notification.metrics.axis == Axis.horizontal,
                              child: SingleChildScrollView(
                                controller: _catalogHorizontalController,
                                scrollDirection: Axis.horizontal,
                                physics: const AlwaysScrollableScrollPhysics(),
                                child: ConstrainedBox(
                                  constraints: const BoxConstraints(
                                    minWidth: tableMinWidth,
                                  ),
                                  child: Theme(
                                    data: theme.copyWith(
                                      dividerColor:
                                          theme.colorScheme.outlineVariant,
                                    ),
                                    child: DataTable(
                                      showCheckboxColumn: false,
                                      headingRowHeight: 44,
                                      dataRowMinHeight: 40,
                                      dataRowMaxHeight: 46,
                                      horizontalMargin: 10,
                                      columnSpacing: 12,
                                      headingRowColor: WidgetStatePropertyAll(
                                        theme
                                            .colorScheme
                                            .surfaceContainerHighest,
                                      ),
                                      columns: [
                                        DataColumn(
                                          label: headerCell(
                                            'Name',
                                            nameColumnWidth,
                                          ),
                                        ),
                                        DataColumn(
                                          label: headerCell(
                                            'Type',
                                            typeColumnWidth,
                                          ),
                                        ),
                                        DataColumn(
                                          label: headerCell(
                                            'Category',
                                            categoryColumnWidth,
                                          ),
                                        ),
                                        DataColumn(
                                          label: headerCell(
                                            'Sub Category',
                                            subCategoryColumnWidth,
                                          ),
                                        ),
                                        DataColumn(
                                          label: headerCell(
                                            'Start Date & Time',
                                            startColumnWidth,
                                          ),
                                        ),
                                        DataColumn(
                                          label: headerCell(
                                            'End Date & Time',
                                            endColumnWidth,
                                          ),
                                        ),
                                        DataColumn(
                                          label: headerCell(
                                            'Status',
                                            statusColumnWidth,
                                          ),
                                        ),
                                      ],
                                      rows: _tournaments
                                          .asMap()
                                          .entries
                                          .map((entry) {
                                            final index = entry.key;
                                            final tournament = entry.value;
                                            final isSelected =
                                                _selectedTournament?.id ==
                                                tournament.id;
                                            return DataRow(
                                              selected: isSelected,
                                              color:
                                                  WidgetStateProperty.resolveWith((
                                                    states,
                                                  ) {
                                                    if (states.contains(
                                                      WidgetState.selected,
                                                    )) {
                                                      return theme
                                                          .colorScheme
                                                          .primaryContainer
                                                          .withValues(
                                                            alpha: 0.4,
                                                          );
                                                    }
                                                    if (index.isOdd) {
                                                      return theme
                                                          .colorScheme
                                                          .surfaceContainerLow;
                                                    }
                                                    return null;
                                                  }),
                                              onSelectChanged: (selected) {
                                                setState(() {
                                                  if (selected == true) {
                                                    _selectedTournament =
                                                        tournament;
                                                    _showInlineEditor = false;
                                                  } else {
                                                    _selectedTournament = null;
                                                    _showInlineEditor = false;
                                                  }
                                                });
                                              },
                                              cells: [
                                                DataCell(
                                                  valueCell(
                                                    _catalogNameLabel(
                                                      tournament,
                                                    ),
                                                    width: nameColumnWidth,
                                                    weight: FontWeight.w600,
                                                  ),
                                                ),
                                                DataCell(
                                                  valueCell(
                                                    tournament.type.isEmpty
                                                        ? '-'
                                                        : _toInitCap(
                                                            tournament.type,
                                                          ),
                                                    width: typeColumnWidth,
                                                  ),
                                                ),
                                                DataCell(
                                                  valueCell(
                                                    tournament.category.isEmpty
                                                        ? '-'
                                                        : _toInitCap(
                                                            tournament.category,
                                                          ),
                                                    width: categoryColumnWidth,
                                                  ),
                                                ),
                                                DataCell(
                                                  valueCell(
                                                    tournament
                                                            .subCategory
                                                            .isEmpty
                                                        ? '-'
                                                        : _toInitCap(
                                                            tournament
                                                                .subCategory,
                                                          ),
                                                    width:
                                                        subCategoryColumnWidth,
                                                  ),
                                                ),
                                                DataCell(
                                                  valueCell(
                                                    _formatDate(
                                                      context,
                                                      tournament
                                                              .metadata
                                                              ?.startDateTime ??
                                                          DateTime.fromMillisecondsSinceEpoch(
                                                            0,
                                                          ),
                                                    ),
                                                    width: startColumnWidth,
                                                  ),
                                                ),
                                                DataCell(
                                                  valueCell(
                                                    _formatDate(
                                                      context,
                                                      tournament
                                                              .metadata
                                                              ?.endDateTime ??
                                                          DateTime.fromMillisecondsSinceEpoch(
                                                            0,
                                                          ),
                                                    ),
                                                    width: endColumnWidth,
                                                  ),
                                                ),
                                                DataCell(
                                                  SizedBox(
                                                    width: statusColumnWidth,
                                                    child: Align(
                                                      alignment:
                                                          Alignment.centerLeft,
                                                      child: _statusPill(
                                                        context,
                                                        tournament.status,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            );
                                          })
                                          .toList(growable: false),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 12),
                SizedBox(
                  width: 300,
                  child: SrrSplitActionButton(
                    label: 'Create Tournament',
                    variant: SrrSplitActionButtonVariant.filled,
                    leadingIcon: Icons.add_circle_outline,
                    onPressed: _busy || _loading ? null : _createTournament,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSetupWorkflowCard(BuildContext context) {
    final selectedTournament = _selectedTournament;
    if (selectedTournament == null) {
      return const SizedBox.shrink();
    }
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    const stepsPerRow = 3;
    const workflowButtonWidth = 280.0;
    const connectorWidth = 40.0;
    final workflowCanvasWidth =
        (stepsPerRow * workflowButtonWidth) +
        ((stepsPerRow - 1) * connectorWidth);

    final rowCount = (_workflowSteps.length / stepsPerRow).ceil();
    final snakeRows = <List<int>>[];
    for (int row = 0; row < rowCount; row += 1) {
      final start = row * stepsPerRow;
      final end = (start + stepsPerRow).clamp(0, _workflowSteps.length);
      final indexes = <int>[
        for (int index = start; index < end; index += 1) index,
      ];
      if (row.isOdd) {
        snakeRows.add(indexes.reversed.toList(growable: false));
      } else {
        snakeRows.add(indexes);
      }
    }

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1180),
        child: Card(
          elevation: 0,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  'Tournament Setup Workflow',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  selectedTournament.name,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 6),
                Text(
                  _selectedRankingLabel(selectedTournament),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  constraints: const BoxConstraints(maxHeight: 430),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: scheme.outlineVariant),
                  ),
                  child: ScrollConfiguration(
                    behavior: const MaterialScrollBehavior().copyWith(
                      dragDevices: _dragDevices,
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Scrollbar(
                        controller: _workflowVerticalController,
                        thumbVisibility: true,
                        trackVisibility: true,
                        interactive: true,
                        child: SingleChildScrollView(
                          controller: _workflowVerticalController,
                          physics: const AlwaysScrollableScrollPhysics(),
                          child: Scrollbar(
                            controller: _workflowHorizontalController,
                            thumbVisibility: true,
                            trackVisibility: true,
                            interactive: true,
                            notificationPredicate: (notification) =>
                                notification.metrics.axis == Axis.horizontal,
                            child: SingleChildScrollView(
                              controller: _workflowHorizontalController,
                              scrollDirection: Axis.horizontal,
                              physics: const AlwaysScrollableScrollPhysics(),
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(
                                  minWidth: 1160,
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      for (
                                        int rowIndex = 0;
                                        rowIndex < snakeRows.length;
                                        rowIndex += 1
                                      ) ...[
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            SizedBox(
                                              width: workflowCanvasWidth,
                                              child: Row(
                                                children: [
                                                  for (
                                                    int cellIndex = 0;
                                                    cellIndex <
                                                        snakeRows[rowIndex]
                                                            .length;
                                                    cellIndex += 1
                                                  ) ...[
                                                    Builder(
                                                      builder: (context) {
                                                        final step =
                                                            _workflowSteps[snakeRows[rowIndex][cellIndex]];
                                                        final isCompleted =
                                                            selectedTournament
                                                                .workflow
                                                                .stepByKey(
                                                                  step.key,
                                                                )
                                                                .isCompleted;
                                                        return _buildWorkflowStepButton(
                                                          step: step,
                                                          stepNumber:
                                                              snakeRows[rowIndex][cellIndex] +
                                                              1,
                                                          isCompleted:
                                                              isCompleted,
                                                          width:
                                                              workflowButtonWidth,
                                                        );
                                                      },
                                                    ),
                                                    if (cellIndex <
                                                        snakeRows[rowIndex]
                                                                .length -
                                                            1)
                                                      SizedBox(
                                                        width: connectorWidth,
                                                        child: Icon(
                                                          rowIndex.isEven
                                                              ? Icons.east
                                                              : Icons.west,
                                                          color: scheme.primary,
                                                        ),
                                                      ),
                                                  ],
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                        if (rowIndex < snakeRows.length - 1)
                                          SizedBox(
                                            width: workflowCanvasWidth,
                                            child: Align(
                                              alignment: rowIndex.isEven
                                                  ? Alignment.centerRight
                                                  : Alignment.centerLeft,
                                              child: Padding(
                                                padding: EdgeInsets.only(
                                                  left: rowIndex.isOdd
                                                      ? workflowButtonWidth / 2
                                                      : 0,
                                                  right: rowIndex.isEven
                                                      ? workflowButtonWidth / 2
                                                      : 0,
                                                  top: 8,
                                                  bottom: 8,
                                                ),
                                                child: Icon(
                                                  Icons.south,
                                                  color: scheme.primary,
                                                ),
                                              ),
                                            ),
                                          ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _selectedRankingLabel(SrrTournamentRecord tournament) {
    final year = tournament.selectedRankingYear;
    final description = tournament.selectedRankingDescription?.trim();
    if (year == null) {
      return 'Selected ranking: Not selected';
    }
    if (description == null || description.isEmpty) {
      return 'Selected ranking: $year';
    }
    return 'Selected ranking: $year - $description';
  }

  Widget _buildWorkflowStepButton({
    required _WorkflowStepDefinition step,
    required int stepNumber,
    required bool isCompleted,
    required double width,
  }) {
    return SizedBox(
      width: width,
      child: SrrSplitActionButton(
        label: '$stepNumber. ${step.title}',
        maxLines: 2,
        variant: isCompleted
            ? SrrSplitActionButtonVariant.filled
            : SrrSplitActionButtonVariant.outlined,
        leadingIcon: isCompleted ? Icons.check_circle : null,
        onPressed: _busy
            ? null
            : () => _handleWorkflowStepPressed(
                step: step,
                isCompleted: isCompleted,
              ),
      ),
    );
  }

  Widget _buildSelectedTournamentActions() {
    if (_selectedTournament == null) return const SizedBox.shrink();
    return Center(
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 10,
        runSpacing: 10,
        children: [
          SizedBox(
            width: 260,
            child: SrrSplitActionButton(
              label: 'Copy & Create New',
              variant: SrrSplitActionButtonVariant.filled,
              leadingIcon: Icons.copy,
              onPressed: _busy ? null : _copyAndCreateNewSelectedTournament,
            ),
          ),
          SizedBox(
            width: 190,
            child: SrrSplitActionButton(
              label: 'Edit',
              variant: SrrSplitActionButtonVariant.outlined,
              leadingIcon: Icons.edit,
              onPressed: _busy ? null : _editSelectedTournament,
            ),
          ),
          SizedBox(
            width: 210,
            child: SrrSplitActionButton(
              label: 'Set Groups',
              variant: SrrSplitActionButtonVariant.outlined,
              leadingIcon: Icons.group_work,
              onPressed: _busy ? null : _setSelectedTournamentGroupCount,
            ),
          ),
          SizedBox(
            width: 190,
            child: SrrSplitActionButton(
              label: 'Delete',
              variant: SrrSplitActionButtonVariant.outlined,
              leadingIcon: Icons.delete,
              onPressed: _busy ? null : _deleteSelectedTournament,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.apiClient.currentUserSnapshot;
    final lastRefreshLabel = _lastRefresh == null
        ? 'No tournament action yet'
        : widget.displayPreferencesController.formatDateTime(
            _lastRefresh!,
            fallbackLocale: Localizations.localeOf(context),
          );

    return SrrPageScaffold(
      title: 'Tournament Setup',
      appState: widget.appState,
      actions: [
        if (user?.isAdmin ?? false) ...[
          IconButton(
            tooltip: 'Player Upload',
            onPressed: () {
              Navigator.pushReplacementNamed(
                context,
                SrrRoutes.genericUpload,
                arguments: SrrUploadPageArguments(
                  context: SrrUploadContext.players,
                  tournamentId: _selectedTournament?.id,
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
          IconButton(
            tooltip: 'Tournament Seeding',
            onPressed: () {
              Navigator.pushNamed(
                context,
                SrrRoutes.tournamentSeeding,
                arguments: SrrTournamentSeedingPageArguments(
                  tournamentId: _selectedTournament?.id,
                ),
              );
            },
            icon: const Icon(Icons.format_list_numbered),
          ),
          IconButton(
            tooltip: 'Ranking Upload',
            onPressed: () {
              Navigator.pushNamed(
                context,
                SrrRoutes.genericUpload,
                arguments: SrrUploadPageArguments(
                  context: SrrUploadContext.ranking,
                  tournamentId: _selectedTournament?.id,
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
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1320),
              child: Column(
                children: [
                  _buildHeaderCard(context, user, lastRefreshLabel),
                  const SizedBox(height: 12),
                  if (!(user?.isAdmin ?? false))
                    const _AdminAccessRequiredCard(
                      featureName: 'Tournament Setup',
                    )
                  else if (_loading)
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(28),
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
                                variant: SrrSplitActionButtonVariant.filled,
                                leadingIcon: Icons.refresh,
                                onPressed: () =>
                                    _loadTournaments(showLoading: true),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else ...[
                    _buildTournamentTable(context),
                    if (_selectedTournament != null) ...[
                      const SizedBox(height: 12),
                      _buildSetupWorkflowCard(context),
                      const SizedBox(height: 12),
                      _buildSelectedTournamentActions(),
                      if (_showInlineEditor) ...[
                        const SizedBox(height: 12),
                        Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 1180),
                            child: SrrTournamentEditorCard(
                              key: ValueKey(_selectedTournament!.id),
                              tournament: _selectedTournament!,
                              canConfigure: !_busy,
                              displayPreferencesController:
                                  widget.displayPreferencesController,
                              onSave: _saveTournament,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WorkflowStepDefinition {
  const _WorkflowStepDefinition({required this.key, required this.title});

  final String key;
  final String title;
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
