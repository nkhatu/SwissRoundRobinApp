// ---------------------------------------------------------------------------
// srr_app/lib/src/ui/srr_tournament_editor_card.dart
// ---------------------------------------------------------------------------
// 
// Purpose:
// - Renders reusable tournament form controls for create/edit operations.
// Architecture:
// - Reusable presentation component encapsulating tournament metadata inputs.
// - Keeps field-level form concerns isolated from page-level orchestration.
// Author: Neil Khatu
// Copyright (c) The Khatu Family Trust
// 
import 'package:flutter/material.dart';

import '../models/srr_models.dart';
import '../theme/srr_display_preferences_controller.dart';
import 'srr_split_action_button.dart';

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
  })
  onSave;

  @override
  State<SrrTournamentEditorCard> createState() =>
      _SrrTournamentEditorCardState();
}

class _SrrTournamentEditorCardState extends State<SrrTournamentEditorCard> {
  final TextEditingController _tournamentNameController =
      TextEditingController();
  final TextEditingController _tournamentStrengthController =
      TextEditingController();
  final TextEditingController _singlesMaxParticipantsController =
      TextEditingController();
  final TextEditingController _doublesMaxTeamsController =
      TextEditingController();
  final TextEditingController _roundTimeLimitMinutesController =
      TextEditingController();
  final TextEditingController _srrRoundsController = TextEditingController();
  final TextEditingController _tournamentVenueController =
      TextEditingController();
  final TextEditingController _tournamentDirectorController =
      TextEditingController();
  final TextEditingController _chiefRefereeFirstNameController =
      TextEditingController();
  final TextEditingController _chiefRefereeLastNameController =
      TextEditingController();

  late final List<_RefereeNameRow> _refereeRows;
  late DateTime _tournamentStartDateTime;
  late DateTime _tournamentEndDateTime;

  String _tournamentType = 'open';
  String _tournamentSubType = 'singles';
  String _tournamentCategory = 'men';
  String _tournamentSubCategory = 'senior';
  String _tournamentStatus = 'setup';

  bool _saving = false;
  String? _saveError;

  @override
  void initState() {
    super.initState();
    _refereeRows = <_RefereeNameRow>[];
    _seedFromTournament();
  }

  @override
  void dispose() {
    _tournamentNameController.dispose();
    _tournamentStrengthController.dispose();
    _singlesMaxParticipantsController.dispose();
    _doublesMaxTeamsController.dispose();
    _roundTimeLimitMinutesController.dispose();
    _srrRoundsController.dispose();
    _tournamentVenueController.dispose();
    _tournamentDirectorController.dispose();
    _chiefRefereeFirstNameController.dispose();
    _chiefRefereeLastNameController.dispose();
    for (final referee in _refereeRows) {
      referee.dispose();
    }
    super.dispose();
  }

  void _seedFromTournament() {
    final tournament = widget.tournament;
    final metadata = tournament.metadata;

    _tournamentNameController.text = tournament.name;
    _tournamentType = metadata?.type ?? 'open';
    _tournamentSubType = metadata?.subType ?? 'singles';
    _tournamentCategory = metadata?.category ?? 'men';
    _tournamentSubCategory = metadata?.subCategory ?? 'senior';
    _tournamentStatus = tournament.status;
    _tournamentStartDateTime =
        metadata?.startDateTime.toLocal() ?? DateTime.now();
    _tournamentEndDateTime =
        metadata?.endDateTime.toLocal() ??
        _tournamentStartDateTime.add(const Duration(hours: 2));

    _tournamentStrengthController.text = (metadata?.strength ?? 1.0)
        .toStringAsFixed(1);
    _singlesMaxParticipantsController.text =
        '${metadata?.singlesMaxParticipants ?? 32}';
    _doublesMaxTeamsController.text = '${metadata?.doublesMaxTeams ?? 16}';
    _roundTimeLimitMinutesController.text =
        '${metadata?.roundTimeLimitMinutes ?? 30}';
    _srrRoundsController.text = '${metadata?.srrRounds ?? 7}';
    _tournamentVenueController.text = metadata?.venueName ?? '';
    _tournamentDirectorController.text = metadata?.directorName ?? '';
    _chiefRefereeFirstNameController.text =
        metadata?.chiefReferee.firstName ?? '';
    _chiefRefereeLastNameController.text =
        metadata?.chiefReferee.lastName ?? '';

    if (metadata?.referees != null && metadata!.referees.isNotEmpty) {
      for (final referee in metadata.referees) {
        _refereeRows.add(
          _RefereeNameRow(
            firstName: referee.firstName,
            lastName: referee.lastName,
          ),
        );
      }
    }
    if (_refereeRows.isEmpty) {
      _refereeRows.add(_RefereeNameRow());
    }
  }

  void _addRefereeRow() {
    setState(() => _refereeRows.add(_RefereeNameRow()));
  }

  void _removeRefereeRow(int index) {
    if (_refereeRows.length <= 1) return;
    final removed = _refereeRows.removeAt(index);
    removed.dispose();
    setState(() {});
  }

  int _parsePositiveEven(String rawValue, String label) {
    final value = int.tryParse(rawValue.trim());
    if (value == null || value < 2 || value.isOdd) {
      throw FormatException('$label must be an even integer >= 2.');
    }
    return value;
  }

  int? _derivedNumberOfTablesPreview() {
    final singles = int.tryParse(_singlesMaxParticipantsController.text.trim());
    final doubles = int.tryParse(_doublesMaxTeamsController.text.trim());
    if (singles == null || doubles == null || singles < 2 || doubles < 2) {
      return null;
    }
    if (singles.isOdd || doubles.isOdd) return null;
    return _tournamentSubType == 'singles' ? singles ~/ 2 : doubles ~/ 2;
  }

  SrrTournamentMetadata _buildTournamentMetadata() {
    final strength = double.tryParse(_tournamentStrengthController.text.trim());
    if (strength == null || strength < 0 || strength > 1) {
      throw const FormatException(
        'Tournament strength must be a number between 0 and 1.',
      );
    }
    final singlesMaxParticipants = _parsePositiveEven(
      _singlesMaxParticipantsController.text,
      'Singles max participants',
    );
    final doublesMaxTeams = _parsePositiveEven(
      _doublesMaxTeamsController.text,
      'Doubles max teams',
    );
    final roundTimeLimitMinutes = int.tryParse(
      _roundTimeLimitMinutesController.text.trim(),
    );
    if (roundTimeLimitMinutes == null ||
        roundTimeLimitMinutes < 1 ||
        roundTimeLimitMinutes > 600) {
      throw const FormatException(
        'Tournament round timelimit must be an integer between 1 and 600 minutes.',
      );
    }
    final srrRounds = int.tryParse(_srrRoundsController.text.trim());
    if (srrRounds == null || srrRounds < 1 || srrRounds > 200) {
      throw const FormatException(
        'No. of SRR rounds must be an integer between 1 and 200.',
      );
    }

    final venueName = _tournamentVenueController.text.trim();
    if (venueName.length < 2) {
      throw const FormatException('Tournament venue name is required.');
    }

    final directorName = _tournamentDirectorController.text.trim();
    if (directorName.length < 2) {
      throw const FormatException('Tournament director name is required.');
    }

    final chiefFirstName = _chiefRefereeFirstNameController.text.trim();
    final chiefLastName = _chiefRefereeLastNameController.text.trim();
    if (chiefFirstName.isEmpty || chiefLastName.isEmpty) {
      throw const FormatException(
        'Chief referee first and last name are required.',
      );
    }

    final referees = _refereeRows
        .map((row) => row.toPersonNameOrNull())
        .whereType<SrrPersonName>()
        .toList(growable: false);
    if (referees.isEmpty) {
      throw const FormatException(
        'At least one tournament referee is required.',
      );
    }

    final numberOfTables = _tournamentSubType == 'singles'
        ? singlesMaxParticipants ~/ 2
        : doublesMaxTeams ~/ 2;
    if (!_tournamentEndDateTime.isAfter(_tournamentStartDateTime)) {
      throw const FormatException(
        'Tournament end date/time must be after start date/time.',
      );
    }

    return SrrTournamentMetadata(
      type: _tournamentType,
      subType: _tournamentSubType,
      strength: strength,
      startDateTime: _tournamentStartDateTime.toUtc(),
      endDateTime: _tournamentEndDateTime.toUtc(),
      srrRounds: srrRounds,
      singlesMaxParticipants: singlesMaxParticipants,
      doublesMaxTeams: doublesMaxTeams,
      numberOfTables: numberOfTables,
      roundTimeLimitMinutes: roundTimeLimitMinutes,
      venueName: venueName,
      directorName: directorName,
      referees: referees,
      chiefReferee: SrrPersonName(
        firstName: chiefFirstName,
        lastName: chiefLastName,
      ),
      category: _tournamentCategory,
      subCategory: _tournamentSubCategory,
    );
  }

  String _formatDateTimeLocal(DateTime value) {
    return widget.displayPreferencesController.formatDateTime(
      value,
      fallbackLocale: Localizations.localeOf(context),
    );
  }

  Future<void> _pickTournamentDateTime({required bool isStart}) async {
    if (_saving) return;
    final currentValue = isStart
        ? _tournamentStartDateTime
        : _tournamentEndDateTime;
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: currentValue,
      firstDate: DateTime(2010),
      lastDate: DateTime(2100),
    );
    if (pickedDate == null || !mounted) return;

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(currentValue),
    );
    if (pickedTime == null || !mounted) return;

    final next = DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      pickedTime.hour,
      pickedTime.minute,
    );
    setState(() {
      if (isStart) {
        _tournamentStartDateTime = next;
        if (!_tournamentEndDateTime.isAfter(next)) {
          _tournamentEndDateTime = next.add(const Duration(hours: 2));
        }
      } else {
        _tournamentEndDateTime = next;
      }
    });
  }

  Future<void> _saveTournament() async {
    if (!widget.canConfigure || _saving) return;

    setState(() {
      _saving = true;
      _saveError = null;
    });

    try {
      final metadata = _buildTournamentMetadata();
      await widget.onSave(
        tournamentId: widget.tournament.id,
        tournamentName: _tournamentNameController.text.trim(),
        status: _tournamentStatus,
        metadata: metadata,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Tournament updated.')));
    } catch (error) {
      if (!mounted) return;
      setState(() => _saveError = error.toString());
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final derivedTables = _derivedNumberOfTablesPreview();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              'Edit Tournament',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 12,
              runSpacing: 12,
              children: [
                SizedBox(
                  width: 340,
                  child: TextField(
                    controller: _tournamentNameController,
                    decoration: const InputDecoration(
                      labelText: 'Tournament name',
                    ),
                  ),
                ),
                SizedBox(
                  width: 180,
                  child: DropdownButtonFormField<String>(
                    initialValue: _tournamentStatus,
                    decoration: const InputDecoration(labelText: 'State'),
                    items: const [
                      DropdownMenuItem(value: 'setup', child: Text('Setup')),
                      DropdownMenuItem(value: 'active', child: Text('Active')),
                      DropdownMenuItem(
                        value: 'completed',
                        child: Text('Completed'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() => _tournamentStatus = value);
                    },
                  ),
                ),
                SizedBox(
                  width: 220,
                  child: DropdownButtonFormField<String>(
                    initialValue: _tournamentType,
                    decoration: const InputDecoration(
                      labelText: 'Tournament type',
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'national',
                        child: Text('National'),
                      ),
                      DropdownMenuItem(value: 'open', child: Text('Open')),
                      DropdownMenuItem(
                        value: 'regional',
                        child: Text('Regional'),
                      ),
                      DropdownMenuItem(value: 'club', child: Text('Club')),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() => _tournamentType = value);
                    },
                  ),
                ),
                SizedBox(
                  width: 180,
                  child: TextField(
                    controller: _tournamentStrengthController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Tournament strength',
                      hintText: '0.0 - 1.0',
                    ),
                  ),
                ),
                SizedBox(
                  width: 180,
                  child: DropdownButtonFormField<String>(
                    initialValue: _tournamentSubType,
                    decoration: const InputDecoration(
                      labelText: 'Tournament sub type',
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'singles',
                        child: Text('Singles'),
                      ),
                      DropdownMenuItem(
                        value: 'doubles',
                        child: Text('Doubles'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() => _tournamentSubType = value);
                    },
                  ),
                ),
                SizedBox(
                  width: 160,
                  child: DropdownButtonFormField<String>(
                    initialValue: _tournamentCategory,
                    decoration: const InputDecoration(labelText: 'Category'),
                    items: const [
                      DropdownMenuItem(value: 'men', child: Text('Men')),
                      DropdownMenuItem(value: 'women', child: Text('Women')),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() => _tournamentCategory = value);
                    },
                  ),
                ),
                SizedBox(
                  width: 180,
                  child: DropdownButtonFormField<String>(
                    initialValue: _tournamentSubCategory,
                    decoration: const InputDecoration(
                      labelText: 'Sub category',
                    ),
                    items: const [
                      DropdownMenuItem(value: 'junior', child: Text('Junior')),
                      DropdownMenuItem(value: 'senior', child: Text('Senior')),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() => _tournamentSubCategory = value);
                    },
                  ),
                ),
                SizedBox(
                  width: 220,
                  child: TextField(
                    controller: _singlesMaxParticipantsController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Singles max participants',
                      hintText: 'Even number',
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                SizedBox(
                  width: 220,
                  child: TextField(
                    controller: _doublesMaxTeamsController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Doubles max teams',
                      hintText: 'Even number',
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                SizedBox(
                  width: 220,
                  child: TextField(
                    controller: _roundTimeLimitMinutesController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Round timelimit (minutes)',
                      hintText: '1 - 600',
                    ),
                  ),
                ),
                SizedBox(
                  width: 220,
                  child: TextField(
                    controller: _srrRoundsController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'No. of SRR rounds',
                      hintText: '1 - 200',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              derivedTables == null
                  ? 'Tournament no. of tables: enter valid even limits'
                  : 'Tournament no. of tables (${_tournamentSubType == 'singles' ? 'singles max participants / 2' : 'doubles max teams / 2'}): $derivedTables',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 12,
              runSpacing: 12,
              children: [
                SizedBox(
                  width: 320,
                  child: TextField(
                    controller: _tournamentVenueController,
                    decoration: const InputDecoration(
                      labelText: 'Tournament venue name',
                    ),
                  ),
                ),
                SizedBox(
                  width: 320,
                  child: TextField(
                    controller: _tournamentDirectorController,
                    decoration: const InputDecoration(
                      labelText: 'Tournament director name',
                    ),
                  ),
                ),
                SizedBox(
                  width: 320,
                  child: SrrSplitActionButton(
                    label:
                        'Start: ${_formatDateTimeLocal(_tournamentStartDateTime)}',
                    variant: SrrSplitActionButtonVariant.outlined,
                    leadingIcon: Icons.event,
                    maxLines: 2,
                    onPressed: _saving
                        ? null
                        : () => _pickTournamentDateTime(isStart: true),
                  ),
                ),
                SizedBox(
                  width: 320,
                  child: SrrSplitActionButton(
                    label:
                        'End: ${_formatDateTimeLocal(_tournamentEndDateTime)}',
                    variant: SrrSplitActionButtonVariant.outlined,
                    leadingIcon: Icons.event_available,
                    maxLines: 2,
                    onPressed: _saving
                        ? null
                        : () => _pickTournamentDateTime(isStart: false),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Chief Referee',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 12,
              runSpacing: 12,
              children: [
                SizedBox(
                  width: 220,
                  child: TextField(
                    controller: _chiefRefereeFirstNameController,
                    decoration: const InputDecoration(
                      labelText: 'Chief referee first name',
                    ),
                  ),
                ),
                SizedBox(
                  width: 220,
                  child: TextField(
                    controller: _chiefRefereeLastNameController,
                    decoration: const InputDecoration(
                      labelText: 'Chief referee last name',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                Text(
                  'Tournament Referees',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                SizedBox(
                  width: 220,
                  child: SrrSplitActionButton(
                    label: 'Add Referee',
                    variant: SrrSplitActionButtonVariant.outlined,
                    leadingIcon: Icons.add,
                    onPressed: _saving ? null : _addRefereeRow,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ..._refereeRows.asMap().entries.map(
              (entry) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 12,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    SizedBox(
                      width: 220,
                      child: TextField(
                        controller: entry.value.firstNameController,
                        decoration: InputDecoration(
                          labelText: 'Referee ${entry.key + 1} first name',
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 220,
                      child: TextField(
                        controller: entry.value.lastNameController,
                        decoration: InputDecoration(
                          labelText: 'Referee ${entry.key + 1} last name',
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Remove referee',
                      onPressed: _saving
                          ? null
                          : () => _removeRefereeRow(entry.key),
                      icon: const Icon(Icons.remove_circle_outline),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: 260,
              child: SrrSplitActionButton(
                label: _saving ? 'Saving...' : 'Save Tournament',
                variant: SrrSplitActionButtonVariant.filled,
                leadingIcon: Icons.save,
                onPressed: widget.canConfigure && !_saving
                    ? _saveTournament
                    : null,
              ),
            ),
            if (!widget.canConfigure) ...[
              const SizedBox(height: 8),
              const Text(
                'Tournament editing is restricted to admin accounts.',
                textAlign: TextAlign.center,
              ),
            ],
            if (_saveError != null) ...[
              const SizedBox(height: 8),
              _InlineError(message: _saveError!),
            ],
          ],
        ),
      ),
    );
  }
}

class _RefereeNameRow {
  _RefereeNameRow({String? firstName, String? lastName})
    : firstNameController = TextEditingController(text: firstName ?? ''),
      lastNameController = TextEditingController(text: lastName ?? '');

  final TextEditingController firstNameController;
  final TextEditingController lastNameController;

  void dispose() {
    firstNameController.dispose();
    lastNameController.dispose();
  }

  SrrPersonName? toPersonNameOrNull() {
    final firstName = firstNameController.text.trim();
    final lastName = lastNameController.text.trim();
    if (firstName.isEmpty && lastName.isEmpty) return null;
    if (firstName.isEmpty || lastName.isEmpty) {
      throw const FormatException(
        'Each referee row must include both first and last name.',
      );
    }
    return SrrPersonName(firstName: firstName, lastName: lastName);
  }
}

class _InlineError extends StatelessWidget {
  const _InlineError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: TextStyle(color: theme.colorScheme.onErrorContainer),
      ),
    );
  }
}
