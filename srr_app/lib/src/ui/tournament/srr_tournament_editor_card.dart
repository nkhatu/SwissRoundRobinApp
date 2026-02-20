// ---------------------------------------------------------------------------
// srr_app/lib/src/ui/tournament/srr_tournament_editor_card.dart
// ---------------------------------------------------------------------------
//
// Purpose:
// - Presents the editable tournament metadata form with a reusable controller.
// Architecture:
// - MVC pattern: `TournamentFormController` owns all field controllers/logic and notifies the view.
// - The widget focuses purely on layout, so other feature forms can reuse the controller/view helpers.
// Author: Neil Khatu
// Copyright (c) The Khatu Family Trust
//
import 'package:flutter/material.dart';

import '../../models/srr_models.dart';
import '../../theme/srr_display_preferences_controller.dart';
import '../helpers/srr_form_helpers.dart';
import 'tournament_form_controller.dart';

class SrrTournamentEditorCard extends StatefulWidget {
  const SrrTournamentEditorCard({
    super.key,
    required this.tournament,
    required this.canConfigure,
    required this.displayPreferencesController,
    required this.onSave,
  });

  final SrrTournamentRecord tournament;
  final bool canConfigure;
  final SrrDisplayPreferencesController displayPreferencesController;
  final Future<void> Function({
    required int tournamentId,
    required String tournamentName,
    required String status,
    required SrrTournamentMetadata metadata,
  }) onSave;

  @override
  State<SrrTournamentEditorCard> createState() => _SrrTournamentEditorCardState();
}

class _SrrTournamentEditorCardState extends State<SrrTournamentEditorCard> {
  late TournamentFormController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TournamentFormController(tournament: widget.tournament)
      ..addListener(_onControllerUpdated);
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerUpdated);
    _controller.dispose();
    super.dispose();
  }

  void _onControllerUpdated() => setState(() {});

  Future<void> _handleSave() async {
    await _controller.save(onSave: widget.onSave);
  }

  Future<void> _pickTournamentDateTime({required bool isStart}) async {
    final initial = isStart ? _controller.startDateTime : _controller.endDateTime;
    final selectedDate = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime.now().subtract(const Duration(days: 365 * 2)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
    );
    if (selectedDate == null) return;
    final selectedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (selectedTime == null) return;
    final combined = DateTime(
      selectedDate.year,
      selectedDate.month,
      selectedDate.day,
      selectedTime.hour,
      selectedTime.minute,
    );
    setState(() {
      if (isStart) {
        _controller.startDateTime = combined;
      } else {
        _controller.endDateTime = combined;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final derivedTables = _controller.derivedTables;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(theme),
            const SizedBox(height: 24),
            _buildFormSection(
              title: 'General',
              subtitle: 'Identity, status, and metadata',
              children: [
                _buildTextField(
                  controller: _controller.tournamentNameController,
                  label: 'Tournament name',
                ),
                _buildDropdown(
                  label: 'State',
                  value: _controller.tournamentStatus,
                  options: TournamentFormController.statusOptions,
                  onChanged: (value) {
                    _controller.tournamentStatus = value;
                    _controller.notifyListeners();
                  },
                ),
                _buildDropdown(
                  label: 'Type',
                  value: _controller.tournamentType,
                  options: TournamentFormController.typeOptions,
                  onChanged: (value) {
                    _controller.tournamentType = value;
                    _controller.notifyListeners();
                  },
                ),
                _buildDropdown(
                  label: 'Sub type',
                  value: _controller.tournamentSubType,
                  options: TournamentFormController.subTypeOptions,
                  onChanged: (value) {
                    _controller.tournamentSubType = value;
                    _controller.notifyListeners();
                  },
                ),
                _buildNumericField(
                  controller: _controller.tournamentStrengthController,
                  label: 'Strength (0.0 - 1.0)',
                ),
              ],
            ),
            const SizedBox(height: 18),
            _buildFormSection(
              title: 'Categories & Limits',
              subtitle: 'Player caps and classification',
              children: [
                _buildDropdown(
                  label: 'Category',
                  value: _controller.tournamentCategory,
                  options: TournamentFormController.categoryOptions,
                  onChanged: (value) {
                    _controller.tournamentCategory = value;
                    _controller.notifyListeners();
                  },
                ),
                _buildDropdown(
                  label: 'Sub category',
                  value: _controller.tournamentSubCategory,
                  options: TournamentFormController.subCategoryOptions,
                  onChanged: (value) {
                    _controller.tournamentSubCategory = value;
                    _controller.notifyListeners();
                  },
                ),
                _buildNumericField(
                  controller: _controller.singlesMaxParticipantsController,
                  label: 'Singles max participants',
                ),
                _buildNumericField(
                  controller: _controller.doublesMaxTeamsController,
                  label: 'Doubles max teams',
                ),
                _buildNumericField(
                  controller: _controller.roundTimeLimitMinutesController,
                  label: 'Round time limit (min)',
                ),
                _buildNumericField(
                  controller: _controller.srrRoundsController,
                  label: 'SRR rounds',
                ),
                _buildNumericField(
                  controller: _controller.numberOfGroupsController,
                  label: 'Groups',
                ),
              ],
            ),
            const SizedBox(height: 18),
            _buildFormSection(
              title: 'Officials',
              subtitle: 'Chief referee plus group of referees',
              children: [
                _buildTextField(
                  controller: _controller.chiefRefereeFirstNameController,
                  label: 'Chief referee first name',
                ),
                _buildTextField(
                  controller: _controller.chiefRefereeLastNameController,
                  label: 'Chief referee last name',
                ),
              ],
            ),
            const SizedBox(height: 18),
            _buildFormSection(
              title: 'Venue & Schedule',
              subtitle: 'Location and timeline',
              children: [
                _buildTextField(
                  controller: _controller.venueController,
                  label: 'Venue name',
                ),
                _buildTextField(
                  controller: _controller.directorController,
                  label: 'Director name',
                ),
                _buildDateButton(
                  label: 'Start',
                  dateTime: _controller.startDateTime,
                  onPressed: () => _pickTournamentDateTime(isStart: true),
                ),
                _buildDateButton(
                  label: 'End',
                  dateTime: _controller.endDateTime,
                  onPressed: () => _pickTournamentDateTime(isStart: false),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              derivedTables == null
                  ? 'Tables will auto-calculate once valid limits exist.'
                  : 'Estimated tables: $derivedTables',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton.icon(
                  onPressed: _controller.isSaving ? null : _controller.addReferee,
                  icon: const Icon(Icons.person_add),
                  label: const Text('Add Referee'),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: widget.canConfigure && !_controller.isSaving
                      ? _handleSave
                      : null,
                  icon: const Icon(Icons.save_outlined),
                  label: const Text('Save Tournament'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 26,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Column(
              children: _controller.refereeRows
                  .asMap()
                  .entries
                  .map((entry) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            Expanded(
                              child: _buildTextField(
                                controller: entry.value.firstNameController,
                                label: 'Referee ${entry.key + 1} first name',
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildTextField(
                                controller: entry.value.lastNameController,
                                label: 'Referee ${entry.key + 1} last name',
                              ),
                            ),
                            IconButton(
                              tooltip: 'Remove referee',
                              onPressed: _controller.isSaving
                                  ? null
                                  : () => _controller.removeReferee(entry.key),
                              icon: const Icon(Icons.remove_circle_outline),
                            ),
                          ],
                        ),
                      ))
                  .toList(growable: false),
            ),
            if (!widget.canConfigure)
              const Padding(
                padding: EdgeInsets.only(top: 12),
                child: Text(
                  'Tournament editing is restricted to admin accounts.',
                  textAlign: TextAlign.center,
                ),
              ),
            if (_controller.error != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: SrrInlineError(message: _controller.error!),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Edit Tournament',
          style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        Text(
          'Structured metadata capture with grouped sections.',
          style: theme.textTheme.bodyMedium,
        ),
      ],
    );
  }

  Widget _buildFormSection({
    required String title,
    required String subtitle,
    required List<Widget> children,
  }) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.shadow.withOpacity(0.12),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(subtitle, style: theme.textTheme.bodySmall),
          const SizedBox(height: 14),
          ..._interleaveFields(children),
        ],
      ),
    );
  }

  Iterable<Widget> _interleaveFields(List<Widget> fields) sync* {
    for (var index = 0; index < fields.length; index++) {
      yield fields[index];
      if (index < fields.length - 1) yield const SizedBox(height: 12);
    }
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
  }) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
    );
  }

  Widget _buildNumericField({
    required TextEditingController controller,
    required String label,
  }) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
    );
  }

  Widget _buildDropdown({
    required String label,
    required String value,
    required List<String> options,
    required ValueChanged<String> onChanged,
  }) {
    return DropdownButtonFormField<String>(
      value: value,
      decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
      items: options
          .map((entry) => DropdownMenuItem(value: entry, child: Text(entry.capitalize())))
          .toList(growable: false),
      onChanged: (updated) {
        if (updated == null) return;
        onChanged(updated);
      },
    );
  }

  Widget _buildDateButton({
    required String label,
    required DateTime dateTime,
    required VoidCallback onPressed,
  }) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
        foregroundColor: Theme.of(context).colorScheme.onSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      onPressed: onPressed,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.calendar_month_outlined, size: 18),
          const SizedBox(width: 8),
          Text('$label: ${_formatDateTimeLocal(dateTime)}'),
        ],
      ),
    );
  }

  String _formatDateTimeLocal(DateTime value) {
    return widget.displayPreferencesController.formatDateTime(
      value,
      fallbackLocale: Localizations.localeOf(context),
    );
  }

  @override
  void didUpdateWidget(covariant SrrTournamentEditorCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tournament.id != widget.tournament.id) {
      _controller.dispose();
      final newController = TournamentFormController(tournament: widget.tournament)
        ..addListener(_onControllerUpdated);
      _controller = newController;
    }
  }
}
