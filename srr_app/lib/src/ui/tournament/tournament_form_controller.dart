// ---------------------------------------------------------------------------
// srr_app/lib/src/ui/tournament/tournament_form_controller.dart
// ---------------------------------------------------------------------------
//
// Purpose:
// - Encapsulates form state for the tournament editor so the view stays declarative.
// Architecture:
// - Holds text controllers, dropdown state, derived fields, and save/addReferee helpers.
// - Notifies listeners when the saving state or referees list changes, enabling reuse by other forms.
// Author: Neil Khatu
// Copyright (c) The Khatu Family Trust
//
import 'package:flutter/material.dart';

import '../../models/srr_models.dart';

class TournamentFormController extends ChangeNotifier {
  TournamentFormController({required SrrTournamentRecord tournament})
    : _tournament = tournament {
    _seedFromTournament();
  }

  static const statusOptions = ['setup', 'active', 'completed'];
  static const typeOptions = ['open', 'national', 'regional', 'club'];
  static const subTypeOptions = ['singles', 'doubles'];
  static const categoryOptions = ['men', 'women'];
  static const subCategoryOptions = ['junior', 'senior'];

  final SrrTournamentRecord _tournament;
  final TextEditingController tournamentNameController = TextEditingController();
  final TextEditingController tournamentStrengthController = TextEditingController();
  final TextEditingController singlesMaxParticipantsController = TextEditingController();
  final TextEditingController doublesMaxTeamsController = TextEditingController();
  final TextEditingController roundTimeLimitMinutesController = TextEditingController();
  final TextEditingController srrRoundsController = TextEditingController();
  final TextEditingController numberOfGroupsController = TextEditingController();
  final TextEditingController venueController = TextEditingController();
  final TextEditingController directorController = TextEditingController();
  final TextEditingController chiefRefereeFirstNameController = TextEditingController();
  final TextEditingController chiefRefereeLastNameController = TextEditingController();

  late final List<_RefereeNameRow> refereeRows = <_RefereeNameRow>[];
  late DateTime startDateTime;
  late DateTime endDateTime;

  String tournamentStatus = 'setup';
  String tournamentType = 'open';
  String tournamentSubType = 'singles';
  String tournamentCategory = 'men';
  String tournamentSubCategory = 'senior';

  bool _saving = false;
  bool get isSaving => _saving;

  String? _error;
  String? get error => _error;

  Future<void> save({
    required Future<void> Function({
      required int tournamentId,
      required String tournamentName,
      required String status,
      required SrrTournamentMetadata metadata,
    }) onSave,
  }) async {
    _error = null;
    _setSaving(true);
    try {
      final metadata = _snapshotMetadata();
      await onSave(
        tournamentId: _tournament.id,
        tournamentName: tournamentNameController.text.trim(),
        status: tournamentStatus,
        metadata: metadata,
      );
    } catch (error) {
      _error = error.toString();
    } finally {
      _setSaving(false);
    }
  }

  void addReferee() {
    refereeRows.add(_RefereeNameRow());
    notifyListeners();
  }

  void removeReferee(int index) {
    if (index < 0 || index >= refereeRows.length || refereeRows.length <= 1) return;
    refereeRows.removeAt(index).dispose();
    notifyListeners();
  }

  void updateStatus(String value) {
    tournamentStatus = value;
    notifyListeners();
  }

  void updateType(String value) {
    tournamentType = value;
    notifyListeners();
  }

  void updateSubType(String value) {
    tournamentSubType = value;
    notifyListeners();
  }

  void updateCategory(String value) {
    tournamentCategory = value;
    notifyListeners();
  }

  void updateSubCategory(String value) {
    tournamentSubCategory = value;
    notifyListeners();
  }

  int? get derivedTables {
    final singles = int.tryParse(singlesMaxParticipantsController.text.trim());
    final doubles = int.tryParse(doublesMaxTeamsController.text.trim());
    if (singles == null || doubles == null) return null;
    if (singles < 2 || doubles < 2) return null;
    if (singles.isOdd || doubles.isOdd) return null;
    return tournamentSubType == 'singles' ? singles ~/ 2 : doubles ~/ 2;
  }

  List<SrrPersonName> get referees {
    final list = <SrrPersonName>[];
    for (final entry in refereeRows) {
      final person = entry.toPersonNameOrNull();
      if (person != null) list.add(person);
    }
    return list;
  }

  SrrTournamentMetadata _buildTournamentMetadata() {
    final strength = double.tryParse(tournamentStrengthController.text.trim());
    final parsedStrength = strength == null ? 1.0 : strength.clamp(0.0, 1.0);
    final singles = _parsePositiveEven(singlesMaxParticipantsController.text, 'Singles max participants');
    final doubles = _parsePositiveEven(doublesMaxTeamsController.text, 'Doubles max teams');
    final roundLimit = int.tryParse(roundTimeLimitMinutesController.text.trim()) ?? 30;
    final srrRounds = int.tryParse(srrRoundsController.text.trim()) ?? 7;
    final groups = int.tryParse(numberOfGroupsController.text.trim()) ?? 4;

    return SrrTournamentMetadata(
      type: tournamentType,
      subType: tournamentSubType,
      strength: parsedStrength,
      startDateTime: startDateTime.toUtc(),
      endDateTime: endDateTime.toUtc(),
      srrRounds: srrRounds,
      numberOfGroups: groups,
      singlesMaxParticipants: singles,
      doublesMaxTeams: doubles,
      numberOfTables: derivedTables ?? (tournamentSubType == 'singles' ? singles ~/ 2 : doubles ~/ 2),
      roundTimeLimitMinutes: roundLimit,
      venueName: venueController.text.trim(),
      directorName: directorController.text.trim(),
      referees: [
        ...referees,
      ],
      chiefReferee: SrrPersonName(
        firstName: chiefRefereeFirstNameController.text.trim(),
        lastName: chiefRefereeLastNameController.text.trim(),
      ),
      category: tournamentCategory,
      subCategory: tournamentSubCategory,
    );
  }

  SrrTournamentMetadata _snapshotMetadata() => _buildTournamentMetadata();

  void _seedFromTournament() {
    final metadata = _tournament.metadata;
    tournamentNameController.text = _tournament.name;
    tournamentStatus = _tournament.status;
    tournamentType = metadata?.type ?? tournamentType;
    tournamentSubType = metadata?.subType ?? tournamentSubType;
    tournamentCategory = metadata?.category ?? tournamentCategory;
    tournamentSubCategory = metadata?.subCategory ?? tournamentSubCategory;
    tournamentStrengthController.text = (metadata?.strength ?? 1.0).toStringAsFixed(1);
    singlesMaxParticipantsController.text = '${metadata?.singlesMaxParticipants ?? 32}';
    doublesMaxTeamsController.text = '${metadata?.doublesMaxTeams ?? 16}';
    roundTimeLimitMinutesController.text = '${metadata?.roundTimeLimitMinutes ?? 30}';
    srrRoundsController.text = '${metadata?.srrRounds ?? 7}';
    numberOfGroupsController.text = '${metadata?.numberOfGroups ?? 4}';
    venueController.text = metadata?.venueName ?? '';
    directorController.text = metadata?.directorName ?? '';
    chiefRefereeFirstNameController.text = metadata?.chiefReferee.firstName ?? '';
    chiefRefereeLastNameController.text = metadata?.chiefReferee.lastName ?? '';
    startDateTime = metadata?.startDateTime.toLocal() ?? DateTime.now();
    endDateTime = metadata?.endDateTime.toLocal() ?? startDateTime.add(const Duration(hours: 2));
    refereeRows.clear();
    if (metadata?.referees != null && metadata!.referees.isNotEmpty) {
      for (final referee in metadata.referees) {
        refereeRows.add(_RefereeNameRow(
          firstName: referee.firstName,
          lastName: referee.lastName,
        ));
      }
    }
    if (refereeRows.isEmpty) {
      refereeRows.add(_RefereeNameRow());
    }
  }

  void _setSaving(bool value) {
    _saving = value;
    notifyListeners();
  }

  int _parsePositiveEven(String rawValue, String label) {
    final value = int.tryParse(rawValue.trim()) ?? 0;
    if (value < 2 || value.isOdd) {
      throw FormatException('$label must be an even integer >= 2.');
    }
    return value;
  }

  @override
  void dispose() {
    tournamentNameController.dispose();
    tournamentStrengthController.dispose();
    singlesMaxParticipantsController.dispose();
    doublesMaxTeamsController.dispose();
    roundTimeLimitMinutesController.dispose();
    srrRoundsController.dispose();
    numberOfGroupsController.dispose();
    venueController.dispose();
    directorController.dispose();
    chiefRefereeFirstNameController.dispose();
    chiefRefereeLastNameController.dispose();
    for (final referee in refereeRows) {
      referee.dispose();
    }
    super.dispose();
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
      throw const FormatException('Each referee row must include both first and last name.');
    }
    return SrrPersonName(firstName: firstName, lastName: lastName);
  }
}

