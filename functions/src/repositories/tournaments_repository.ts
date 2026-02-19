/* ---------------------------------------------------------------------------
 * functions/src/repositories/tournaments_repository.ts
 * ---------------------------------------------------------------------------
 *
 * Purpose:
 * - Implements persistence operations for tournament records and workflow state.
 * Architecture:
 * - Repository module encapsulating Firestore reads/writes for tournament entities.
 * - Provides typed storage operations consumed by route orchestration logic.
 * Author: Neil Khatu
 * Copyright (c) The Khatu Family Trust
 */
import {Firestore} from 'firebase-admin/firestore';

import {
  PersonNameModel,
  TournamentCategory,
  TournamentMetadataModel,
  TournamentModel,
  TournamentWorkflowModel,
  TournamentWorkflowStepKey,
  TournamentWorkflowStepModel,
  TournamentWorkflowStepStatus,
  TournamentSubCategory,
  TournamentSubType,
  TournamentType,
} from '../models/domain_models';
import {CounterRepository} from './counter_repository';

const TOURNAMENTS_COLLECTION = 'tournaments';
const TOURNAMENT_WORKFLOW_STEP_KEYS: TournamentWorkflowStepKey[] = [
  'create_tournament',
  'load_registered_players',
  'load_current_national_ranking',
  'create_tournament_seeding',
  'create_tournament_groups',
  'generate_matchups_next_round',
  'create_final_srr_standings',
  'generate_knockout_brackets',
  'generate_final_tournament_standings',
  'announce_winners',
];

interface ParsedTournamentDocument {
  model: TournamentModel;
  needsWorkflowBackfill: boolean;
}

function asInt(value: unknown): number {
  if (typeof value === 'number' && Number.isFinite(value)) {
    return Math.trunc(value);
  }
  if (typeof value === 'string' && value.trim().length > 0) {
    const parsed = Number(value);
    if (Number.isFinite(parsed)) return Math.trunc(parsed);
  }
  return 0;
}

function asText(value: unknown): string {
  return typeof value === 'string' ? value : '';
}

function asNumber(value: unknown, fallback: number): number {
  if (typeof value === 'number' && Number.isFinite(value)) {
    return value;
  }
  if (typeof value === 'string' && value.trim().length > 0) {
    const parsed = Number(value);
    if (Number.isFinite(parsed)) return parsed;
  }
  return fallback;
}

function asIsoDateTime(value: unknown, fallback: string): string {
  const raw = asText(value).trim();
  if (!raw) return fallback;
  const parsed = Date.parse(raw);
  if (Number.isNaN(parsed)) return fallback;
  return new Date(parsed).toISOString();
}

function asEnum<T extends string>(
  value: unknown,
  allowed: readonly T[],
): T | null {
  const normalized = asText(value).trim().toLowerCase();
  if (!normalized) return null;
  return allowed.includes(normalized as T) ? (normalized as T) : null;
}

function normalizeWorkflowStepKey(value: unknown): TournamentWorkflowStepKey | null {
  const normalized = asText(value).trim().toLowerCase();
  return TOURNAMENT_WORKFLOW_STEP_KEYS.includes(
    normalized as TournamentWorkflowStepKey,
  )
    ? (normalized as TournamentWorkflowStepKey)
    : null;
}

function normalizeWorkflowStepStatus(
  value: unknown,
): TournamentWorkflowStepStatus | null {
  const normalized = asText(value).trim().toLowerCase();
  if (normalized === 'completed') return 'completed';
  if (normalized === 'pending') return 'pending';
  return null;
}

function toPersonName(value: unknown): PersonNameModel | null {
  if (value == null || typeof value !== 'object') return null;
  const payload = value as Record<string, unknown>;
  const firstName = asText(
    payload.first_name ?? payload.firstName ?? payload.fname,
  ).trim();
  const lastName = asText(
    payload.last_name ?? payload.lastName ?? payload.lname,
  ).trim();
  if (!firstName || !lastName) return null;
  return {firstName, lastName};
}

function toTournamentMetadata(value: unknown): TournamentMetadataModel | null {
  if (value == null || typeof value !== 'object') return null;
  const payload = value as Record<string, unknown>;
  const fallbackStart = new Date().toISOString();
  const fallbackEnd = new Date(
    Date.parse(fallbackStart) + 2 * 60 * 60 * 1000,
  ).toISOString();
  const normalizedType = asText(payload.type).trim().toLowerCase();
  const normalizedFlag = asText(payload.flag).trim().toLowerCase();
  const typeRaw =
    normalizedType === 'reginaol'
      ? 'regional'
      : normalizedFlag === 'reginaol'
      ? 'regional'
      : null;

  const type =
    asEnum<TournamentType>(typeRaw ?? payload.type, [
      'national',
      'open',
      'regional',
      'club',
    ]) ??
    asEnum<TournamentType>(typeRaw ?? payload.flag, [
      'national',
      'open',
      'regional',
      'club',
    ]);
  const subType =
    asEnum<TournamentSubType>(
      payload.sub_type ?? payload.subType ?? payload.tournament_sub_type,
      ['singles', 'doubles'],
    ) ??
    asEnum<TournamentSubType>(payload.type, ['singles', 'doubles']);
  const category = asEnum<TournamentCategory>(payload.category, ['men', 'women']);
  const subCategory = asEnum<TournamentSubCategory>(
    payload.sub_category ?? payload.subCategory,
    ['junior', 'senior'],
  );
  const chiefReferee = toPersonName(
    payload.chief_referee ?? payload.chiefReferee,
  );

  const refereesRaw = payload.referees;
  const referees = Array.isArray(refereesRaw)
    ? refereesRaw
        .map((entry) => toPersonName(entry))
        .filter((entry): entry is PersonNameModel => entry !== null)
    : [];

  if (
    type == null ||
    subType == null ||
    category == null ||
    subCategory == null ||
    chiefReferee == null
  ) {
    return null;
  }

  const venueName = asText(payload.venue_name ?? payload.venueName).trim();
  const directorName = asText(
    payload.director_name ?? payload.directorName,
  ).trim();
  if (!venueName || !directorName) return null;

  const strength = asNumber(payload.strength, 1);
  const startDateTime = asIsoDateTime(
    payload.start_date_time ?? payload.startDateTime,
    fallbackStart,
  );
  const endDateTime = asIsoDateTime(
    payload.end_date_time ?? payload.endDateTime,
    fallbackEnd,
  );
  const srrRoundsRaw =
    payload.srr_rounds ??
    payload.srrRounds ??
    payload.tournament_srr_rounds;
  const srrRounds = srrRoundsRaw == null ? 7 : asInt(srrRoundsRaw);
  const numberOfGroupsRaw =
    payload.number_of_groups ??
    payload.numberOfGroups ??
    payload.tournament_number_of_groups;
  const numberOfGroups = numberOfGroupsRaw == null
    ? 4
    : asInt(numberOfGroupsRaw);
  const singlesMaxParticipants = asInt(
    payload.singles_max_participants ?? payload.singlesMaxParticipants,
  );
  const doublesMaxTeams = asInt(payload.doubles_max_teams ?? payload.doublesMaxTeams);
  const numberOfTables = asInt(payload.number_of_tables ?? payload.numberOfTables);
  const roundTimeLimitMinutes = asInt(
    payload.round_time_limit_minutes ?? payload.roundTimeLimitMinutes,
  );
  if (
    singlesMaxParticipants < 2 ||
    doublesMaxTeams < 2 ||
    srrRounds < 1 ||
    numberOfGroups < 2 ||
    numberOfTables < 1 ||
    roundTimeLimitMinutes < 1
  ) {
    return null;
  }

  return {
    type,
    subType,
    strength,
    startDateTime,
    endDateTime,
    srrRounds,
    numberOfGroups,
    singlesMaxParticipants,
    doublesMaxTeams,
    numberOfTables,
    roundTimeLimitMinutes,
    venueName,
    directorName,
    referees,
    chiefReferee,
    category,
    subCategory,
  };
}

function toFirestorePersonName(name: PersonNameModel): Record<string, string> {
  return {
    first_name: name.firstName,
    last_name: name.lastName,
  };
}

function toFirestoreTournamentMetadata(
  metadata: TournamentMetadataModel,
): Record<string, unknown> {
  return {
    type: metadata.type,
    sub_type: metadata.subType,
    strength: metadata.strength,
    start_date_time: metadata.startDateTime,
    end_date_time: metadata.endDateTime,
    srr_rounds: metadata.srrRounds,
    number_of_groups: metadata.numberOfGroups,
    singles_max_participants: metadata.singlesMaxParticipants,
    doubles_max_teams: metadata.doublesMaxTeams,
    number_of_tables: metadata.numberOfTables,
    round_time_limit_minutes: metadata.roundTimeLimitMinutes,
    venue_name: metadata.venueName,
    director_name: metadata.directorName,
    referees: metadata.referees.map((entry) => toFirestorePersonName(entry)),
    chief_referee: toFirestorePersonName(metadata.chiefReferee),
    category: metadata.category,
    sub_category: metadata.subCategory,
  };
}

function defaultCompletedKeysForStatus(
  status: TournamentModel['status'],
): Set<TournamentWorkflowStepKey> {
  switch (status) {
    case 'completed':
      return new Set<TournamentWorkflowStepKey>(TOURNAMENT_WORKFLOW_STEP_KEYS);
    case 'active':
      return new Set<TournamentWorkflowStepKey>([
        'create_tournament',
        'load_registered_players',
        'load_current_national_ranking',
        'create_tournament_seeding',
        'create_tournament_groups',
        'generate_matchups_next_round',
      ]);
    case 'setup':
    default:
      return new Set<TournamentWorkflowStepKey>(['create_tournament']);
  }
}

function defaultTournamentWorkflow(
  status: TournamentModel['status'],
  now: string,
): TournamentWorkflowModel {
  const completedKeys = defaultCompletedKeysForStatus(status);
  const steps: TournamentWorkflowStepModel[] = TOURNAMENT_WORKFLOW_STEP_KEYS.map((key) => {
    const completed = completedKeys.has(key);
    return {
      key,
      status: completed ? ('completed' as const) : ('pending' as const),
      completedAt: completed ? now : null,
    };
  });

  return {
    steps,
    updatedAt: now,
  };
}

function normalizeWorkflow(
  value: unknown,
  params: {status: TournamentModel['status']; now: string},
): {workflow: TournamentWorkflowModel; needsBackfill: boolean} {
  const fallback = defaultTournamentWorkflow(params.status, params.now);
  if (value == null || typeof value !== 'object') {
    return {workflow: fallback, needsBackfill: true};
  }

  const payload = value as Record<string, unknown>;
  const stepsRaw = Array.isArray(payload.steps) ? payload.steps : [];
  const stepsByKey = new Map<TournamentWorkflowStepKey, TournamentWorkflowStepModel>();
  let needsBackfill = !Array.isArray(payload.steps);

  for (const entry of stepsRaw) {
    if (entry == null || typeof entry !== 'object') {
      needsBackfill = true;
      continue;
    }
    const item = entry as Record<string, unknown>;
    const key = normalizeWorkflowStepKey(item.key);
    const status = normalizeWorkflowStepStatus(item.status);
    if (key == null || status == null) {
      needsBackfill = true;
      continue;
    }
    const completedAt = asText(
      item.completed_at ?? item.completedAt,
    ).trim();
    stepsByKey.set(key, {
      key,
      status,
      completedAt: status === 'completed' ? (completedAt || params.now) : null,
    });
  }

  const normalizedSteps: TournamentWorkflowStepModel[] =
    TOURNAMENT_WORKFLOW_STEP_KEYS.map((key) => {
      const existing = stepsByKey.get(key);
      if (existing) return existing;
      needsBackfill = true;
      const fallbackStep = fallback.steps.find((entry) => entry.key === key);
      return (
        fallbackStep ?? {
          key,
          status: 'pending' as const,
          completedAt: null,
        }
      );
    });
  const updatedAt = asText(payload.updated_at ?? payload.updatedAt).trim();
  if (!updatedAt) needsBackfill = true;

  return {
    workflow: {
      steps: normalizedSteps,
      updatedAt: updatedAt || params.now,
    },
    needsBackfill,
  };
}

function withWorkflowProgressForStatus(
  workflow: TournamentWorkflowModel,
  status: TournamentModel['status'],
  now: string,
): TournamentWorkflowModel {
  const completedKeys = defaultCompletedKeysForStatus(status);
  let changed = false;
  const steps: TournamentWorkflowStepModel[] = workflow.steps.map((step) => {
    if (!completedKeys.has(step.key) || step.status === 'completed') {
      return step;
    }
    changed = true;
    return {
      key: step.key,
      status: 'completed' as const,
      completedAt: now,
    };
  });

  if (!changed) {
    return workflow;
  }
  return {
    steps,
    updatedAt: now,
  };
}

function toFirestoreWorkflow(
  workflow: TournamentWorkflowModel,
): Record<string, unknown> {
  return {
    steps: workflow.steps.map((step) => ({
      key: step.key,
      status: step.status,
      completed_at: step.completedAt,
    })),
    updated_at: workflow.updatedAt,
  };
}

function toFirestoreTournament(
  tournament: TournamentModel,
): Record<string, unknown> {
  return {
    id: tournament.id,
    name: tournament.name,
    status: tournament.status,
    metadata: tournament.metadata
      ? toFirestoreTournamentMetadata(tournament.metadata)
      : null,
    selected_ranking_year: tournament.selectedRankingYear,
    selected_ranking_description: tournament.selectedRankingDescription,
    workflow: toFirestoreWorkflow(tournament.workflow),
    created_at: tournament.createdAt,
    updated_at: tournament.updatedAt,
  };
}

function fromDoc(
  snapshot: FirebaseFirestore.DocumentSnapshot,
): ParsedTournamentDocument | null {
  if (!snapshot.exists) return null;
  const data = snapshot.data() ?? {};
  const statusRaw = asText(data.status);
  const status: TournamentModel['status'] =
    statusRaw === 'active' || statusRaw === 'completed' ? statusRaw : 'setup';
  const createdAt = asText(data.created_at);
  const updatedAt = asText(data.updated_at);
  const nowForWorkflow = updatedAt || createdAt || new Date().toISOString();
  const workflow = normalizeWorkflow(data.workflow, {
    status,
    now: nowForWorkflow,
  });

  return {
    model: {
      id: asInt(data.id) || asInt(snapshot.id),
      name: asText(data.name),
      status,
      metadata: toTournamentMetadata(data.metadata),
      selectedRankingYear: (() => {
        const value = asInt(data.selected_ranking_year);
        return value > 0 ? value : null;
      })(),
      selectedRankingDescription: (() => {
        const value = asText(data.selected_ranking_description).trim();
        return value.length > 0 ? value : null;
      })(),
      workflow: workflow.workflow,
      createdAt,
      updatedAt,
    },
    needsWorkflowBackfill: workflow.needsBackfill,
  };
}

export class TournamentsRepository {
  constructor(
    private readonly db: Firestore,
    private readonly counters: CounterRepository,
  ) {}

  async create(params: {
    name: string;
    status: TournamentModel['status'];
    metadata?: TournamentMetadataModel | null;
    selectedRankingYear?: number | null;
    selectedRankingDescription?: string | null;
    workflow?: TournamentWorkflowModel | null;
    now: string;
  }): Promise<TournamentModel> {
    const id = await this.counters.next('next_tournament_id');
    const workflow = withWorkflowProgressForStatus(
      params.workflow ?? defaultTournamentWorkflow(params.status, params.now),
      params.status,
      params.now,
    );
    const tournament: TournamentModel = {
      id,
      name: params.name.trim(),
      status: params.status,
      metadata: params.metadata ?? null,
      selectedRankingYear:
        params.selectedRankingYear == null
          ? null
          : Math.trunc(params.selectedRankingYear),
      selectedRankingDescription:
        params.selectedRankingDescription?.trim() || null,
      workflow,
      createdAt: params.now,
      updatedAt: params.now,
    };
    await this.db
      .collection(TOURNAMENTS_COLLECTION)
      .doc(String(tournament.id))
      .set(toFirestoreTournament(tournament));
    return tournament;
  }

  async ensureDefault(name: string, now: string): Promise<TournamentModel> {
    const existing = await this.list();
    const active = existing.find((item) => item.status === 'active');
    if (active) return active;
    if (existing.length > 0) {
      return existing[0];
    }
    return this.create({name, status: 'active', now});
  }

  async findById(tournamentId: number): Promise<TournamentModel | null> {
    const ref = this.db
      .collection(TOURNAMENTS_COLLECTION)
      .doc(String(tournamentId));
    const parsed = fromDoc(await ref.get());
    if (parsed == null) return null;
    if (parsed.needsWorkflowBackfill) {
      await ref.set(
        {
          workflow: toFirestoreWorkflow(parsed.model.workflow),
          updated_at: parsed.model.updatedAt || parsed.model.workflow.updatedAt,
        },
        {merge: true},
      );
    }
    return parsed.model;
  }

  async list(): Promise<TournamentModel[]> {
    const snapshot = await this.db.collection(TOURNAMENTS_COLLECTION).get();
    const parsed = snapshot.docs
      .map((doc) => ({doc, parsed: fromDoc(doc)}))
      .filter(
        (entry): entry is {
          doc: FirebaseFirestore.QueryDocumentSnapshot;
          parsed: ParsedTournamentDocument;
        } => entry.parsed !== null,
      );

    const backfills = parsed
      .filter((entry) => entry.parsed.needsWorkflowBackfill)
      .map((entry) =>
        entry.doc.ref.set(
          {
            workflow: toFirestoreWorkflow(entry.parsed.model.workflow),
            updated_at:
              entry.parsed.model.updatedAt ||
              entry.parsed.model.workflow.updatedAt,
          },
          {merge: true},
        ),
      );
    if (backfills.length > 0) {
      await Promise.all(backfills);
    }

    return parsed
      .map((entry) => entry.parsed.model)
      .sort((a, b) => a.id - b.id);
  }

  async update(params: {
    tournamentId: number;
    name: string;
    status: TournamentModel['status'];
    metadata?: TournamentMetadataModel | null;
    selectedRankingYear?: number | null;
    selectedRankingDescription?: string | null;
    workflow?: TournamentWorkflowModel | null;
    now: string;
  }): Promise<TournamentModel | null> {
    const ref = this.db
      .collection(TOURNAMENTS_COLLECTION)
      .doc(String(params.tournamentId));
    const existing = fromDoc(await ref.get());
    if (!existing) return null;

    const workflow = withWorkflowProgressForStatus(
      params.workflow ?? existing.model.workflow,
      params.status,
      params.now,
    );
    const updated: TournamentModel = {
      id: existing.model.id,
      name: params.name.trim(),
      status: params.status,
      metadata: params.metadata ?? null,
      selectedRankingYear:
        params.selectedRankingYear === undefined
          ? existing.model.selectedRankingYear
          : params.selectedRankingYear == null
          ? null
          : Math.trunc(params.selectedRankingYear),
      selectedRankingDescription:
        params.selectedRankingDescription === undefined
          ? existing.model.selectedRankingDescription
          : params.selectedRankingDescription?.trim() || null,
      workflow,
      createdAt: existing.model.createdAt || params.now,
      updatedAt: params.now,
    };

    await ref.set(toFirestoreTournament(updated), {merge: true});
    return updated;
  }

  async updateWorkflowStepStatus(params: {
    tournamentId: number;
    stepKey: TournamentWorkflowStepKey;
    status: TournamentWorkflowStepStatus;
    now: string;
  }): Promise<TournamentModel | null> {
    const ref = this.db
      .collection(TOURNAMENTS_COLLECTION)
      .doc(String(params.tournamentId));
    const existing = fromDoc(await ref.get());
    if (!existing) return null;

    const steps = existing.model.workflow.steps.map((step) => {
      if (step.key !== params.stepKey) return step;
      if (params.status === 'completed') {
        return {
          key: step.key,
          status: 'completed' as const,
          completedAt: step.completedAt ?? params.now,
        };
      }
      return {
        key: step.key,
        status: 'pending' as const,
        completedAt: null,
      };
    });
    const workflow: TournamentWorkflowModel = {
      steps,
      updatedAt: params.now,
    };
    const updated: TournamentModel = {
      ...existing.model,
      workflow,
      updatedAt: params.now,
    };

    await ref.set(toFirestoreTournament(updated), {merge: true});
    return updated;
  }

  async selectNationalRankingYear(params: {
    tournamentId: number;
    rankingYear: number;
    rankingDescription: string;
    now: string;
  }): Promise<TournamentModel | null> {
    const ref = this.db
      .collection(TOURNAMENTS_COLLECTION)
      .doc(String(params.tournamentId));
    const existing = fromDoc(await ref.get());
    if (!existing) return null;

    const steps = existing.model.workflow.steps.map((step) => {
      if (step.key === 'load_current_national_ranking') {
        return {
          key: step.key,
          status: 'completed' as const,
          completedAt: step.completedAt ?? params.now,
        };
      }
      if (step.key === 'create_tournament_seeding') {
        return {
          key: step.key,
          status: 'pending' as const,
          completedAt: null,
        };
      }
      return {
        key: step.key,
        status: step.status,
        completedAt: step.completedAt,
      };
    });
    const workflow: TournamentWorkflowModel = {
      steps,
      updatedAt: params.now,
    };
    const updated: TournamentModel = {
      ...existing.model,
      selectedRankingYear: Math.trunc(params.rankingYear),
      selectedRankingDescription: params.rankingDescription.trim() || null,
      workflow,
      updatedAt: params.now,
    };

    await ref.set(toFirestoreTournament(updated), {merge: true});
    return updated;
  }

  async delete(tournamentId: number): Promise<boolean> {
    const ref = this.db.collection(TOURNAMENTS_COLLECTION).doc(String(tournamentId));
    const snapshot = await ref.get();
    if (!snapshot.exists) return false;
    await ref.delete();
    return true;
  }
}
