/* ---------------------------------------------------------------------------
 * functions/src/index.ts
 * ---------------------------------------------------------------------------
 *
 * Purpose:
 * - Defines Cloud Functions HTTP routes and orchestrates tournament domain workflows.
 * Architecture:
 * - Composition root that wires auth guards, validation, repositories, and response DTOs.
 * - Keeps persistence and domain logic behind repository/service boundaries.
 * Author: Neil Khatu
 * Copyright (c) The Khatu Family Trust
 */
import crypto from 'crypto';
import cors from 'cors';
import express, {NextFunction, Request, Response} from 'express';
import {initializeApp} from 'firebase-admin/app';
import {DecodedIdToken, getAuth} from 'firebase-admin/auth';
import {getFirestore} from 'firebase-admin/firestore';
import {setGlobalOptions} from 'firebase-functions/v2';
import {onRequest} from 'firebase-functions/v2/https';

import {
  NationalRankingModel,
  PlayerModel,
  PersonNameModel,
  TournamentGroupModel,
  TournamentGroupingMethod,
  TournamentSeedingMatchedBy,
  TournamentSeedingModel,
  TournamentSeedingSourceType,
  TournamentCategory,
  TournamentMetadataModel,
  TournamentModel,
  TournamentWorkflowStepKey,
  TournamentWorkflowStepStatus,
  TournamentSubType,
  TournamentSubCategory,
  TournamentType,
  UserModel,
} from './models/domain_models';
import {
  CounterRepository,
  NationalRankingsRepository,
  PlayersRepository,
  RoundsRepository,
  ScoresRepository,
  TournamentGroupUpsertInput,
  TournamentGroupsRepository,
  TournamentSeedingUpsertInput,
  TournamentSeedingsRepository,
  TournamentsRepository,
  UsersRepository,
} from './repositories';
import {runtimeConfig} from './config/runtime_config';

initializeApp();
const db = getFirestore();
const counterRepository = new CounterRepository(db);
const usersRepository = new UsersRepository(db);
const playersRepository = new PlayersRepository(db);
const nationalRankingsRepository = new NationalRankingsRepository(db);
const tournamentSeedingsRepository = new TournamentSeedingsRepository(db);
const tournamentGroupsRepository = new TournamentGroupsRepository(db);
const tournamentsRepository = new TournamentsRepository(db, counterRepository);
const roundsRepository = new RoundsRepository(db, counterRepository);
const scoresRepository = new ScoresRepository(db);

setGlobalOptions({
  region: process.env.FUNCTION_REGION ?? 'us-central1',
  maxInstances: 20,
});

type Role = 'player' | 'viewer' | 'admin';
type MatchStatus = 'pending' | 'disputed' | 'confirmed';
type TossDecision = 'strike_first' | 'choose_side';
type CarromColor = 'white' | 'black';
type QueenPocketedBy = 'none' | 'striker' | 'non_striker';

interface CarromTossState {
  toss_winner_player_id: number | null;
  toss_decision: TossDecision | null;
  first_striker_player_id: number | null;
  first_striker_color: CarromColor | null;
}

interface CarromBoardRecord {
  board_number: number;
  striker_player_id: number | null;
  striker_color: CarromColor | null;
  striker_pocketed: number | null;
  non_striker_pocketed: number | null;
  queen_pocketed_by: QueenPocketedBy;
  points_player1: number;
  points_player2: number;
  winner_player_id: number | null;
  is_tiebreaker: boolean;
  is_sudden_death: boolean;
  notes: string;
}

interface CarromSuddenDeathRecord {
  winner_player_id: number;
  player1_hits: number;
  player2_hits: number;
  attempts: number;
}

interface UserRecord {
  id: number;
  email: string | null;
  handle: string;
  display_name: string;
  first_name: string | null;
  last_name: string | null;
  password_hash: string;
  role: Role;
  created_at: string;
}

interface MatchRecord {
  id: number;
  tournament_id: number | null;
  group_number: number | null;
  round_number: number;
  table_number: number;
  player1_id: number;
  player2_id: number;
  confirmed_score1: number | null;
  confirmed_score2: number | null;
  confirmed_at: string | null;
  toss: CarromTossState | null;
  boards: CarromBoardRecord[];
  sudden_death: CarromSuddenDeathRecord | null;
}

interface ScoreConfirmationRecord {
  match_id: number;
  player_id: number;
  score1: number;
  score2: number;
  carrom_digest: string | null;
  toss: CarromTossState | null;
  boards: CarromBoardRecord[];
  sudden_death: CarromSuddenDeathRecord | null;
  created_at: string;
  updated_at: string;
}

interface UserDto {
  id: number;
  email: string | null;
  handle: string;
  display_name: string;
  first_name: string | null;
  last_name: string | null;
  profile_complete: boolean;
  role: Role;
}

interface MatchDto {
  id: number;
  tournament_id: number | null;
  group_number: number | null;
  round_number: number;
  table_number: number;
  player1: {
    id: number;
    handle: string;
    display_name: string;
    country: string | null;
  };
  player2: {
    id: number;
    handle: string;
    display_name: string;
    country: string | null;
  };
  status: MatchStatus;
  confirmed_score1: number | null;
  confirmed_score2: number | null;
  confirmations: number;
  my_confirmation: {
    score1: number;
    score2: number;
  } | null;
  toss: CarromTossState | null;
  boards: CarromBoardRecord[];
  sudden_death: CarromSuddenDeathRecord | null;
}

interface RoundDto {
  round_number: number;
  is_complete: boolean;
  matches: MatchDto[];
}

interface StandingRowDto {
  position: number;
  player_id: number;
  handle: string;
  display_name: string;
  played: number;
  wins: number;
  draws: number;
  losses: number;
  goals_for: number;
  goals_against: number;
  goal_difference: number;
  sum_round_points: number;
  sum_opponent_round_points: number;
  net_game_points_difference: number;
  round_points: number;
  points: number;
}

interface RoundPointsDto {
  round_number: number;
  points: Array<{
    player_id: number;
    display_name: string;
    points: number;
  }>;
}

interface RoundStandingsDto {
  round_number: number;
  is_complete: boolean;
  standings: StandingRowDto[];
}

interface LiveSnapshotDto {
  generated_at: string;
  current_round: number | null;
  rounds: RoundDto[];
  standings: StandingRowDto[];
}

interface TournamentSetupPlayerInput {
  displayName: string;
  handleHint?: string;
  password?: string;
  state?: string;
  country?: string;
  emailId?: string;
  registeredFlag?: boolean;
  tshirtSize?: string;
  feesPaidFlag?: boolean;
  phoneNumber?: string;
}

interface PersonNameDto {
  first_name: string;
  last_name: string;
}

interface TournamentSetupMetadataInput {
  type: TournamentType;
  subType: TournamentSubType;
  strength: number;
  startDateTime: string;
  endDateTime: string;
  srrRounds: number;
  numberOfGroups: number;
  singlesMaxParticipants: number;
  doublesMaxTeams: number;
  numberOfTables: number;
  roundTimeLimitMinutes: number;
  venueName: string;
  directorName: string;
  referees: PersonNameModel[];
  chiefReferee: PersonNameModel;
  category: TournamentCategory;
  subCategory: TournamentSubCategory;
}

interface TournamentSetupCredentialDto {
  player_id: number;
  display_name: string;
  handle: string;
  password: string;
}

interface TournamentSetupResultDto {
  tournament: {
    id: number;
    name: string;
    status: 'setup' | 'active' | 'completed';
    metadata: {
      type: TournamentType;
      sub_type: TournamentSubType;
      strength: number;
      start_date_time: string;
      end_date_time: string;
      srr_rounds: number;
      number_of_groups: number;
      singles_max_participants: number;
      doubles_max_teams: number;
      number_of_tables: number;
      round_time_limit_minutes: number;
      venue_name: string;
      director_name: string;
      referees: PersonNameDto[];
      chief_referee: PersonNameDto;
      category: TournamentCategory;
      sub_category: TournamentSubCategory;
    } | null;
  };
  players_created: number;
  rounds_created: number;
  matches_created: number;
  credentials: TournamentSetupCredentialDto[];
}

type TournamentStatus = 'setup' | 'active' | 'completed';

interface TournamentWorkflowStepDto {
  key: TournamentWorkflowStepKey;
  status: TournamentWorkflowStepStatus;
  completed_at: string | null;
}

interface TournamentWorkflowDto {
  steps: TournamentWorkflowStepDto[];
  updated_at: string;
}

interface TournamentDto {
  id: number;
  name: string;
  status: TournamentStatus;
  created_at: string;
  updated_at: string;
  selected_ranking_year: number | null;
  selected_ranking_description: string | null;
  type: TournamentType | null;
  category: TournamentCategory | null;
  sub_category: TournamentSubCategory | null;
  metadata: TournamentSetupResultDto['tournament']['metadata'];
  workflow: TournamentWorkflowDto;
}

interface TournamentPlayerDto {
  id: number;
  handle: string;
  display_name: string;
  state?: string;
  country?: string;
  email_id?: string;
  registered_flag?: boolean;
  t_shirt_size?: string;
  fees_paid_flag?: boolean;
  phone_number?: string;
}

interface TournamentSeedingRowDto {
  seed: number;
  player_id: number;
  display_name: string;
  handle: string;
  state: string | null;
  country: string | null;
  email_id: string | null;
  source_type: TournamentSeedingSourceType;
  matched_by: TournamentSeedingMatchedBy;
  ranking_rank: number | null;
  ranking_year: number | null;
  ranking_description: string | null;
  is_manual: boolean;
  updated_at: string;
}

interface TournamentSeedingSummaryDto {
  national_players: number;
  international_players: number;
  new_players: number;
}

interface TournamentSeedingSnapshotDto {
  tournament: TournamentDto;
  ranking_year: number;
  ranking_description: string;
  national_country: string | null;
  seeded: boolean;
  generated_at: string | null;
  summary: TournamentSeedingSummaryDto;
  rows: TournamentSeedingRowDto[];
}

interface TournamentGroupRowDto {
  seed: number;
  group_number: number;
  group_count: number;
  method: TournamentGroupingMethod;
  player_id: number;
  display_name: string;
  handle: string;
  state: string | null;
  country: string | null;
  email_id: string | null;
  source_type: TournamentSeedingSourceType;
  ranking_rank: number | null;
  ranking_year: number | null;
  ranking_description: string | null;
  updated_at: string;
}

interface TournamentGroupsSnapshotDto {
  tournament: TournamentDto;
  generated: boolean;
  method: TournamentGroupingMethod | null;
  group_count: number;
  generated_at: string | null;
  rows: TournamentGroupRowDto[];
}

type RoundOnePairingMethod = 'adjacent' | 'top_vs_top' | 'top_vs_bottom';

interface GroupMatchupSummaryDto {
  group_number: number;
  player_count: number;
  current_round: number;
  max_rounds: number;
  pending_matches: number;
  completed_matches: number;
}

interface MatchupGenerateResultDto {
  tournament: TournamentDto;
  group_number: number;
  round_number: number;
  method: RoundOnePairingMethod | 'swiss';
  matches_created: number;
  summary: GroupMatchupSummaryDto;
}

interface MatchupDeleteResultDto {
  tournament: TournamentDto;
  group_number: number;
  deleted_round_number: number;
  deleted_matches: number;
  summary: GroupMatchupSummaryDto;
}

interface NationalRankingUploadInput {
  rank: number;
  playerName: string;
  rankingDescription: string;
  state: string | null;
  country: string | null;
  emailId: string | null;
  rankingPoints: number | null;
  rankingYear: number;
  lastUpdated: string | null;
}

interface ParsedCarromSubmission {
  toss: CarromTossState | null;
  boards: CarromBoardRecord[];
  sudden_death: CarromSuddenDeathRecord | null;
  score1: number | null;
  score2: number | null;
  digest: string;
}

const COLLECTIONS = {
  users: 'users',
  userEmails: 'user_emails',
  firebaseIdentities: 'firebase_identities',
  players: 'players',
  nationalRankings: 'national_rankings',
  tournamentPlayers: 'tournament_players',
  tournamentSeedings: 'tournament_seedings',
  tournamentGroups: 'tournament_groups',
  tournaments: 'tournaments',
  rounds: 'rounds',
  scores: 'scores',
  matches: 'matches',
  scoreConfirmations: 'score_confirmations',
};

const countersRef = db.doc('meta/counters');

const CARROM_RULES = {
  regulationBoards: 8,
  tieBreakerBoard: 9,
  maxBoardPoints: 13,
  maxMenPerColor: 9,
  queenPoints: 3,
  suddenDeathBonusPoint: 1,
  maxSuddenDeathAttempts: 3,
};

class HttpError extends Error {
  constructor(
    public readonly statusCode: number,
    public readonly detail: string,
  ) {
    super(detail);
  }
}

function utcNow(): string {
  return new Date().toISOString();
}

function normalizeHandle(handle: string): string {
  return handle.trim().toLowerCase();
}

function normalizeEmail(value: string): string {
  return value.trim().toLowerCase();
}

function isValidEmail(value: string): boolean {
  return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(value);
}

function matchPoints(score1: number, score2: number): [number, number] {
  if (score1 > score2) return [3, 0];
  if (score2 > score1) return [0, 3];
  return [1, 1];
}

function toInt(value: unknown, fallback: number): number {
  if (typeof value === 'number' && Number.isFinite(value)) {
    return Math.trunc(value);
  }
  if (typeof value === 'string' && value.trim().length > 0) {
    const parsed = Number(value);
    if (Number.isFinite(parsed)) return Math.trunc(parsed);
  }
  return fallback;
}

function toOptionalInt(value: unknown): number | null {
  if (value === null || value === undefined) return null;
  if (typeof value === 'number' && Number.isFinite(value)) {
    return Math.trunc(value);
  }
  if (typeof value === 'string' && value.trim().length > 0) {
    const parsed = Number(value);
    if (Number.isFinite(parsed)) return Math.trunc(parsed);
  }
  return null;
}

function toText(value: unknown, fallback = ''): string {
  if (typeof value === 'string') return value;
  return fallback;
}

function parseBooleanQuery(value: unknown): boolean {
  if (typeof value === 'boolean') return value;
  if (typeof value !== 'string') return false;
  const normalized = value.trim().toLowerCase();
  return normalized === '1' || normalized === 'true' || normalized === 'yes';
}

function parsePositiveInt(value: unknown, fieldName: string): number {
  const parsed = toInt(value, -1);
  if (parsed < 1) {
    throw new HttpError(422, `${fieldName} must be a positive integer.`);
  }
  return parsed;
}

function parsePositiveEvenInt(value: unknown, fieldName: string): number {
  const parsed = parsePositiveInt(value, fieldName);
  if (parsed % 2 !== 0) {
    throw new HttpError(422, `${fieldName} must be an even integer.`);
  }
  return parsed;
}

function parseScore(value: unknown, fieldName: string): number {
  const parsed = toInt(value, Number.NaN);
  if (!Number.isInteger(parsed) || parsed < 0 || parsed > 999) {
    throw new HttpError(422, `${fieldName} must be an integer between 0 and 999.`);
  }
  return parsed;
}

function parseNumberInRange(
  value: unknown,
  fieldName: string,
  min: number,
  max: number,
): number {
  let parsed = Number.NaN;
  if (typeof value === 'number') {
    parsed = value;
  } else if (typeof value === 'string' && value.trim().length > 0) {
    parsed = Number(value);
  }
  if (!Number.isFinite(parsed) || parsed < min || parsed > max) {
    throw new HttpError(422, `${fieldName} must be between ${min} and ${max}.`);
  }
  return parsed;
}

function parseIsoDateTime(value: unknown, fieldName: string): string {
  const raw = toText(value).trim();
  if (!raw) {
    throw new HttpError(422, `${fieldName} is required.`);
  }
  const parsed = Date.parse(raw);
  if (Number.isNaN(parsed)) {
    throw new HttpError(422, `${fieldName} must be a valid date-time.`);
  }
  return new Date(parsed).toISOString();
}

function parseEnumValue<T extends string>(
  value: unknown,
  fieldName: string,
  allowed: readonly T[],
  aliases?: Record<string, T>,
): T {
  const normalized = toText(value).trim().toLowerCase();
  const mapped = aliases?.[normalized] ?? normalized;
  if (!allowed.includes(mapped as T)) {
    throw new HttpError(
      422,
      `${fieldName} must be one of: ${allowed.join(', ')}.`,
    );
  }
  return mapped as T;
}

function parsePersonNameInput(value: unknown, fieldName: string): PersonNameModel {
  if (typeof value !== 'object' || value == null) {
    throw new HttpError(422, `${fieldName} must be an object.`);
  }
  const payload = value as Record<string, unknown>;
  const firstName = toText(
    payload.first_name ?? payload.firstName ?? payload.fname,
  ).trim();
  const lastName = toText(
    payload.last_name ?? payload.lastName ?? payload.lname,
  ).trim();
  assertLength(firstName, `${fieldName}.first_name`, 1, 80);
  assertLength(lastName, `${fieldName}.last_name`, 1, 80);
  return {firstName, lastName};
}

function parseTournamentSetupMetadata(
  payload: Record<string, unknown>,
): TournamentSetupMetadataInput {
  const tournamentTypeValues = ['national', 'open', 'regional', 'club'] as const;
  const tournamentSubTypeValues = ['singles', 'doubles'] as const;

  const typeCandidate =
    [payload.tournament_type, payload.type, payload.tournament_flag, payload.flag]
      .find((entry) => {
        const normalized = toText(entry).trim().toLowerCase();
        return (
          normalized === 'national' ||
          normalized === 'open' ||
          normalized === 'regional' ||
          normalized === 'reginaol' ||
          normalized === 'club'
        );
      });
  const normalizedTypeCandidate = toText(typeCandidate).trim().toLowerCase();
  const type = parseEnumValue<TournamentType>(
    normalizedTypeCandidate == 'reginaol' ? 'regional' : typeCandidate,
    'tournament_type',
    tournamentTypeValues,
  );
  const explicitSubTypeValue =
    payload.tournament_sub_type ??
    payload.sub_type ??
    payload.subType ??
    payload.subtype ??
    payload.tournament_subtype;
  const legacySubTypeCandidate =
    [payload.tournament_type, payload.type].find((entry) => {
      const normalized = toText(entry).trim().toLowerCase();
      return normalized === 'singles' || normalized === 'doubles';
    });
  const subType = parseEnumValue<TournamentSubType>(
    explicitSubTypeValue ?? legacySubTypeCandidate,
    'tournament_sub_type',
    tournamentSubTypeValues,
  );
  const strength = parseNumberInRange(
    payload.tournament_strength ?? payload.strength,
    'tournament_strength',
    0,
    1,
  );
  const startDateTime = parseIsoDateTime(
    payload.tournament_start_date_time ??
      payload.start_date_time ??
      payload.startDateTime,
    'tournament_start_date_time',
  );
  const endDateTime = parseIsoDateTime(
    payload.tournament_end_date_time ??
      payload.end_date_time ??
      payload.endDateTime,
    'tournament_end_date_time',
  );
  if (Date.parse(endDateTime) <= Date.parse(startDateTime)) {
    throw new HttpError(
      422,
      'tournament_end_date_time must be after tournament_start_date_time.',
    );
  }
  const srrRounds = parsePositiveInt(
    payload.tournament_srr_rounds ??
      payload.tournament_no_of_srr_rounds ??
      payload.srr_rounds ??
      payload.number_of_srr_rounds ??
      payload.srrRounds,
    'tournament_srr_rounds',
  );
  if (srrRounds > 200) {
    throw new HttpError(
      422,
      'tournament_srr_rounds must be <= 200.',
    );
  }
  const singlesMaxParticipants = parsePositiveEvenInt(
    payload.tournament_limits_singles_max_participants ??
      payload.tournament_limits_single_max_participants ??
      payload.singles_max_participants ??
      payload.singlesMaxParticipants,
    'tournament_limits_singles_max_participants',
  );
  const doublesMaxTeams = parsePositiveEvenInt(
    payload.tournament_limits_doubles_max_teams ??
      payload.tournament_limits_double_max_teams ??
      payload.doubles_max_teams ??
      payload.doublesMaxTeams,
    'tournament_limits_doubles_max_teams',
  );
  const numberOfGroups = parsePositiveInt(
    payload.tournament_number_of_groups ??
      payload.number_of_groups ??
      payload.numberOfGroups ??
      payload.group_count ??
      payload.groupCount ??
      4,
    'tournament_number_of_groups',
  );
  if (numberOfGroups > 64) {
    throw new HttpError(
      422,
      'tournament_number_of_groups must be <= 64.',
    );
  }
  const venueName = toText(
    payload.tournament_venue_name ?? payload.venue_name ?? payload.venueName,
  ).trim();
  assertLength(venueName, 'tournament_venue_name', 2, 120);

  const directorName = toText(
    payload.tournament_director_name ??
      payload.director_name ??
      payload.directorName,
  ).trim();
  assertLength(directorName, 'tournament_director_name', 2, 120);

  const chiefReferee = parsePersonNameInput(
    payload.tournament_chief_referee ??
      payload.chief_referee ??
      payload.chiefReferee,
    'tournament_chief_referee',
  );

  const refereesRaw =
    payload.tournament_referees ??
    payload.referees ??
    payload.tournament_referee_list;
  if (!Array.isArray(refereesRaw) || refereesRaw.length === 0) {
    throw new HttpError(
      422,
      'tournament_referees must be a non-empty array.',
    );
  }
  const referees = refereesRaw.map((entry, index) =>
    parsePersonNameInput(entry, `tournament_referees[${index}]`),
  );
  const category = parseEnumValue<TournamentCategory>(
    payload.tournament_category ?? payload.category,
    'tournament_category',
    ['men', 'women'],
  );
  const subCategory = parseEnumValue<TournamentSubCategory>(
    payload.tournament_sub_category ?? payload.sub_category ?? payload.subCategory,
    'tournament_sub_category',
    ['junior', 'senior'],
    {juniors: 'junior', seniors: 'senior'},
  );
  const computedNumberOfTables =
    subType === 'singles'
      ? singlesMaxParticipants / 2
      : doublesMaxTeams / 2;
  const participantLimit =
    subType === 'singles'
      ? singlesMaxParticipants
      : doublesMaxTeams;
  if (numberOfGroups > participantLimit) {
    throw new HttpError(
      422,
      `tournament_number_of_groups must be <= participant limit (${participantLimit}).`,
    );
  }
  const roundTimeLimitMinutes = parsePositiveInt(
    payload.tournament_round_time_limit_minutes ??
      payload.round_time_limit_minutes ??
      payload.roundTimeLimitMinutes,
    'tournament_round_time_limit_minutes',
  );
  if (roundTimeLimitMinutes > 600) {
    throw new HttpError(
      422,
      'tournament_round_time_limit_minutes must be <= 600.',
    );
  }
  const providedNumberOfTablesRaw =
    payload.tournament_number_of_tables ??
    payload.number_of_tables ??
    payload.numberOfTables;
  if (providedNumberOfTablesRaw != null && providedNumberOfTablesRaw != '') {
    const providedNumberOfTables = parsePositiveInt(
      providedNumberOfTablesRaw,
      'tournament_number_of_tables',
    );
    if (providedNumberOfTables !== computedNumberOfTables) {
      throw new HttpError(
        422,
        `tournament_number_of_tables must equal ${computedNumberOfTables} for ${subType}.`,
      );
    }
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
    numberOfTables: computedNumberOfTables,
    roundTimeLimitMinutes,
    venueName,
    directorName,
    referees,
    chiefReferee,
    category,
    subCategory,
  };
}

function tournamentMetadataInputToModel(
  metadata: TournamentSetupMetadataInput,
): TournamentMetadataModel {
  return {
    type: metadata.type,
    subType: metadata.subType,
    strength: metadata.strength,
    startDateTime: metadata.startDateTime,
    endDateTime: metadata.endDateTime,
    srrRounds: metadata.srrRounds,
    numberOfGroups: metadata.numberOfGroups,
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
  };
}

function defaultTournamentMetadataInput(): TournamentSetupMetadataInput {
  const singlesMaxParticipants = 32;
  const doublesMaxTeams = 16;
  const startDateTime = utcNow();
  const endDateTime = new Date(
    Date.parse(startDateTime) + 2 * 60 * 60 * 1000,
  ).toISOString();
  return {
    type: 'open',
    subType: 'singles',
    strength: 1,
    startDateTime,
    endDateTime,
    srrRounds: 7,
    numberOfGroups: 4,
    singlesMaxParticipants,
    doublesMaxTeams,
    numberOfTables: singlesMaxParticipants / 2,
    roundTimeLimitMinutes: 30,
    venueName: 'TBD Venue',
    directorName: 'TBD Director',
    referees: [{firstName: 'TBD', lastName: 'Referee'}],
    chiefReferee: {firstName: 'TBD', lastName: 'Chief Referee'},
    category: 'men',
    subCategory: 'senior',
  };
}

function personNameToDto(name: PersonNameModel): PersonNameDto {
  return {
    first_name: name.firstName,
    last_name: name.lastName,
  };
}

function tournamentMetadataToDto(
  metadata: TournamentMetadataModel | null | undefined,
): TournamentSetupResultDto['tournament']['metadata'] {
  if (metadata == null) return null;
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
    referees: metadata.referees.map((entry) => personNameToDto(entry)),
    chief_referee: personNameToDto(metadata.chiefReferee),
    category: metadata.category,
    sub_category: metadata.subCategory,
  };
}

function tournamentDtoFromModel(model: {
  id: number;
  name: string;
  status: TournamentStatus;
  metadata?: TournamentMetadataModel | null;
  selectedRankingYear: number | null;
  selectedRankingDescription: string | null;
  workflow: {
    steps: {
      key: TournamentWorkflowStepKey;
      status: TournamentWorkflowStepStatus;
      completedAt: string | null;
    }[];
    updatedAt: string;
  };
  createdAt: string;
  updatedAt: string;
}): TournamentDto {
  const metadata = tournamentMetadataToDto(model.metadata);
  return {
    id: model.id,
    name: model.name,
    status: model.status,
    created_at: model.createdAt,
    updated_at: model.updatedAt,
    selected_ranking_year: model.selectedRankingYear,
    selected_ranking_description: model.selectedRankingDescription,
    type: metadata?.type ?? null,
    category: metadata?.category ?? null,
    sub_category: metadata?.sub_category ?? null,
    metadata,
    workflow: {
      steps: model.workflow.steps.map((step) => ({
        key: step.key,
        status: step.status,
        completed_at: step.completedAt,
      })),
      updated_at: model.workflow.updatedAt,
    },
  };
}

function parseTournamentStatus(
  value: unknown,
  fallback: TournamentStatus,
): TournamentStatus {
  const normalized = toText(value).trim().toLowerCase();
  if (!normalized) return fallback;
  if (normalized === 'setup' || normalized === 'active' || normalized === 'completed') {
    return normalized;
  }
  throw new HttpError(422, 'status must be setup, active, or completed.');
}

function parseTournamentWorkflowStepKey(value: unknown): TournamentWorkflowStepKey {
  const normalized = toText(value).trim().toLowerCase();
  const allowed = new Set<TournamentWorkflowStepKey>([
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
  ]);
  if (allowed.has(normalized as TournamentWorkflowStepKey)) {
    return normalized as TournamentWorkflowStepKey;
  }
  throw new HttpError(422, 'Invalid workflow step key.');
}

function parseTournamentWorkflowStepStatus(
  value: unknown,
  fallback: TournamentWorkflowStepStatus = 'completed',
): TournamentWorkflowStepStatus {
  const normalized = toText(value).trim().toLowerCase();
  if (!normalized) return fallback;
  if (normalized === 'pending' || normalized === 'completed') {
    return normalized;
  }
  throw new HttpError(422, 'workflow status must be pending or completed.');
}

function parseIntInRange(
  value: unknown,
  fieldName: string,
  min: number,
  max: number,
): number {
  const parsed = toInt(value, Number.NaN);
  if (!Number.isInteger(parsed) || parsed < min || parsed > max) {
    throw new HttpError(
      422,
      `${fieldName} must be an integer between ${min} and ${max}.`,
    );
  }
  return parsed;
}

function parseOptionalIntInRange(
  value: unknown,
  fieldName: string,
  min: number,
  max: number,
): number | null {
  if (value == null || value === '') return null;
  return parseIntInRange(value, fieldName, min, max);
}

function toBool(value: unknown, fallback = false): boolean {
  if (typeof value === 'boolean') return value;
  if (typeof value === 'number') return value !== 0;
  if (typeof value !== 'string') return fallback;
  const normalized = value.trim().toLowerCase();
  if (!normalized) return fallback;
  return (
    normalized === '1' ||
    normalized === 'true' ||
    normalized === 'yes' ||
    normalized === 'y'
  );
}

function parseOptionalPlayerIdForMatch(
  value: unknown,
  fieldName: string,
  player1Id: number,
  player2Id: number,
): number | null {
  if (value == null || value === '') return null;
  const parsed = parsePositiveInt(value, fieldName);
  if (parsed !== player1Id && parsed !== player2Id) {
    throw new HttpError(
      422,
      `${fieldName} must be either ${player1Id} or ${player2Id}.`,
    );
  }
  return parsed;
}

function parseOptionalTossDecision(value: unknown, fieldName: string): TossDecision | null {
  const normalized = toText(value).trim().toLowerCase();
  if (!normalized) return null;
  if (normalized === 'strike_first' || normalized === 'strike') {
    return 'strike_first';
  }
  if (normalized === 'choose_side' || normalized === 'side') {
    return 'choose_side';
  }
  throw new HttpError(
    422,
    `${fieldName} must be strike_first or choose_side.`,
  );
}

function parseOptionalCarromColor(value: unknown, fieldName: string): CarromColor | null {
  const normalized = toText(value).trim().toLowerCase();
  if (!normalized) return null;
  if (normalized === 'white' || normalized === 'black') {
    return normalized;
  }
  throw new HttpError(422, `${fieldName} must be white or black.`);
}

function parseQueenPocketedBy(value: unknown, fieldName: string): QueenPocketedBy {
  const normalized = toText(value).trim().toLowerCase();
  if (!normalized || normalized === 'none') return 'none';
  if (normalized === 'striker' || normalized === 'non_striker') {
    return normalized;
  }
  throw new HttpError(
    422,
    `${fieldName} must be none, striker, or non_striker.`,
  );
}

function parseCarromTossState(
  value: unknown,
  player1Id: number,
  player2Id: number,
): CarromTossState | null {
  if (value == null) return null;
  if (typeof value !== 'object') {
    throw new HttpError(422, 'toss must be an object.');
  }
  const payload = value as Record<string, unknown>;
  const tossWinner = parseOptionalPlayerIdForMatch(
    payload.toss_winner_player_id ?? payload.tossWinnerPlayerId,
    'toss.toss_winner_player_id',
    player1Id,
    player2Id,
  );
  const tossDecision = parseOptionalTossDecision(
    payload.toss_decision ?? payload.tossDecision,
    'toss.toss_decision',
  );
  const firstStriker = parseOptionalPlayerIdForMatch(
    payload.first_striker_player_id ?? payload.firstStrikerPlayerId,
    'toss.first_striker_player_id',
    player1Id,
    player2Id,
  );
  const firstStrikerColor = parseOptionalCarromColor(
    payload.first_striker_color ?? payload.firstStrikerColor,
    'toss.first_striker_color',
  );

  if (
    tossWinner == null &&
    tossDecision == null &&
    firstStriker == null &&
    firstStrikerColor == null
  ) {
    return null;
  }

  if (firstStrikerColor != null && firstStriker == null) {
    throw new HttpError(
      422,
      'toss.first_striker_player_id is required when first_striker_color is provided.',
    );
  }

  return {
    toss_winner_player_id: tossWinner,
    toss_decision: tossDecision,
    first_striker_player_id: firstStriker,
    first_striker_color: firstStrikerColor,
  };
}

function parseCarromBoardRecord(
  value: unknown,
  index: number,
  player1Id: number,
  player2Id: number,
): CarromBoardRecord {
  if (typeof value !== 'object' || value == null) {
    throw new HttpError(422, `boards[${index}] must be an object.`);
  }
  const payload = value as Record<string, unknown>;
  const boardNumber = parsePositiveInt(
    payload.board_number ?? payload.boardNumber ?? index + 1,
    `boards[${index}].board_number`,
  );
  if (boardNumber > CARROM_RULES.tieBreakerBoard) {
    throw new HttpError(
      422,
      `boards[${index}].board_number cannot exceed ${CARROM_RULES.tieBreakerBoard}.`,
    );
  }

  const strikerPlayerId = parseOptionalPlayerIdForMatch(
    payload.striker_player_id ?? payload.strikerPlayerId,
    `boards[${index}].striker_player_id`,
    player1Id,
    player2Id,
  );
  const strikerColor = parseOptionalCarromColor(
    payload.striker_color ?? payload.strikerColor,
    `boards[${index}].striker_color`,
  );
  const queenPocketedBy = parseQueenPocketedBy(
    payload.queen_pocketed_by ?? payload.queenPocketedBy,
    `boards[${index}].queen_pocketed_by`,
  );

  const directP1 = parseOptionalIntInRange(
    payload.player1_points ??
      payload.points_player1 ??
      payload.player1Points ??
      payload.pointsPlayer1,
    `boards[${index}].player1_points`,
    0,
    CARROM_RULES.maxBoardPoints,
  );
  const directP2 = parseOptionalIntInRange(
    payload.player2_points ??
      payload.points_player2 ??
      payload.player2Points ??
      payload.pointsPlayer2,
    `boards[${index}].player2_points`,
    0,
    CARROM_RULES.maxBoardPoints,
  );
  const hasDirectPoints = directP1 != null || directP2 != null;
  if (hasDirectPoints && (directP1 == null || directP2 == null)) {
    throw new HttpError(
      422,
      `boards[${index}] must provide both player1_points and player2_points.`,
    );
  }

  const strikerPocketed = parseOptionalIntInRange(
    payload.striker_pocketed ?? payload.strikerPocketed,
    `boards[${index}].striker_pocketed`,
    0,
    CARROM_RULES.maxMenPerColor,
  );
  const nonStrikerPocketed = parseOptionalIntInRange(
    payload.non_striker_pocketed ?? payload.nonStrikerPocketed,
    `boards[${index}].non_striker_pocketed`,
    0,
    CARROM_RULES.maxMenPerColor,
  );
  const hasPocketStats =
    strikerPocketed != null ||
    nonStrikerPocketed != null ||
    toText(payload.queen_pocketed_by ?? payload.queenPocketedBy).trim().length > 0;
  if (hasPocketStats && (strikerPocketed == null || nonStrikerPocketed == null)) {
    throw new HttpError(
      422,
      `boards[${index}] must provide both striker_pocketed and non_striker_pocketed.`,
    );
  }

  let pointsPlayer1: number;
  let pointsPlayer2: number;

  if (directP1 != null && directP2 != null) {
    pointsPlayer1 = directP1;
    pointsPlayer2 = directP2;
  } else {
    if (strikerPlayerId == null) {
      throw new HttpError(
        422,
        `boards[${index}].striker_player_id is required when points are not provided directly.`,
      );
    }
    if (strikerPocketed == null || nonStrikerPocketed == null) {
      throw new HttpError(
        422,
        `boards[${index}] must provide pocket stats when points are not provided directly.`,
      );
    }

    let strikerPoints = Math.max(0, CARROM_RULES.maxMenPerColor - nonStrikerPocketed);
    let nonStrikerPoints = Math.max(0, CARROM_RULES.maxMenPerColor - strikerPocketed);

    if (queenPocketedBy === 'striker') {
      strikerPoints += CARROM_RULES.queenPoints;
    } else if (queenPocketedBy === 'non_striker') {
      nonStrikerPoints += CARROM_RULES.queenPoints;
    }

    strikerPoints = Math.min(strikerPoints, CARROM_RULES.maxBoardPoints);
    nonStrikerPoints = Math.min(nonStrikerPoints, CARROM_RULES.maxBoardPoints);

    if (strikerPlayerId === player1Id) {
      pointsPlayer1 = strikerPoints;
      pointsPlayer2 = nonStrikerPoints;
    } else {
      pointsPlayer1 = nonStrikerPoints;
      pointsPlayer2 = strikerPoints;
    }
  }

  const winnerPlayerId = parseOptionalPlayerIdForMatch(
    payload.winner_player_id ?? payload.winnerPlayerId,
    `boards[${index}].winner_player_id`,
    player1Id,
    player2Id,
  );
  const resolvedWinner =
    winnerPlayerId ??
    (pointsPlayer1 === pointsPlayer2 ? null : pointsPlayer1 > pointsPlayer2 ? player1Id : player2Id);

  const notes = toText(payload.notes).trim().slice(0, 500);
  const isTiebreaker =
    toBool(payload.is_tiebreaker ?? payload.isTiebreaker, false) ||
    boardNumber === CARROM_RULES.tieBreakerBoard;
  const isSuddenDeath = toBool(
    payload.is_sudden_death ?? payload.isSuddenDeath,
    false,
  );

  return {
    board_number: boardNumber,
    striker_player_id: strikerPlayerId,
    striker_color: strikerColor,
    striker_pocketed: strikerPocketed,
    non_striker_pocketed: nonStrikerPocketed,
    queen_pocketed_by: queenPocketedBy,
    points_player1: pointsPlayer1,
    points_player2: pointsPlayer2,
    winner_player_id: resolvedWinner,
    is_tiebreaker: isTiebreaker,
    is_sudden_death: isSuddenDeath,
    notes,
  };
}

function parseCarromSuddenDeath(
  value: unknown,
  player1Id: number,
  player2Id: number,
): CarromSuddenDeathRecord | null {
  if (value == null) return null;
  if (typeof value !== 'object') {
    throw new HttpError(422, 'sudden_death must be an object.');
  }

  const payload = value as Record<string, unknown>;
  const winner = parseOptionalPlayerIdForMatch(
    payload.winner_player_id ?? payload.winnerPlayerId,
    'sudden_death.winner_player_id',
    player1Id,
    player2Id,
  );
  const player1Hits = parseOptionalIntInRange(
    payload.player1_hits ?? payload.player1Hits,
    'sudden_death.player1_hits',
    0,
    99,
  );
  const player2Hits = parseOptionalIntInRange(
    payload.player2_hits ?? payload.player2Hits,
    'sudden_death.player2_hits',
    0,
    99,
  );
  const attempts = parseOptionalIntInRange(
    payload.attempts,
    'sudden_death.attempts',
    1,
    99,
  );

  if (winner == null && player1Hits == null && player2Hits == null && attempts == null) {
    return null;
  }

  const resolvedPlayer1Hits = player1Hits ?? 0;
  const resolvedPlayer2Hits = player2Hits ?? 0;
  const resolvedAttempts = attempts ?? CARROM_RULES.maxSuddenDeathAttempts;
  const resolvedWinner =
    winner ??
    (resolvedPlayer1Hits === resolvedPlayer2Hits
      ? null
      : resolvedPlayer1Hits > resolvedPlayer2Hits
      ? player1Id
      : player2Id);

  if (resolvedWinner == null) {
    throw new HttpError(
      422,
      'sudden_death.winner_player_id is required when hits are tied.',
    );
  }

  return {
    winner_player_id: resolvedWinner,
    player1_hits: resolvedPlayer1Hits,
    player2_hits: resolvedPlayer2Hits,
    attempts: resolvedAttempts,
  };
}

function stableNormalizedValue(value: unknown): unknown {
  if (Array.isArray(value)) {
    return value.map((entry) => stableNormalizedValue(entry));
  }
  if (value != null && typeof value === 'object') {
    const source = value as Record<string, unknown>;
    const keys = Object.keys(source).sort((a, b) => a.localeCompare(b));
    const output: Record<string, unknown> = {};
    for (const key of keys) {
      output[key] = stableNormalizedValue(source[key]);
    }
    return output;
  }
  return value;
}

function digestCarromSubmission(value: {
  toss: CarromTossState | null;
  boards: CarromBoardRecord[];
  sudden_death: CarromSuddenDeathRecord | null;
}): string {
  const normalized = stableNormalizedValue(value);
  return crypto
    .createHash('sha256')
    .update(JSON.stringify(normalized))
    .digest('hex');
}

function parseCarromSubmission(
  value: unknown,
  player1Id: number,
  player2Id: number,
): ParsedCarromSubmission | null {
  if (value == null || typeof value !== 'object') {
    return null;
  }

  const payload = value as Record<string, unknown>;
  const topLevelTossProvided =
    payload.toss_winner_player_id != null ||
    payload.toss_decision != null ||
    payload.first_striker_player_id != null ||
    payload.first_striker_color != null;
  const topLevelSuddenDeathProvided =
    payload.sudden_death_winner_player_id != null ||
    payload.sudden_death_player1_hits != null ||
    payload.sudden_death_player2_hits != null ||
    payload.sudden_death_attempts != null;
  const hasCarromFields =
    topLevelTossProvided ||
    topLevelSuddenDeathProvided ||
    payload.toss != null ||
    payload.boards != null ||
    payload.sudden_death != null ||
    payload.suddenDeath != null;
  if (!hasCarromFields) {
    return null;
  }

  const toss = parseCarromTossState(
    payload.toss ??
      (topLevelTossProvided
        ? {
            toss_winner_player_id: payload.toss_winner_player_id,
            toss_decision: payload.toss_decision,
            first_striker_player_id: payload.first_striker_player_id,
            first_striker_color: payload.first_striker_color,
          }
        : null),
    player1Id,
    player2Id,
  );
  const suddenDeath = parseCarromSuddenDeath(
    payload.sudden_death ??
      payload.suddenDeath ??
      (topLevelSuddenDeathProvided
        ? {
            winner_player_id: payload.sudden_death_winner_player_id,
            player1_hits: payload.sudden_death_player1_hits,
            player2_hits: payload.sudden_death_player2_hits,
            attempts: payload.sudden_death_attempts,
          }
        : null),
    player1Id,
    player2Id,
  );

  let boards: CarromBoardRecord[] = [];
  if (payload.boards != null) {
    if (!Array.isArray(payload.boards)) {
      throw new HttpError(422, 'boards must be an array.');
    }
    boards = payload.boards.map((entry, index) =>
      parseCarromBoardRecord(entry, index, player1Id, player2Id),
    );
    boards.sort((a, b) => a.board_number - b.board_number);

    const seen = new Set<number>();
    for (const board of boards) {
      if (seen.has(board.board_number)) {
        throw new HttpError(
          422,
          `Duplicate board_number ${board.board_number} in boards.`,
        );
      }
      seen.add(board.board_number);
    }
    if (boards.length > CARROM_RULES.tieBreakerBoard) {
      throw new HttpError(
        422,
        `A match can contain at most ${CARROM_RULES.tieBreakerBoard} boards.`,
      );
    }
    const hasTieBreakerBoard = boards.some(
      (board) => board.board_number === CARROM_RULES.tieBreakerBoard,
    );
    const regulationBoards = boards.filter(
      (board) => board.board_number <= CARROM_RULES.regulationBoards,
    );
    if (hasTieBreakerBoard && regulationBoards.length < CARROM_RULES.regulationBoards) {
      throw new HttpError(
        422,
        `Board ${CARROM_RULES.tieBreakerBoard} cannot be recorded before all ${CARROM_RULES.regulationBoards} regulation boards.`,
      );
    }
  }

  let score1: number | null = null;
  let score2: number | null = null;
  if (boards.length > 0) {
    score1 = boards.reduce((sum, board) => sum + board.points_player1, 0);
    score2 = boards.reduce((sum, board) => sum + board.points_player2, 0);
    const tieAfterBoards = score1 === score2;

    if (suddenDeath != null && boards.length < CARROM_RULES.regulationBoards) {
      throw new HttpError(
        422,
        `Sudden death cannot be recorded before ${CARROM_RULES.regulationBoards} boards.`,
      );
    }
    if (suddenDeath != null && !tieAfterBoards) {
      throw new HttpError(
        422,
        'Sudden death is only valid when board totals are tied.',
      );
    }

    if (tieAfterBoards && suddenDeath != null) {
      if (suddenDeath.winner_player_id === player1Id) {
        score1 += CARROM_RULES.suddenDeathBonusPoint;
      } else {
        score2 += CARROM_RULES.suddenDeathBonusPoint;
      }
    }
  }

  if (boards.length === 0 && toss == null && suddenDeath == null) {
    return null;
  }

  return {
    toss,
    boards,
    sudden_death: suddenDeath,
    score1,
    score2,
    digest: digestCarromSubmission({
      toss,
      boards,
      sudden_death: suddenDeath,
    }),
  };
}

function confirmationSignature(confirmation: ScoreConfirmationRecord): string {
  return `${confirmation.score1}:${confirmation.score2}:${confirmation.carrom_digest ?? ''}`;
}

function tokenFromHeader(authorization?: string): string | null {
  if (!authorization) return null;
  const [prefix, token] = authorization.trim().split(/\s+/, 2);
  if (!prefix || !token || prefix.toLowerCase() !== 'bearer') {
    return null;
  }
  return token.trim();
}

function hashPassword(password: string): string {
  const salt = crypto.randomBytes(16).toString('hex');
  const digest = crypto
    .pbkdf2Sync(password, salt, 200_000, 32, 'sha256')
    .toString('hex');
  return `${salt}$${digest}`;
}

function handleWithSuffix(baseHandle: string, collisionIndex: number): string {
  if (collisionIndex === 0) return baseHandle.slice(0, 32);
  const suffix = `_${collisionIndex + 1}`;
  const trimmed = baseHandle.slice(0, Math.max(3, 32 - suffix.length));
  return `${trimmed}${suffix}`;
}

function generateRoundRobin(playerIds: number[]): Array<Array<[number, number]>> {
  const participants: Array<number | null> = [...playerIds];
  if (participants.length % 2 === 1) {
    participants.push(null);
  }

  const rounds: Array<Array<[number, number]>> = [];
  const count = participants.length;
  const half = Math.floor(count / 2);

  for (let roundIndex = 0; roundIndex < count - 1; roundIndex += 1) {
    const pairs: Array<[number, number]> = [];
    for (let i = 0; i < half; i += 1) {
      const left = participants[i];
      const right = participants[count - 1 - i];
      if (left == null || right == null) continue;

      if (roundIndex % 2 === 0 && i === 0) {
        pairs.push([right, left]);
      } else {
        pairs.push([left, right]);
      }
    }

    rounds.push(pairs);
    const rotated: Array<number | null> = [
      participants[0],
      participants[count - 1],
      ...participants.slice(1, count - 1),
    ];
    for (let i = 0; i < participants.length; i += 1) {
      participants[i] = rotated[i];
    }
  }

  return rounds;
}

function toUserRecord(snapshot: FirebaseFirestore.DocumentSnapshot): UserRecord | null {
  if (!snapshot.exists) return null;
  const data = snapshot.data() ?? {};
  const roleRaw = toText(data.role);
  const role: Role = roleRaw === 'admin' || roleRaw === 'viewer' ? roleRaw : 'player';
  const handle = toText(data.handle);
  const email = normalizeEmail(toText(data.email));
  const emailFallback = handle.includes('@') ? normalizeEmail(handle) : '';
  return {
    id: toInt(data.id, toInt(snapshot.id, 0)),
    email: email || emailFallback || null,
    handle,
    display_name: toText(data.display_name),
    first_name: toText(data.first_name).trim() || null,
    last_name: toText(data.last_name).trim() || null,
    password_hash: toText(data.password_hash),
    role,
    created_at: toText(data.created_at),
  };
}

function normalizeStoredMatchPlayerId(
  value: unknown,
  player1Id: number,
  player2Id: number,
): number | null {
  const playerId = toOptionalInt(value);
  if (playerId == null) return null;
  return playerId === player1Id || playerId === player2Id ? playerId : null;
}

function normalizeStoredCarromColor(value: unknown): CarromColor | null {
  const normalized = toText(value).trim().toLowerCase();
  if (normalized === 'white' || normalized === 'black') {
    return normalized;
  }
  return null;
}

function normalizeStoredQueenPocketedBy(value: unknown): QueenPocketedBy {
  const normalized = toText(value).trim().toLowerCase();
  if (normalized === 'striker' || normalized === 'non_striker') {
    return normalized;
  }
  return 'none';
}

function toCarromTossStateFromDoc(
  value: unknown,
  player1Id: number,
  player2Id: number,
): CarromTossState | null {
  if (value == null || typeof value !== 'object') return null;
  const payload = value as Record<string, unknown>;
  const tossDecision = parseOptionalTossDecision(
    payload.toss_decision ?? payload.tossDecision,
    'toss.toss_decision',
  );
  const tossState: CarromTossState = {
    toss_winner_player_id: normalizeStoredMatchPlayerId(
      payload.toss_winner_player_id ?? payload.tossWinnerPlayerId,
      player1Id,
      player2Id,
    ),
    toss_decision: tossDecision,
    first_striker_player_id: normalizeStoredMatchPlayerId(
      payload.first_striker_player_id ?? payload.firstStrikerPlayerId,
      player1Id,
      player2Id,
    ),
    first_striker_color: normalizeStoredCarromColor(
      payload.first_striker_color ?? payload.firstStrikerColor,
    ),
  };
  if (
    tossState.toss_winner_player_id == null &&
    tossState.toss_decision == null &&
    tossState.first_striker_player_id == null &&
    tossState.first_striker_color == null
  ) {
    return null;
  }
  return tossState;
}

function toCarromBoardFromDoc(
  value: unknown,
  player1Id: number,
  player2Id: number,
): CarromBoardRecord | null {
  if (value == null || typeof value !== 'object') return null;
  const payload = value as Record<string, unknown>;
  const boardNumber = toInt(payload.board_number ?? payload.boardNumber, 0);
  if (boardNumber < 1 || boardNumber > CARROM_RULES.tieBreakerBoard) return null;

  const pointsPlayer1 = parseIntInRange(
    toInt(
      payload.points_player1 ??
        payload.player1_points ??
        payload.pointsPlayer1 ??
        payload.player1Points,
      0,
    ),
    'points_player1',
    0,
    CARROM_RULES.maxBoardPoints,
  );
  const pointsPlayer2 = parseIntInRange(
    toInt(
      payload.points_player2 ??
        payload.player2_points ??
        payload.pointsPlayer2 ??
        payload.player2Points,
      0,
    ),
    'points_player2',
    0,
    CARROM_RULES.maxBoardPoints,
  );

  return {
    board_number: boardNumber,
    striker_player_id: normalizeStoredMatchPlayerId(
      payload.striker_player_id ?? payload.strikerPlayerId,
      player1Id,
      player2Id,
    ),
    striker_color: normalizeStoredCarromColor(
      payload.striker_color ?? payload.strikerColor,
    ),
    striker_pocketed: toOptionalInt(
      payload.striker_pocketed ?? payload.strikerPocketed,
    ),
    non_striker_pocketed: toOptionalInt(
      payload.non_striker_pocketed ?? payload.nonStrikerPocketed,
    ),
    queen_pocketed_by: normalizeStoredQueenPocketedBy(
      payload.queen_pocketed_by ?? payload.queenPocketedBy,
    ),
    points_player1: pointsPlayer1,
    points_player2: pointsPlayer2,
    winner_player_id: normalizeStoredMatchPlayerId(
      payload.winner_player_id ?? payload.winnerPlayerId,
      player1Id,
      player2Id,
    ),
    is_tiebreaker: toBool(
      payload.is_tiebreaker ?? payload.isTiebreaker,
      boardNumber === CARROM_RULES.tieBreakerBoard,
    ),
    is_sudden_death: toBool(
      payload.is_sudden_death ?? payload.isSuddenDeath,
      false,
    ),
    notes: toText(payload.notes).trim(),
  };
}

function toCarromBoardsFromDoc(
  value: unknown,
  player1Id: number,
  player2Id: number,
): CarromBoardRecord[] {
  if (!Array.isArray(value)) return [];
  const boards = value
    .map((entry) => toCarromBoardFromDoc(entry, player1Id, player2Id))
    .filter((entry): entry is CarromBoardRecord => entry !== null)
    .sort((a, b) => a.board_number - b.board_number);

  const unique: CarromBoardRecord[] = [];
  const seen = new Set<number>();
  for (const board of boards) {
    if (seen.has(board.board_number)) continue;
    seen.add(board.board_number);
    unique.push(board);
  }
  return unique;
}

function toCarromSuddenDeathFromDoc(
  value: unknown,
  player1Id: number,
  player2Id: number,
): CarromSuddenDeathRecord | null {
  if (value == null || typeof value !== 'object') return null;
  const payload = value as Record<string, unknown>;
  const winner = normalizeStoredMatchPlayerId(
    payload.winner_player_id ?? payload.winnerPlayerId,
    player1Id,
    player2Id,
  );
  if (winner == null) return null;
  return {
    winner_player_id: winner,
    player1_hits: toInt(payload.player1_hits ?? payload.player1Hits, 0),
    player2_hits: toInt(payload.player2_hits ?? payload.player2Hits, 0),
    attempts: toInt(payload.attempts, CARROM_RULES.maxSuddenDeathAttempts),
  };
}

function toMatchRecord(snapshot: FirebaseFirestore.DocumentSnapshot): MatchRecord | null {
  if (!snapshot.exists) return null;
  const data = snapshot.data() ?? {};
  const player1Id = toInt(data.player1_id, 0);
  const player2Id = toInt(data.player2_id, 0);
  const toss =
    toCarromTossStateFromDoc(data.toss, player1Id, player2Id) ??
    toCarromTossStateFromDoc(
      {
        toss_winner_player_id: data.toss_winner_player_id,
        toss_decision: data.toss_decision,
        first_striker_player_id: data.first_striker_player_id,
        first_striker_color: data.first_striker_color,
      },
      player1Id,
      player2Id,
    );
  const boards = toCarromBoardsFromDoc(
    data.boards ?? data.board_results,
    player1Id,
    player2Id,
  );
  const suddenDeath =
    toCarromSuddenDeathFromDoc(data.sudden_death, player1Id, player2Id) ??
    toCarromSuddenDeathFromDoc(data.suddenDeath, player1Id, player2Id);

  return {
    id: toInt(data.id, toInt(snapshot.id, 0)),
    tournament_id: toOptionalInt(data.tournament_id ?? data.tournamentId),
    group_number: toOptionalInt(data.group_number ?? data.groupNumber),
    round_number: toInt(data.round_number, 0),
    table_number: toInt(data.table_number, 0),
    player1_id: player1Id,
    player2_id: player2Id,
    confirmed_score1: toOptionalInt(data.confirmed_score1),
    confirmed_score2: toOptionalInt(data.confirmed_score2),
    confirmed_at: toText(data.confirmed_at) || null,
    toss,
    boards,
    sudden_death: suddenDeath,
  };
}

function toScoreConfirmationRecord(
  snapshot: FirebaseFirestore.DocumentSnapshot,
): ScoreConfirmationRecord | null {
  if (!snapshot.exists) return null;
  const data = snapshot.data() ?? {};
  const player1Id = toInt(data.player1_id, 0);
  const player2Id = toInt(data.player2_id, 0);
  const toss =
    toCarromTossStateFromDoc(data.toss, player1Id, player2Id) ??
    toCarromTossStateFromDoc(
      {
        toss_winner_player_id: data.toss_winner_player_id,
        toss_decision: data.toss_decision,
        first_striker_player_id: data.first_striker_player_id,
        first_striker_color: data.first_striker_color,
      },
      player1Id,
      player2Id,
    );
  const boards = toCarromBoardsFromDoc(
    data.boards ?? data.board_results,
    player1Id,
    player2Id,
  );
  const suddenDeath =
    toCarromSuddenDeathFromDoc(data.sudden_death, player1Id, player2Id) ??
    toCarromSuddenDeathFromDoc(data.suddenDeath, player1Id, player2Id);

  return {
    match_id: toInt(data.match_id, 0),
    player_id: toInt(data.player_id, 0),
    score1: toInt(data.score1, 0),
    score2: toInt(data.score2, 0),
    carrom_digest: toText(data.carrom_digest) || null,
    toss,
    boards,
    sudden_death: suddenDeath,
    created_at: toText(data.created_at),
    updated_at: toText(data.updated_at),
  };
}

function userDto(user: UserRecord): UserDto {
  const firstName = user.first_name?.trim() || null;
  const lastName = user.last_name?.trim() || null;
  return {
    id: user.id,
    email: user.email,
    handle: user.handle,
    display_name: user.display_name,
    first_name: firstName,
    last_name: lastName,
    profile_complete: firstName != null && lastName != null,
    role: user.role,
  };
}

function userRecordToModel(user: UserRecord): UserModel {
  return {
    id: user.id,
    email: user.email,
    handle: user.handle,
    displayName: user.display_name,
    firstName: user.first_name,
    lastName: user.last_name,
    passwordHash: user.password_hash,
    role: user.role,
    createdAt: user.created_at,
  };
}

function userModelToRecord(user: UserModel): UserRecord {
  return {
    id: user.id,
    email: user.email ?? null,
    handle: user.handle,
    display_name: user.displayName,
    first_name: user.firstName ?? null,
    last_name: user.lastName ?? null,
    password_hash: user.passwordHash,
    role: user.role,
    created_at: user.createdAt,
  };
}

function tournamentPlayerDtoFromUser(user: UserRecord): TournamentPlayerDto {
  return {
    id: user.id,
    handle: user.handle,
    display_name: user.display_name,
  };
}

function tournamentPlayerDtoFromDoc(
  snapshot: FirebaseFirestore.DocumentSnapshot,
): TournamentPlayerDto | null {
  if (!snapshot.exists) return null;
  const data = snapshot.data() ?? {};
  const playerId = toInt(data.player_id ?? data.id, toInt(snapshot.id, 0));
  if (playerId < 1) return null;
  const state = toText(data.state).trim();
  const country = toText(data.country).trim();
  const emailId = toText(data.email_id).trim();
  const tshirtSize = toText(data.t_shirt_size).trim();
  const phoneNumber = toText(data.phone_number).trim();
  return {
    id: playerId,
    handle: toText(data.handle),
    display_name: toText(data.display_name),
    state: state || undefined,
    country: country || undefined,
    email_id: emailId || undefined,
    registered_flag: toBool(data.registered_flag, false),
    t_shirt_size: tshirtSize || undefined,
    fees_paid_flag: toBool(data.fees_paid_flag, false),
    phone_number: phoneNumber || undefined,
  };
}

function normalizeLookupText(value: unknown): string {
  return toText(value)
    .trim()
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, ' ')
    .replace(/\s+/g, ' ')
    .trim();
}

function normalizeCountryKey(value: unknown): string {
  return toText(value)
    .trim()
    .toLowerCase()
    .replace(/[^a-z]+/g, '');
}

function inferNationalCountry(rankingRows: NationalRankingModel[]): string | null {
  const counts = new Map<string, {count: number; label: string}>();
  for (const row of rankingRows) {
    const key = normalizeCountryKey(row.country);
    const label = toText(row.country).trim();
    if (!key || !label) continue;
    const existing = counts.get(key);
    if (existing == null) {
      counts.set(key, {count: 1, label});
      continue;
    }
    counts.set(key, {count: existing.count + 1, label: existing.label});
  }
  if (counts.size === 0) return null;
  const entries = [...counts.entries()].sort((a, b) => {
    if (a[1].count !== b[1].count) return b[1].count - a[1].count;
    return a[1].label.localeCompare(b[1].label, undefined, {
      sensitivity: 'base',
    });
  });
  return entries[0][1].label;
}

function buildTournamentSeedingRows(params: {
  players: TournamentPlayerDto[];
  rankingRows: NationalRankingModel[];
  rankingYear: number;
  rankingDescription: string;
}): {rows: TournamentSeedingUpsertInput[]; nationalCountry: string | null} {
  const rankingRowsSorted = [...params.rankingRows].sort((a, b) => {
    if (a.rank !== b.rank) return a.rank - b.rank;
    return a.playerName.localeCompare(b.playerName, undefined, {
      sensitivity: 'base',
    });
  });

  const rankingByEmail = new Map<string, NationalRankingModel[]>();
  const rankingByName = new Map<string, NationalRankingModel[]>();
  for (const row of rankingRowsSorted) {
    const emailKey = normalizeEmail(toText(row.emailId));
    if (emailKey.length > 0) {
      const next = rankingByEmail.get(emailKey) ?? [];
      next.push(row);
      rankingByEmail.set(emailKey, next);
    }
    const nameKey = normalizeLookupText(row.playerName);
    if (nameKey.length > 0) {
      const next = rankingByName.get(nameKey) ?? [];
      next.push(row);
      rankingByName.set(nameKey, next);
    }
  }

  const nationalCountry = inferNationalCountry(rankingRowsSorted);
  const nationalCountryKey = normalizeCountryKey(nationalCountry);
  const usedRankingRowIds = new Set<string>();
  const seededRows: TournamentSeedingUpsertInput[] = [];

  for (const player of params.players) {
    const playerEmail = normalizeEmail(toText(player.email_id));
    const playerNameKey = normalizeLookupText(player.display_name);

    let matchedBy: TournamentSeedingMatchedBy = 'none';
    let matchedRanking: NationalRankingModel | null = null;

    if (playerEmail.length > 0) {
      const candidates = rankingByEmail.get(playerEmail) ?? [];
      matchedRanking =
        candidates.find((candidate) => !usedRankingRowIds.has(candidate.id)) ??
        null;
      if (matchedRanking != null) {
        matchedBy = 'email';
      }
    }
    if (matchedRanking == null && playerNameKey.length > 0) {
      const candidates = rankingByName.get(playerNameKey) ?? [];
      matchedRanking =
        candidates.find((candidate) => !usedRankingRowIds.has(candidate.id)) ??
        null;
      if (matchedRanking != null) {
        matchedBy = 'name';
      }
    }

    if (matchedRanking != null) {
      usedRankingRowIds.add(matchedRanking.id);
    }

    const playerCountryKey = normalizeCountryKey(player.country);
    const sourceType: TournamentSeedingSourceType =
      matchedRanking != null
        ? 'national'
        : nationalCountryKey &&
            playerCountryKey &&
            playerCountryKey !== nationalCountryKey
        ? 'international'
        : 'new';

    seededRows.push({
      playerId: player.id,
      seed: 0,
      sourceType,
      matchedBy,
      rankingRank: matchedRanking?.rank ?? null,
      rankingYear: matchedRanking == null ? null : params.rankingYear,
      rankingDescription:
        matchedRanking == null ? null : params.rankingDescription.trim(),
      displayName: player.display_name,
      handle: player.handle,
      state: player.state ?? null,
      country: player.country ?? null,
      emailId: player.email_id ?? null,
      isManual: false,
    });
  }

  seededRows.sort((a, b) => {
    const sourcePriority = (value: TournamentSeedingSourceType): number => {
      if (value === 'national') return 0;
      if (value === 'international') return 1;
      return 2;
    };
    const bySource = sourcePriority(a.sourceType) - sourcePriority(b.sourceType);
    if (bySource !== 0) return bySource;

    if (a.sourceType === 'national') {
      const byRank = (a.rankingRank ?? Number.MAX_SAFE_INTEGER) -
        (b.rankingRank ?? Number.MAX_SAFE_INTEGER);
      if (byRank !== 0) return byRank;
    }

    return a.displayName.localeCompare(b.displayName, undefined, {
      sensitivity: 'base',
    });
  });

  for (let index = 0; index < seededRows.length; index += 1) {
    seededRows[index] = {
      ...seededRows[index],
      seed: index + 1,
    };
  }

  return {
    rows: seededRows,
    nationalCountry,
  };
}

function tournamentSeedingRowDtoFromModel(
  row: TournamentSeedingModel,
): TournamentSeedingRowDto {
  return {
    seed: row.seed,
    player_id: row.playerId,
    display_name: row.displayName,
    handle: row.handle,
    state: row.state,
    country: row.country,
    email_id: row.emailId,
    source_type: row.sourceType,
    matched_by: row.matchedBy,
    ranking_rank: row.rankingRank,
    ranking_year: row.rankingYear,
    ranking_description: row.rankingDescription,
    is_manual: row.isManual,
    updated_at: row.updatedAt,
  };
}

function tournamentSeedingPreviewRowDto(
  row: TournamentSeedingUpsertInput,
  now: string,
): TournamentSeedingRowDto {
  return {
    seed: row.seed,
    player_id: row.playerId,
    display_name: row.displayName,
    handle: row.handle,
    state: row.state ?? null,
    country: row.country ?? null,
    email_id: row.emailId ?? null,
    source_type: row.sourceType,
    matched_by: row.matchedBy,
    ranking_rank: row.rankingRank ?? null,
    ranking_year: row.rankingYear ?? null,
    ranking_description: row.rankingDescription ?? null,
    is_manual: row.isManual ?? false,
    updated_at: now,
  };
}

function summarizeTournamentSeedingRows(
  rows: TournamentSeedingRowDto[],
): TournamentSeedingSummaryDto {
  let nationalPlayers = 0;
  let internationalPlayers = 0;
  let newPlayers = 0;
  for (const row of rows) {
    if (row.source_type === 'national') {
      nationalPlayers += 1;
      continue;
    }
    if (row.source_type === 'international') {
      internationalPlayers += 1;
      continue;
    }
    newPlayers += 1;
  }
  return {
    national_players: nationalPlayers,
    international_players: internationalPlayers,
    new_players: newPlayers,
  };
}

function lastSeedingGeneratedAt(rows: TournamentSeedingRowDto[]): string | null {
  if (rows.length === 0) return null;
  let latest = rows[0].updated_at;
  for (let index = 1; index < rows.length; index += 1) {
    const value = rows[index].updated_at;
    if (Date.parse(value) > Date.parse(latest)) {
      latest = value;
    }
  }
  return latest;
}

function parseTournamentGroupingMethod(
  value: unknown,
  fallback: TournamentGroupingMethod = 'interleaved',
): TournamentGroupingMethod {
  const normalized = toText(value).trim().toLowerCase();
  if (!normalized) return fallback;
  if (normalized === 'interleaved' || normalized === 'snake') {
    return normalized;
  }
  throw new HttpError(422, 'grouping method must be interleaved or snake.');
}

function tournamentGroupCountForGeneration(
  tournament: TournamentModel,
  seededCount: number,
): number {
  const configured = Math.trunc(tournament.metadata?.numberOfGroups ?? 4);
  const base = Number.isFinite(configured) ? configured : 4;
  const clamped = Math.max(2, Math.min(64, base));
  if (seededCount <= 0) {
    return clamped;
  }
  return Math.max(2, Math.min(clamped, seededCount));
}

function buildTournamentGroupRows(params: {
  seededRows: TournamentSeedingModel[];
  groupCount: number;
  method: TournamentGroupingMethod;
}): TournamentGroupUpsertInput[] {
  const seedSortedRows = [...params.seededRows].sort((a, b) => a.seed - b.seed);
  const rows: TournamentGroupUpsertInput[] = [];

  for (let index = 0; index < seedSortedRows.length; index += 1) {
    const row = seedSortedRows[index];
    const groupIndex = index % params.groupCount;
    const groupRow = Math.trunc(index / params.groupCount);
    const effectiveGroupIndex =
      params.method === 'snake' && groupRow % 2 == 1
        ? params.groupCount - 1 - groupIndex
        : groupIndex;
    rows.push({
      playerId: row.playerId,
      seed: row.seed,
      groupNumber: effectiveGroupIndex + 1,
      groupCount: params.groupCount,
      method: params.method,
      displayName: row.displayName,
      handle: row.handle,
      state: row.state,
      country: row.country,
      emailId: row.emailId,
      sourceType: row.sourceType,
      rankingRank: row.rankingRank,
      rankingYear: row.rankingYear,
      rankingDescription: row.rankingDescription,
    });
  }
  return rows;
}

function tournamentGroupRowDtoFromModel(row: TournamentGroupModel): TournamentGroupRowDto {
  return {
    seed: row.seed,
    group_number: row.groupNumber,
    group_count: row.groupCount,
    method: row.method,
    player_id: row.playerId,
    display_name: row.displayName,
    handle: row.handle,
    state: row.state,
    country: row.country,
    email_id: row.emailId,
    source_type: row.sourceType,
    ranking_rank: row.rankingRank,
    ranking_year: row.rankingYear,
    ranking_description: row.rankingDescription,
    updated_at: row.updatedAt,
  };
}

function lastGroupsGeneratedAt(rows: TournamentGroupRowDto[]): string | null {
  if (rows.length === 0) return null;
  let latest = rows[0].updated_at;
  for (let index = 1; index < rows.length; index += 1) {
    const value = rows[index].updated_at;
    if (Date.parse(value) > Date.parse(latest)) {
      latest = value;
    }
  }
  return latest;
}

function parseGroupNumber(
  value: unknown,
  fieldName = 'group_number',
): number {
  const groupNumber = parsePositiveInt(value, fieldName);
  if (groupNumber > 256) {
    throw new HttpError(422, `${fieldName} must be <= 256.`);
  }
  return groupNumber;
}

function parseRoundOnePairingMethod(
  value: unknown,
  fallback: RoundOnePairingMethod = 'adjacent',
): RoundOnePairingMethod {
  const normalized = toText(value).trim().toLowerCase();
  if (!normalized) return fallback;
  if (normalized === 'adjacent') return 'adjacent';
  if (normalized === 'top_vs_top' || normalized === 'toptop') {
    return 'top_vs_top';
  }
  if (normalized === 'top_vs_bottom' || normalized === 'topbottom') {
    return 'top_vs_bottom';
  }
  throw new HttpError(
    422,
    'round_one_method must be adjacent, top_vs_top, or top_vs_bottom.',
  );
}

function shuffledTableNumbers(tableCount: number): number[] {
  const count = Math.max(1, Math.trunc(tableCount));
  const values = Array.from({length: count}, (_, index) => index + 1);
  for (let index = values.length - 1; index > 0; index -= 1) {
    const target = crypto.randomInt(index + 1);
    const temp = values[index];
    values[index] = values[target];
    values[target] = temp;
  }
  return values;
}

function buildRandomTableAssignments(params: {
  matchCount: number;
  tableCount: number;
}): number[] {
  const matchCount = Math.max(0, Math.trunc(params.matchCount));
  if (matchCount === 0) return [];
  const tableCount = Math.max(1, Math.trunc(params.tableCount));
  const assignments: number[] = [];
  while (assignments.length < matchCount) {
    const batch = shuffledTableNumbers(tableCount);
    for (const tableNumber of batch) {
      assignments.push(tableNumber);
      if (assignments.length === matchCount) break;
    }
  }
  return assignments;
}

function assertTournamentSetupEditable(tournament: TournamentModel): void {
  if (tournament.status === 'active' || tournament.status === 'completed') {
    throw new HttpError(
      409,
      'Tournament setup is locked after match-up generation.',
    );
  }
}

interface GroupSwissPlayerState {
  playerId: number;
  seed: number;
  displayName: string;
  matchPoints: number;
  totalScore: number;
  concededScore: number;
  opponentPoints: number;
  opponents: Set<number>;
}

function swissPlayerComparator(
  left: GroupSwissPlayerState,
  right: GroupSwissPlayerState,
): number {
  const netLeft = left.totalScore - left.concededScore;
  const netRight = right.totalScore - right.concededScore;
  return (
    right.matchPoints - left.matchPoints ||
    right.opponentPoints - left.opponentPoints ||
    netRight - netLeft ||
    right.totalScore - left.totalScore ||
    left.seed - right.seed ||
    left.displayName.localeCompare(right.displayName, undefined, {
      sensitivity: 'base',
    })
  );
}

function playersHavePlayed(
  left: GroupSwissPlayerState,
  right: GroupSwissPlayerState,
): boolean {
  return left.opponents.has(right.playerId) || right.opponents.has(left.playerId);
}

function perfectSwissMatching(
  players: GroupSwissPlayerState[],
): Array<[GroupSwissPlayerState, GroupSwissPlayerState]> | null {
  if (players.length === 0) return [];
  if (players.length % 2 === 1) return null;

  let attempts = 0;
  const maxAttempts = 200000;

  const search = (
    pool: GroupSwissPlayerState[],
  ): Array<[GroupSwissPlayerState, GroupSwissPlayerState]> | null => {
    attempts += 1;
    if (attempts > maxAttempts) return null;
    if (pool.length === 0) return [];

    let pivotIndex = -1;
    let pivotCandidates: number[] = [];
    for (let i = 0; i < pool.length; i += 1) {
      const candidates: number[] = [];
      for (let j = 0; j < pool.length; j += 1) {
        if (i === j) continue;
        if (!playersHavePlayed(pool[i], pool[j])) {
          candidates.push(j);
        }
      }
      if (candidates.length === 0) return null;
      if (pivotIndex === -1 || candidates.length < pivotCandidates.length) {
        pivotIndex = i;
        pivotCandidates = candidates;
      }
    }

    if (pivotIndex < 0 || pivotCandidates.length === 0) {
      return null;
    }

    pivotCandidates.sort((leftIndex, rightIndex) => {
      const leftCandidate = pool[leftIndex];
      const rightCandidate = pool[rightIndex];
      const leftDegree = pool.reduce((count, entry, index) => {
        if (index === pivotIndex || index === leftIndex) return count;
        return !playersHavePlayed(leftCandidate, entry) ? count + 1 : count;
      }, 0);
      const rightDegree = pool.reduce((count, entry, index) => {
        if (index === pivotIndex || index === rightIndex) return count;
        return !playersHavePlayed(rightCandidate, entry) ? count + 1 : count;
      }, 0);
      return leftDegree - rightDegree;
    });

    const pivot = pool[pivotIndex];
    for (const partnerIndex of pivotCandidates) {
      const partner = pool[partnerIndex];
      const nextPool: GroupSwissPlayerState[] = [];
      for (let index = 0; index < pool.length; index += 1) {
        if (index === pivotIndex || index === partnerIndex) continue;
        nextPool.push(pool[index]);
      }
      const next = search(nextPool);
      if (next != null) {
        return [[pivot, partner], ...next];
      }
    }
    return null;
  };

  return search(players);
}

function pairSwissPool(params: {
  players: GroupSwissPlayerState[];
}): {
  pairs: Array<[GroupSwissPlayerState, GroupSwissPlayerState]>;
  carry: GroupSwissPlayerState[];
} {
  const working = [...params.players];
  const carry: GroupSwissPlayerState[] = [];
  while (working.length > 0) {
    if (working.length % 2 === 1) {
      const floater = working.pop();
      if (floater) {
        carry.unshift(floater);
      }
    }
    if (working.length === 0) break;

    const paired = perfectSwissMatching(working);
    if (paired != null) {
      return {pairs: paired, carry};
    }

    const additionalFloater = working.pop();
    if (additionalFloater == null) break;
    carry.unshift(additionalFloater);
  }
  return {pairs: [], carry};
}

function buildRoundOnePairs(params: {
  players: TournamentGroupModel[];
  method: RoundOnePairingMethod;
}): Array<[TournamentGroupModel, TournamentGroupModel]> {
  const players = [...params.players].sort((a, b) => a.seed - b.seed);
  if (players.length < 2) {
    throw new HttpError(
      422,
      'At least 2 players are required to generate match-ups.',
    );
  }
  if (players.length % 2 === 1) {
    throw new HttpError(
      422,
      'Group player count must be even to generate pairings.',
    );
  }

  const half = Math.floor(players.length / 2);
  const pairs: Array<[TournamentGroupModel, TournamentGroupModel]> = [];
  switch (params.method) {
    case 'adjacent':
      for (let index = 0; index < players.length; index += 2) {
        pairs.push([players[index], players[index + 1]]);
      }
      return pairs;
    case 'top_vs_top':
      for (let index = 0; index < half; index += 1) {
        pairs.push([players[index], players[index + half]]);
      }
      return pairs;
    case 'top_vs_bottom':
      for (let index = 0; index < half; index += 1) {
        pairs.push([players[index], players[players.length - 1 - index]]);
      }
      return pairs;
  }
}

function buildSwissPairs(params: {
  players: TournamentGroupModel[];
  historicalMatches: MatchRecord[];
}): Array<[TournamentGroupModel, TournamentGroupModel]> {
  const sortedPlayers = [...params.players].sort((a, b) => a.seed - b.seed);
  const stateByPlayerId = new Map<number, GroupSwissPlayerState>();
  for (const player of sortedPlayers) {
    stateByPlayerId.set(player.playerId, {
      playerId: player.playerId,
      seed: player.seed,
      displayName: player.displayName,
      matchPoints: 0,
      totalScore: 0,
      concededScore: 0,
      opponentPoints: 0,
      opponents: new Set<number>(),
    });
  }

  for (const match of params.historicalMatches) {
    if (match.confirmed_score1 == null || match.confirmed_score2 == null) continue;
    const left = stateByPlayerId.get(match.player1_id);
    const right = stateByPlayerId.get(match.player2_id);
    if (left == null || right == null) continue;

    const [leftPoints, rightPoints] = matchPoints(
      match.confirmed_score1,
      match.confirmed_score2,
    );
    left.matchPoints += leftPoints;
    right.matchPoints += rightPoints;
    left.totalScore += match.confirmed_score1;
    right.totalScore += match.confirmed_score2;
    left.concededScore += match.confirmed_score2;
    right.concededScore += match.confirmed_score1;
    left.opponents.add(right.playerId);
    right.opponents.add(left.playerId);
  }

  for (const player of stateByPlayerId.values()) {
    let opponentPoints = 0;
    for (const opponentId of player.opponents) {
      opponentPoints += stateByPlayerId.get(opponentId)?.matchPoints ?? 0;
    }
    player.opponentPoints = opponentPoints;
  }

  const bracketByPoints = new Map<number, GroupSwissPlayerState[]>();
  for (const player of stateByPlayerId.values()) {
    const bucket = bracketByPoints.get(player.matchPoints) ?? [];
    bucket.push(player);
    bracketByPoints.set(player.matchPoints, bucket);
  }
  const bracketScores = [...bracketByPoints.keys()].sort((a, b) => b - a);

  const resultPairs: Array<[GroupSwissPlayerState, GroupSwissPlayerState]> = [];
  let carry: GroupSwissPlayerState[] = [];
  for (const score of bracketScores) {
    const bucket = [...(bracketByPoints.get(score) ?? [])].sort(
      swissPlayerComparator,
    );
    const pool = [...carry, ...bucket].sort(swissPlayerComparator);
    const paired = pairSwissPool({players: pool});
    resultPairs.push(...paired.pairs);
    carry = paired.carry;
  }

  if (carry.length > 0) {
    if (carry.length % 2 === 1) {
      throw new HttpError(
        422,
        'Unable to pair all players without repeats. Manual override required.',
      );
    }
    const finalPairs = perfectSwissMatching(carry);
    if (finalPairs == null) {
      throw new HttpError(
        422,
        'Unable to pair all players without repeats. Manual override required.',
      );
    }
    resultPairs.push(...finalPairs);
  }

  const modelByPlayerId = new Map<number, TournamentGroupModel>(
    sortedPlayers.map((player) => [player.playerId, player]),
  );
  return resultPairs.map(([left, right]) => {
    const leftModel = modelByPlayerId.get(left.playerId);
    const rightModel = modelByPlayerId.get(right.playerId);
    if (leftModel == null || rightModel == null) {
      throw new HttpError(500, 'Unable to resolve players for Swiss pairing.');
    }
    return [leftModel, rightModel];
  });
}

async function fetchTournamentGroupAssignments(
  tournamentId: number,
): Promise<Map<number, TournamentGroupModel[]>> {
  const grouped = new Map<number, TournamentGroupModel[]>();
  const rows = await tournamentGroupsRepository.listByTournament(tournamentId);
  for (const row of rows) {
    const bucket = grouped.get(row.groupNumber) ?? [];
    bucket.push(row);
    grouped.set(row.groupNumber, bucket);
  }
  for (const bucket of grouped.values()) {
    bucket.sort((a, b) => a.seed - b.seed);
  }
  return grouped;
}

function groupMatchupSummary(params: {
  groupNumber: number;
  playerCount: number;
  matches: MatchRecord[];
  maxRounds: number;
}): GroupMatchupSummaryDto {
  const currentRound =
    params.matches.length == 0
      ? 0
      : Math.max(...params.matches.map((match) => match.round_number));
  const currentRoundMatches = currentRound == 0
    ? []
    : params.matches.filter((match) => match.round_number === currentRound);
  const pendingMatches = currentRoundMatches.filter(
    (match) => match.confirmed_score1 == null || match.confirmed_score2 == null,
  ).length;
  const completedMatches = currentRoundMatches.length - pendingMatches;
  return {
    group_number: params.groupNumber,
    player_count: params.playerCount,
    current_round: currentRound,
    max_rounds: params.maxRounds,
    pending_matches: pendingMatches,
    completed_matches: completedMatches,
  };
}

async function deleteMatchesByIds(matchIds: number[]): Promise<number> {
  if (matchIds.length === 0) return 0;
  const deletedIds = [...new Set(matchIds.map((id) => Math.trunc(id)))].filter(
    (id) => id > 0,
  );
  if (deletedIds.length === 0) return 0;

  await deleteDocumentRefs(
    deletedIds.map((id) => db.collection(COLLECTIONS.matches).doc(String(id))),
  );

  const scoreSnapshot = await db.collection(COLLECTIONS.scores).get();
  const scoreRefs = scoreSnapshot.docs
    .filter((doc) => deletedIds.includes(toInt((doc.data() ?? {}).match_id, 0)))
    .map((doc) => doc.ref);
  await deleteDocumentRefs(scoreRefs);

  const confirmations = await db.collection(COLLECTIONS.scoreConfirmations).get();
  const confirmationRefs = confirmations.docs
    .filter((doc) => deletedIds.includes(toInt((doc.data() ?? {}).match_id, 0)))
    .map((doc) => doc.ref);
  await deleteDocumentRefs(confirmationRefs);

  return deletedIds.length;
}

function parseOrderedPlayerIds(rawValue: unknown): number[] {
  if (!Array.isArray(rawValue)) {
    throw new HttpError(422, 'ordered_player_ids must be an array.');
  }
  if (rawValue.length === 0) {
    throw new HttpError(
      422,
      'ordered_player_ids must include at least one player id.',
    );
  }
  if (rawValue.length > 512) {
    throw new HttpError(
      422,
      'ordered_player_ids exceeds the max supported count (512).',
    );
  }
  const output = rawValue
    .map((entry) => parsePositiveInt(entry, 'ordered_player_ids[]'))
    .map((entry) => Math.trunc(entry));
  const seen = new Set<number>();
  for (const value of output) {
    if (seen.has(value)) {
      throw new HttpError(422, 'ordered_player_ids contains duplicates.');
    }
    seen.add(value);
  }
  return output;
}

async function resolveTournamentSeedingContext(
  tournamentId: number,
): Promise<{
  tournament: TournamentModel;
  rankingYear: number;
  rankingDescription: string;
  players: TournamentPlayerDto[];
  rankingRows: NationalRankingModel[];
  nationalCountry: string | null;
  computedRows: TournamentSeedingUpsertInput[];
}> {
  const tournament = await requireTournamentById(tournamentId);
  const rankingYear = tournament.selectedRankingYear;
  const rankingDescription = toText(tournament.selectedRankingDescription).trim();
  if (rankingYear == null || !rankingDescription) {
    throw new HttpError(
      422,
      'Select national ranking for this tournament before creating seeding.',
    );
  }

  const players = await fetchTournamentPlayers(tournamentId);
  if (players.length === 0) {
    throw new HttpError(
      422,
      'Load registered players for this tournament before creating seeding.',
    );
  }

  const rankingRows = await nationalRankingsRepository.listRows({
    rankingYear,
    rankingDescription,
  });
  if (rankingRows.length === 0) {
    throw new HttpError(
      422,
      `No ranking rows found for ${rankingYear} - ${rankingDescription}.`,
    );
  }

  const seeding = buildTournamentSeedingRows({
    players,
    rankingRows,
    rankingYear,
    rankingDescription,
  });

  return {
    tournament,
    rankingYear,
    rankingDescription,
    players,
    rankingRows,
    nationalCountry: seeding.nationalCountry,
    computedRows: seeding.rows,
  };
}

function tournamentPlayerLinkDocId(tournamentId: number, playerId: number): string {
  return `${tournamentId}_${playerId}`;
}

async function clearTournamentPlayerLinks(tournamentId: number): Promise<number> {
  let deleted = 0;
  while (true) {
    const snapshot = await db
      .collection(COLLECTIONS.tournamentPlayers)
      .where('tournament_id', '==', tournamentId)
      .limit(400)
      .get();
    if (snapshot.empty) return deleted;
    const refs = snapshot.docs.map((doc) => doc.ref);
    deleted += refs.length;
    await deleteDocumentRefs(refs);
  }
}

async function clearCollectionByTournamentId(
  collectionName: string,
  tournamentId: number,
): Promise<void> {
  while (true) {
    const snapshot = await db
      .collection(collectionName)
      .where('tournament_id', '==', tournamentId)
      .limit(400)
      .get();
    if (snapshot.empty) return;
    await deleteDocumentRefs(snapshot.docs.map((doc) => doc.ref));
  }
}

async function deleteTournamentArtifacts(tournamentId: number): Promise<void> {
  await clearTournamentPlayerLinks(tournamentId);
  await clearCollectionByTournamentId(COLLECTIONS.tournamentSeedings, tournamentId);
  await clearCollectionByTournamentId(COLLECTIONS.tournamentGroups, tournamentId);
  await clearCollectionByTournamentId(COLLECTIONS.rounds, tournamentId);
  await clearCollectionByTournamentId(COLLECTIONS.scores, tournamentId);

  const deletedMatchIds = new Set<number>();
  while (true) {
    const matchesSnapshot = await db
      .collection(COLLECTIONS.matches)
      .where('tournament_id', '==', tournamentId)
      .limit(400)
      .get();
    if (matchesSnapshot.empty) break;
    for (const doc of matchesSnapshot.docs) {
      const data = doc.data() ?? {};
      const matchId = toInt(data.id ?? doc.id, 0);
      if (matchId > 0) deletedMatchIds.add(matchId);
    }
    await deleteDocumentRefs(matchesSnapshot.docs.map((doc) => doc.ref));
  }

  if (deletedMatchIds.size > 0) {
    const confirmations = await db.collection(COLLECTIONS.scoreConfirmations).get();
    const refsToDelete = confirmations.docs
      .filter((doc) => {
        const data = doc.data() ?? {};
        const matchId = toInt(data.match_id, 0);
        return deletedMatchIds.has(matchId);
      })
      .map((doc) => doc.ref);
    await deleteDocumentRefs(refsToDelete);
  }
}

async function fetchTournamentPlayers(tournamentId: number): Promise<TournamentPlayerDto[]> {
  const snapshot = await db
    .collection(COLLECTIONS.tournamentPlayers)
    .where('tournament_id', '==', tournamentId)
    .get();
  const players = snapshot.docs
    .map((doc) => tournamentPlayerDtoFromDoc(doc))
    .filter((row): row is TournamentPlayerDto => row !== null);
  players.sort((a, b) =>
    a.display_name.localeCompare(b.display_name, undefined, {sensitivity: 'base'}),
  );
  return players;
}

async function upsertTournamentPlayerLinks(
  tournamentId: number,
  players: TournamentPlayerDto[],
): Promise<void> {
  const now = utcNow();
  for (let offset = 0; offset < players.length; offset += 350) {
    const batch = db.batch();
    const chunk = players.slice(offset, offset + 350);
    for (const player of chunk) {
      const ref = db
        .collection(COLLECTIONS.tournamentPlayers)
        .doc(tournamentPlayerLinkDocId(tournamentId, player.id));
      batch.set(
        ref,
        {
          tournament_id: tournamentId,
          player_id: player.id,
          handle: player.handle,
          display_name: player.display_name,
          state: player.state ?? null,
          country: player.country ?? null,
          email_id: player.email_id ?? null,
          registered_flag: player.registered_flag ?? false,
          t_shirt_size: player.t_shirt_size ?? null,
          fees_paid_flag: player.fees_paid_flag ?? false,
          phone_number: player.phone_number ?? null,
          updated_at: now,
          created_at: now,
        },
        {merge: true},
      );
    }
    await batch.commit();
  }
}

async function clearCollection(collectionName: string): Promise<void> {
  while (true) {
    const snapshot = await db.collection(collectionName).limit(400).get();
    if (snapshot.empty) return;

    const batch = db.batch();
    for (const doc of snapshot.docs) {
      batch.delete(doc.ref);
    }
    await batch.commit();
  }
}

async function deleteDocumentRefs(
  refs: FirebaseFirestore.DocumentReference[],
): Promise<void> {
  if (refs.length === 0) return;
  for (let offset = 0; offset < refs.length; offset += 400) {
    const batch = db.batch();
    const chunk = refs.slice(offset, offset + 400);
    for (const ref of chunk) {
      batch.delete(ref);
    }
    await batch.commit();
  }
}

function normalizeHandleSeed(value: string): string {
  return value
    .trim()
    .toLowerCase()
    .replace(/[^a-z0-9_.-]+/g, '_')
    .replace(/_+/g, '_')
    .replace(/^[_\-.]+|[_\-.]+$/g, '');
}

function handleSeedFromDisplayName(displayName: string, index: number): string {
  const normalized = normalizeHandleSeed(displayName);
  if (normalized.length >= 3) {
    return normalized.slice(0, 32);
  }
  return `player_${index + 1}`;
}

function parseOptionalPlayerText(
  value: unknown,
  fieldName: string,
  maxLength: number,
): string | undefined {
  const text = toText(value).trim();
  if (!text) return undefined;
  assertLength(text, fieldName, 1, maxLength);
  return text;
}

function parseOptionalPlayerFlag(value: unknown): boolean | undefined {
  if (value == null) return undefined;
  if (typeof value === 'string' && value.trim().length === 0) return undefined;
  return toBool(value, false);
}

function parseOptionalPlayerEmail(value: unknown): string | undefined {
  const email = parseOptionalPlayerText(value, 'email_id', 160);
  if (!email) return undefined;
  if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) {
    throw new HttpError(422, 'email_id must be a valid email address.');
  }
  return email.toLowerCase();
}

function parseTournamentSetupPlayers(rawPlayers: unknown): TournamentSetupPlayerInput[] {
  if (!Array.isArray(rawPlayers)) {
    throw new HttpError(422, 'players must be an array.');
  }

  const parsed: TournamentSetupPlayerInput[] = [];
  for (const raw of rawPlayers) {
    if (typeof raw !== 'object' || raw == null) continue;
    const payload = raw as Record<string, unknown>;

    const displayName = toText(
      payload.display_name ?? payload.displayName ?? payload.name ?? payload.player_name,
    ).trim();
    if (!displayName) continue;

    const handleHint = toText(
      payload.handle ?? payload.username ?? payload.user_id ?? payload.userId,
    ).trim();
    const password = toText(payload.password).trim();
    const state = parseOptionalPlayerText(payload.state, 'state', 80);
    const country = parseOptionalPlayerText(payload.country, 'country', 80);
    const emailId = parseOptionalPlayerEmail(
      payload.email_id ?? payload.emailId ?? payload.email,
    );
    const registeredFlag = parseOptionalPlayerFlag(
      payload.registered_flag ?? payload.registeredFlag ?? payload.registered,
    );
    const tshirtSize = parseOptionalPlayerText(
      payload.t_shirt_size ??
        payload.tshirt_size ??
        payload.tshirtSize ??
        payload.shirt_size,
      't_shirt_size',
      20,
    );
    const feesPaidFlag = parseOptionalPlayerFlag(
      payload.fees_paid_flag ?? payload.feesPaidFlag ?? payload.fees_paid,
    );
    const phoneNumber = parseOptionalPlayerText(
      payload.phone_number ?? payload.phoneNumber ?? payload.phone,
      'phone_number',
      40,
    );

    parsed.push({
      displayName,
      handleHint: handleHint || undefined,
      password: password || undefined,
      state,
      country,
      emailId,
      registeredFlag,
      tshirtSize,
      feesPaidFlag,
      phoneNumber,
    });
  }

  if (parsed.length < 2) {
    throw new HttpError(422, 'At least 2 players are required.');
  }
  if (parsed.length > 256) {
    throw new HttpError(422, 'Maximum supported player count is 256.');
  }
  return parsed;
}

function parseOptionalRankingText(
  value: unknown,
  fieldName: string,
  maxLength: number,
): string | null {
  const text = toText(value).trim();
  if (!text) return null;
  assertLength(text, fieldName, 1, maxLength);
  return text;
}

function parseOptionalRankingEmail(value: unknown): string | null {
  const email = parseOptionalRankingText(value, 'email_id', 160);
  if (!email) return null;
  if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) {
    throw new HttpError(422, 'email_id must be a valid email address.');
  }
  return email.toLowerCase();
}

function parseOptionalRankingPoints(value: unknown): number | null {
  if (value == null) return null;
  if (typeof value === 'string' && value.trim().length === 0) return null;
  return parseNumberInRange(value, 'ranking_points', 0, 1000000);
}

function parseOptionalRankingDate(value: unknown): string | null {
  const raw = toText(value).trim();
  if (!raw) return null;
  const parsed = Date.parse(raw);
  if (Number.isNaN(parsed)) {
    throw new HttpError(422, 'last_updated must be a valid date-time.');
  }
  return new Date(parsed).toISOString();
}

function parseRankingYear(value: unknown): number {
  if (value == null || (typeof value === 'string' && value.trim().length === 0)) {
    return new Date().getUTCFullYear();
  }
  const year = parsePositiveInt(value, 'ranking_year');
  if (year < 1900 || year > 3000) {
    throw new HttpError(422, 'ranking_year must be between 1900 and 3000.');
  }
  return year;
}

function parseRankingDescription(
  value: unknown,
  fieldName = 'ranking_description',
): string {
  const text = toText(value).trim();
  if (!text) {
    throw new HttpError(422, `${fieldName} is required.`);
  }
  assertLength(text, fieldName, 1, 120);
  return text;
}

function parseNationalRankingRows(
  rawRows: unknown,
  rankingDescriptionDefault?: string,
): NationalRankingUploadInput[] {
  if (!Array.isArray(rawRows)) {
    throw new HttpError(422, 'rows must be an array.');
  }
  if (rawRows.length === 0) {
    throw new HttpError(422, 'rows must include at least one ranking row.');
  }
  if (rawRows.length > 5000) {
    throw new HttpError(422, 'rows exceeds the max supported count (5000).');
  }

  const output: NationalRankingUploadInput[] = [];
  const seenByYearAndRank = new Set<string>();
  for (const raw of rawRows) {
    if (raw == null || typeof raw !== 'object') continue;
    const payload = raw as Record<string, unknown>;
    const rank = parsePositiveInt(
      payload.rank ?? payload.ranking_position ?? payload.position,
      'rank',
    );
    const playerName = toText(
      payload.player_name ?? payload.playerName ?? payload.name ?? payload.player,
    ).trim();
    assertLength(playerName, 'player_name', 1, 120);

    const rankingYear = parseRankingYear(
      payload.ranking_year ?? payload.rankingYear ?? payload.year,
    );
    const rankingDescription = parseRankingDescription(
      payload.ranking_description ??
        payload.rankingDescription ??
        payload.description ??
        rankingDescriptionDefault,
      'ranking_description',
    );
    const dedupeKey = `${rankingYear}:${rankingDescription.toLowerCase()}:${rank}`;
    if (seenByYearAndRank.has(dedupeKey)) {
      throw new HttpError(
        422,
        `Duplicate rank ${rank} found for ranking year ${rankingYear} and description "${rankingDescription}".`,
      );
    }
    seenByYearAndRank.add(dedupeKey);

    output.push({
      rank,
      playerName,
      rankingDescription,
      state: parseOptionalRankingText(payload.state, 'state', 80),
      country: parseOptionalRankingText(payload.country, 'country', 80),
      emailId: parseOptionalRankingEmail(
        payload.email_id ?? payload.emailId ?? payload.email,
      ),
      rankingPoints: parseOptionalRankingPoints(
        payload.ranking_points ?? payload.rankingPoints ?? payload.points,
      ),
      rankingYear,
      lastUpdated: parseOptionalRankingDate(
        payload.last_updated ?? payload.lastUpdated ?? payload.updated_at,
      ),
    });
  }

  if (output.length === 0) {
    throw new HttpError(422, 'rows must include at least one ranking row.');
  }
  return output;
}

async function createPlayerForTournamentSetup(params: {
  input: TournamentSetupPlayerInput;
  fallbackIndex: number;
  defaultPassword?: string;
}): Promise<{user: UserRecord; password: string}> {
  const displayName = params.input.displayName.trim();
  assertLength(displayName, 'display_name', 1, 120);

  const password = (
    params.input.password ??
    params.defaultPassword ??
    crypto.randomBytes(24).toString('hex')
  ).trim();
  assertLength(password, 'password', 6, 128);

  const baseHandleRaw =
    params.input.handleHint?.trim().length
      ? (params.input.handleHint as string)
      : handleSeedFromDisplayName(displayName, params.fallbackIndex);
  const baseHandle = normalizeHandleSeed(baseHandleRaw);
  const safeBaseHandle =
    baseHandle.length >= 3
      ? baseHandle.slice(0, 32)
      : handleSeedFromDisplayName(displayName, params.fallbackIndex);

  for (let attempt = 0; attempt < 64; attempt += 1) {
    const candidateHandle = handleWithSuffix(safeBaseHandle, attempt);
    try {
      const nameParts = splitNameParts(displayName);
      const user = await createUserWithHandle({
        handle: candidateHandle,
        email: params.input.emailId ?? null,
        displayName,
        firstName: nameParts.firstName || null,
        lastName: nameParts.lastName || null,
        password,
        role: 'player',
      });
      return {user, password};
    } catch (error) {
      if (error instanceof HttpError && error.statusCode === 409) {
        if (error.detail.toLowerCase().includes('handle')) {
          continue;
        }
        throw error;
      }
      throw error;
    }
  }

  throw new HttpError(
    500,
    `Unable to allocate handle for player "${displayName}".`,
  );
}

async function resolveTournamentUploadPlayer(params: {
  input: TournamentSetupPlayerInput;
  fallbackIndex: number;
  defaultPassword?: string;
}): Promise<{user: UserRecord; passwordAssigned: string | null}> {
  const uploadDisplayName = params.input.displayName.trim();
  const maybeRefreshExistingPlayer = async (
    existing: UserRecord,
  ): Promise<UserRecord> => {
    if (existing.role !== 'player') {
      throw new HttpError(
        422,
        `User "${existing.handle}" already exists but is not a player account.`,
      );
    }

    if (uploadDisplayName.length > 0 && uploadDisplayName !== existing.display_name) {
      const names = splitNameParts(uploadDisplayName);
      const userRef = db.collection(COLLECTIONS.users).doc(String(existing.id));
      await userRef.set(
        {
          display_name: uploadDisplayName,
          first_name: names.firstName || null,
          last_name: names.lastName || null,
          role: 'player',
        },
        {merge: true},
      );
      const updated = await fetchUserById(existing.id);
      if (updated != null) {
        return updated;
      }
    }
    return existing;
  };

  const normalizedEmail =
    params.input.emailId != null ? normalizeEmail(params.input.emailId) : '';
  if (normalizedEmail.length > 0) {
    const existingByEmail = await findUserByEmail(normalizedEmail);
    if (existingByEmail != null) {
      return {
        user: await maybeRefreshExistingPlayer(existingByEmail),
        passwordAssigned: null,
      };
    }
  }

  const handleHint = params.input.handleHint?.trim() ?? '';
  if (handleHint.length > 0) {
    const existing = await findUserByHandle(normalizeHandle(handleHint));
    if (existing != null) {
      return {
        user: await maybeRefreshExistingPlayer(existing),
        passwordAssigned: null,
      };
    }
  }

  const created = await createPlayerForTournamentSetup(params);
  return {user: created.user, passwordAssigned: created.password};
}

async function setupTournamentFromPlayers(params: {
  tournamentName: string;
  defaultPassword: string;
  metadata: TournamentSetupMetadataInput;
  players: TournamentSetupPlayerInput[];
}): Promise<TournamentSetupResultDto> {
  const tournamentName = params.tournamentName.trim();
  assertLength(tournamentName, 'tournament_name', 2, 120);
  assertLength(params.defaultPassword, 'default_password', 6, 128);
  const participantLimit =
    params.metadata.subType === 'singles'
      ? params.metadata.singlesMaxParticipants
      : params.metadata.doublesMaxTeams;
  if (params.players.length > participantLimit) {
    const limitField =
      params.metadata.subType === 'singles'
        ? 'tournament_limits_singles_max_participants'
        : 'tournament_limits_doubles_max_teams';
    throw new HttpError(
      422,
      `Uploaded participants (${params.players.length}) exceed ${limitField} (${participantLimit}).`,
    );
  }

  const now = utcNow();
  const tournament = await tournamentsRepository.create({
    name: tournamentName,
    status: 'setup',
    metadata: tournamentMetadataInputToModel(params.metadata),
    now,
  });

  const createdPlayers: TournamentSetupCredentialDto[] = [];
  const tournamentPlayers: TournamentPlayerDto[] = [];
  for (let i = 0; i < params.players.length; i += 1) {
    const inputPlayer = params.players[i];
    const created = await createPlayerForTournamentSetup({
      input: inputPlayer,
      fallbackIndex: i,
      defaultPassword: params.defaultPassword,
    });
    await syncPlayerModelFromUser(created.user, {
      playerName: inputPlayer.displayName,
      state: inputPlayer.state,
      country: inputPlayer.country,
      emailId: inputPlayer.emailId,
      registeredFlag: inputPlayer.registeredFlag,
      tshirtSize: inputPlayer.tshirtSize,
      feesPaidFlag: inputPlayer.feesPaidFlag,
      phoneNumber: inputPlayer.phoneNumber,
    });
    tournamentPlayers.push({
      ...tournamentPlayerDtoFromUser(created.user),
      state: inputPlayer.state,
      country: inputPlayer.country,
      email_id: inputPlayer.emailId,
      registered_flag: inputPlayer.registeredFlag,
      t_shirt_size: inputPlayer.tshirtSize,
      fees_paid_flag: inputPlayer.feesPaidFlag,
      phone_number: inputPlayer.phoneNumber,
    });
    createdPlayers.push({
      player_id: created.user.id,
      display_name: created.user.display_name,
      handle: created.user.handle,
      password: created.password,
    });
  }

  await upsertTournamentPlayerLinks(tournament.id, tournamentPlayers);
  await syncDomainReadModels(now, tournament.id);
  return {
    tournament: {
      id: tournament.id,
      name: tournament.name,
      status: tournament.status,
      metadata: tournamentMetadataToDto(tournament.metadata),
    },
    players_created: createdPlayers.length,
    rounds_created: 0,
    matches_created: 0,
    credentials: createdPlayers,
  };
}

async function createUserWithHandle(params: {
  handle: string;
  email?: string | null;
  displayName: string;
  firstName?: string | null;
  lastName?: string | null;
  password: string;
  role: Role;
}): Promise<UserRecord> {
  try {
    const user = await usersRepository.create({
      handle: params.handle,
      email: params.email,
      displayName: params.displayName,
      firstName: params.firstName,
      lastName: params.lastName,
      passwordHash: hashPassword(params.password),
      role: params.role,
      createdAt: utcNow(),
    });
    return userModelToRecord(user);
  } catch (error) {
    if (error instanceof Error && error.message === 'HANDLE_EXISTS') {
      throw new HttpError(409, 'Handle already exists.');
    }
    if (error instanceof Error && error.message === 'EMAIL_EXISTS') {
      throw new HttpError(409, 'Email already exists.');
    }
    throw error;
  }
}

async function createMatch(params: {
  tournamentId: number;
  groupNumber?: number | null;
  roundNumber: number;
  tableNumber: number;
  player1Id: number;
  player2Id: number;
}): Promise<MatchRecord> {
  return db.runTransaction(async (tx) => {
    const counterSnap = await tx.get(countersRef);
    const nextMatchId = toInt(counterSnap.get('next_match_id'), 1);
    const match: MatchRecord = {
      id: nextMatchId,
      tournament_id: params.tournamentId,
      group_number:
        params.groupNumber == null ? null : Math.trunc(params.groupNumber),
      round_number: params.roundNumber,
      table_number: params.tableNumber,
      player1_id: params.player1Id,
      player2_id: params.player2Id,
      confirmed_score1: null,
      confirmed_score2: null,
      confirmed_at: null,
      toss: null,
      boards: [],
      sudden_death: null,
    };

    tx.set(countersRef, {next_match_id: nextMatchId + 1}, {merge: true});
    tx.set(db.collection(COLLECTIONS.matches).doc(String(nextMatchId)), match);
    return match;
  });
}

async function fetchAllUsers(): Promise<UserRecord[]> {
  const users = await usersRepository.list();
  return users.map((user) => userModelToRecord(user)).sort((a, b) => a.id - b.id);
}

async function fetchUserById(userId: number): Promise<UserRecord | null> {
  const user = await usersRepository.findById(userId);
  return user == null ? null : userModelToRecord(user);
}

async function requireTournamentById(tournamentId: number) {
  const tournament = await tournamentsRepository.findById(tournamentId);
  if (!tournament) {
    throw new HttpError(404, 'Tournament not found.');
  }
  return tournament;
}

async function resolveTournamentId(tournamentIdInput?: unknown): Promise<number> {
  const raw = toText(tournamentIdInput).trim();
  if (raw.length > 0) {
    const tournamentId = parsePositiveInt(raw, 'tournament_id');
    await requireTournamentById(tournamentId);
    return tournamentId;
  }

  const tournaments = await tournamentsRepository.list();
  if (tournaments.length === 0) {
    const created = await tournamentsRepository.create({
      name: 'Lavi Tournament',
      status: 'setup',
      now: utcNow(),
    });
    return created.id;
  }

  const active = tournaments.find((entry) => entry.status === 'active');
  if (active) {
    return active.id;
  }

  tournaments.sort((a, b) => b.id - a.id);
  return tournaments[0].id;
}

function filterMatchesByTournament(
  matches: MatchRecord[],
  tournamentId: number,
): MatchRecord[] {
  const hasTaggedMatches = matches.some((match) => match.tournament_id != null);
  if (!hasTaggedMatches) {
    return matches;
  }
  return matches.filter((match) => match.tournament_id === tournamentId);
}

async function fetchAllMatches(tournamentId?: number): Promise<MatchRecord[]> {
  const snapshot = await db.collection(COLLECTIONS.matches).get();
  const allMatches = snapshot.docs
    .map((doc) => toMatchRecord(doc))
    .filter((row): row is MatchRecord => row !== null);
  const matches =
    tournamentId == null
      ? allMatches
      : filterMatchesByTournament(allMatches, tournamentId);
  matches.sort(
    (a, b) =>
      a.round_number - b.round_number ||
      a.table_number - b.table_number ||
      a.id - b.id,
  );
  return matches;
}

async function fetchMatchById(matchId: number): Promise<MatchRecord | null> {
  const snap = await db.collection(COLLECTIONS.matches).doc(String(matchId)).get();
  return toMatchRecord(snap);
}

async function fetchAllConfirmations(): Promise<ScoreConfirmationRecord[]> {
  const snapshot = await db.collection(COLLECTIONS.scoreConfirmations).get();
  return snapshot.docs
    .map((doc) => toScoreConfirmationRecord(doc))
    .filter((row): row is ScoreConfirmationRecord => row !== null);
}

async function fetchConfirmationsForMatch(
  matchId: number,
): Promise<ScoreConfirmationRecord[]> {
  const snapshot = await db
    .collection(COLLECTIONS.scoreConfirmations)
    .where('match_id', '==', matchId)
    .get();
  return snapshot.docs
    .map((doc) => toScoreConfirmationRecord(doc))
    .filter((row): row is ScoreConfirmationRecord => row !== null)
    .sort((a, b) => a.player_id - b.player_id);
}

function parseFirebaseRoleHint(value: unknown): Role | undefined {
  const normalized = toText(value).trim().toLowerCase();
  if (normalized === 'player') return 'player';
  if (normalized === 'viewer') return 'viewer';
  return undefined;
}

async function findUserByFirebaseUid(uid: string): Promise<UserRecord | null> {
  const identityRef = db.collection(COLLECTIONS.firebaseIdentities).doc(uid);
  const identitySnap = await identityRef.get();
  if (!identitySnap.exists) return null;

  const userId = toInt((identitySnap.data() ?? {}).user_id, 0);
  if (userId < 1) return null;
  const user = await fetchUserById(userId);
  if (user) return user;

  await identityRef.delete().catch(() => undefined);
  return null;
}

async function linkFirebaseUid(uid: string, userId: number): Promise<void> {
  await db.collection(COLLECTIONS.firebaseIdentities).doc(uid).set(
    {
      uid,
      user_id: userId,
      updated_at: utcNow(),
      created_at: utcNow(),
    },
    {merge: true},
  );
}

async function resolveFirebaseUser(params: {
  uid: string;
  displayName?: string;
  email?: string;
  handleHint?: string;
  roleHint?: Role;
}): Promise<UserRecord> {
  const existingByUid = await findUserByFirebaseUid(params.uid);
  if (existingByUid) {
    return existingByUid;
  }

  const normalizedEmail = normalizeEmail(toText(params.email));
  if (normalizedEmail.length > 0 && isValidEmail(normalizedEmail)) {
    const existingByEmail = await findUserByEmail(normalizedEmail);
    if (existingByEmail != null) {
      await linkFirebaseUid(params.uid, existingByEmail.id);
      return existingByEmail;
    }
  }

  const displayName =
    toText(params.displayName).trim() ||
    (toText(params.email).split('@')[0] ?? '').trim() ||
    'SRR Player';
  const role = params.roleHint === 'viewer' ? 'viewer' : 'player';
  const baseHandle =
    normalizeHandleSeed(params.handleHint ?? '') ||
    normalizeHandleSeed((params.email ?? '').split('@')[0] ?? '') ||
    normalizeHandleSeed(displayName) ||
    `player_${params.uid.slice(0, 8)}`;

  for (let attempt = 0; attempt < 64; attempt += 1) {
    const candidate = handleWithSuffix(baseHandle, attempt);
    try {
      const names = splitNameParts(displayName);
      const created = await createUserWithHandle({
        handle: candidate,
        email: normalizedEmail || null,
        displayName,
        firstName: names.firstName || null,
        lastName: names.lastName || null,
        password: crypto.randomBytes(32).toString('hex'),
        role,
      });
      await linkFirebaseUid(params.uid, created.id);
      return created;
    } catch (error) {
      if (error instanceof HttpError && error.statusCode === 409) {
        continue;
      }
      throw error;
    }
  }

  throw new HttpError(500, 'Unable to provision Firebase identity user.');
}

async function userFromFirebaseBearerToken(
  token: string,
  hints?: {
    displayName?: string;
    handleHint?: string;
    roleHint?: Role;
  },
): Promise<UserRecord | null> {
  let decoded: DecodedIdToken;
  try {
    decoded = await getAuth().verifyIdToken(token);
  } catch {
    return null;
  }

  return resolveFirebaseUser({
    uid: decoded.uid,
    displayName: hints?.displayName || decoded.name || undefined,
    email: decoded.email || undefined,
    handleHint: hints?.handleHint,
    roleHint: hints?.roleHint,
  });
}

async function optionalUser(req: Request): Promise<UserRecord | null> {
  const token = tokenFromHeader(req.header('authorization') ?? undefined);
  if (!token) return null;
  return userFromFirebaseBearerToken(token);
}

async function requireUser(req: Request): Promise<UserRecord> {
  const token = tokenFromHeader(req.header('authorization') ?? undefined);
  if (!token) {
    throw new HttpError(401, 'Missing bearer token.');
  }

  const firebaseUser = await userFromFirebaseBearerToken(token);
  if (firebaseUser) {
    return firebaseUser;
  }
  throw new HttpError(401, 'Invalid Firebase ID token.');
}

async function requireAdminUser(req: Request): Promise<UserRecord> {
  const user = await requireUser(req);
  if (user.role !== 'admin') {
    throw new HttpError(
      403,
      'Only admin accounts can access this feature.',
    );
  }
  return user;
}

async function syncPlayerModelFromUser(
  user: UserRecord,
  profile?: {
    playerName?: string;
    state?: string;
    country?: string;
    emailId?: string;
    registeredFlag?: boolean;
    tshirtSize?: string;
    feesPaidFlag?: boolean;
    phoneNumber?: string;
  },
): Promise<void> {
  await playersRepository.upsertFromUser(userRecordToModel(user), profile);
}

async function syncDomainReadModels(
  now: string,
  tournamentId?: number,
): Promise<void> {
  const tournament =
    tournamentId == null
      ? await tournamentsRepository.ensureDefault('Swiss Round Robin', now)
      : await requireTournamentById(tournamentId);
  const [users, matches, confirmations] = await Promise.all([
    fetchAllUsers(),
    fetchAllMatches(tournament.id),
    fetchAllConfirmations(),
  ]);

  for (const user of users) {
    if (user.role !== 'player') continue;
    await syncPlayerModelFromUser(user);
  }

  const roundCompletion = new Map<number, boolean>();
  for (const match of matches) {
    const complete =
      match.confirmed_score1 != null && match.confirmed_score2 != null;
    if (!roundCompletion.has(match.round_number)) {
      roundCompletion.set(match.round_number, complete);
      continue;
    }
    if (!complete) {
      roundCompletion.set(match.round_number, false);
    }
  }

  const roundSummaries = [...roundCompletion.entries()]
    .sort((a, b) => a[0] - b[0])
    .map(([roundNumber, isComplete]) => ({roundNumber, isComplete}));

  const rounds = await roundsRepository.syncFromRoundSummaries({
    tournamentId: tournament.id,
    rounds: roundSummaries,
    now,
  });
  const roundIdByRoundNumber = new Map<number, number>(
    rounds.map((round) => [round.roundNumber, round.id]),
  );

  const confirmationsByMatch = new Map<number, ScoreConfirmationRecord[]>();
  for (const confirmation of confirmations) {
    const bucket = confirmationsByMatch.get(confirmation.match_id) ?? [];
    bucket.push(confirmation);
    confirmationsByMatch.set(confirmation.match_id, bucket);
  }

  const scoreInputs = matches.map((match) => {
    const matchConfirmations = confirmationsByMatch.get(match.id) ?? [];
    const distinctConfirmations = new Set(
      matchConfirmations.map((row) => confirmationSignature(row)),
    ).size;
    return {
      matchId: match.id,
      roundNumber: match.round_number,
      tableNumber: match.table_number,
      player1Id: match.player1_id,
      player2Id: match.player2_id,
      confirmedScore1: match.confirmed_score1,
      confirmedScore2: match.confirmed_score2,
      confirmations: matchConfirmations.length,
      distinctConfirmations,
    };
  });

  await scoresRepository.syncFromMatches({
    tournamentId: tournament.id,
    roundIdByRoundNumber,
    scores: scoreInputs,
    now,
  });
}

async function seedDemoData(force: boolean): Promise<{
  players: number;
  matches: number;
  seeded: number;
}>;
async function seedDemoData(
  force: boolean,
  includeFixtures: boolean,
): Promise<{
  players: number;
  matches: number;
  seeded: number;
}>;
async function seedDemoData(
  force: boolean,
  includeFixtures = true,
): Promise<{
  players: number;
  matches: number;
  seeded: number;
}> {
  if (force) {
    await clearCollection(COLLECTIONS.scores);
    await clearCollection(COLLECTIONS.rounds);
    await clearCollection(COLLECTIONS.tournaments);
    await clearCollection(COLLECTIONS.players);
    await clearCollection(COLLECTIONS.nationalRankings);
    await clearCollection(COLLECTIONS.tournamentPlayers);
    await clearCollection(COLLECTIONS.scoreConfirmations);
    await clearCollection(COLLECTIONS.matches);
    await clearCollection(COLLECTIONS.firebaseIdentities);
    await clearCollection(COLLECTIONS.userEmails);
    await clearCollection(COLLECTIONS.users);
    await countersRef.delete().catch(() => undefined);
  }

  const existingUsers = await db.collection(COLLECTIONS.users).get();
  if (!existingUsers.empty) {
    const playersCount = existingUsers.docs.filter((doc) => {
      const role = toText((doc.data() ?? {}).role);
      return role === 'player';
    }).length;
    const matchesCount = (await db.collection(COLLECTIONS.matches).get()).size;
    await syncDomainReadModels(utcNow());
    return {players: playersCount, matches: matchesCount, seeded: 0};
  }

  const demoUsers: Array<{
    handle: string;
    displayName: string;
    password: string;
    role: Role;
  }> = [
    {
      handle: runtimeConfig.demoAdminHandle,
      displayName: 'Tournament Admin',
      password: runtimeConfig.demoAdminPassword,
      role: 'admin',
    },
    {handle: 'alice', displayName: 'Alice Mercer', password: 'pass123', role: 'player'},
    {handle: 'bob', displayName: 'Bob Singh', password: 'pass123', role: 'player'},
    {handle: 'carla', displayName: 'Carla Diaz', password: 'pass123', role: 'player'},
    {handle: 'diego', displayName: 'Diego Kim', password: 'pass123', role: 'player'},
    {handle: 'viewer', displayName: 'Live Viewer', password: 'viewer123', role: 'viewer'},
  ];

  const createdUsers: UserRecord[] = [];
  for (const user of demoUsers) {
    const nameParts = splitNameParts(user.displayName);
    createdUsers.push(
      await createUserWithHandle({
        handle: user.handle,
        displayName: user.displayName,
        firstName: nameParts.firstName || null,
        lastName: nameParts.lastName || null,
        password: user.password,
        role: user.role,
      }),
    );
  }

  const playerIds = createdUsers
    .filter((user) => user.role === 'player')
    .map((user) => user.id)
    .sort((a, b) => a - b);

  const now = utcNow();
  const seededTournament = await tournamentsRepository.create({
    name: 'Lavi Tournament',
    status: includeFixtures ? 'active' : 'setup',
    now,
  });

  if (!includeFixtures) {
    for (const user of createdUsers) {
      await syncPlayerModelFromUser(user);
    }

    await countersRef.set(
      {
        next_user_id: createdUsers.length + 1,
        next_match_id: 1,
        next_round_id: 1,
      },
      {merge: true},
    );
    return {players: playerIds.length, matches: 0, seeded: 1};
  }

  const rounds = generateRoundRobin(playerIds);

  let matchesCreated = 0;
  for (let roundIndex = 0; roundIndex < rounds.length; roundIndex += 1) {
    const fixtures = rounds[roundIndex];
    for (let tableIndex = 0; tableIndex < fixtures.length; tableIndex += 1) {
      const [player1Id, player2Id] = fixtures[tableIndex];
      await createMatch({
        tournamentId: seededTournament.id,
        roundNumber: roundIndex + 1,
        tableNumber: tableIndex + 1,
        player1Id,
        player2Id,
      });
      matchesCreated += 1;
    }
  }

  await syncDomainReadModels(utcNow(), seededTournament.id);
  return {players: playerIds.length, matches: matchesCreated, seeded: 1};
}

function buildStandings(
  players: UserRecord[],
  matches: MatchRecord[],
  upToRound: number | null,
): StandingRowDto[] {
  const stats = new Map<
    number,
    {
      player_id: number;
      handle: string;
      display_name: string;
      played: number;
      wins: number;
      draws: number;
      losses: number;
      goals_for: number;
      goals_against: number;
      points: number;
      round_points: number;
    }
  >();

  for (const player of players) {
    if (player.role !== 'player') continue;
    stats.set(player.id, {
      player_id: player.id,
      handle: player.handle,
      display_name: player.display_name,
      played: 0,
      wins: 0,
      draws: 0,
      losses: 0,
      goals_for: 0,
      goals_against: 0,
      points: 0,
      round_points: 0,
    });
  }

  for (const match of matches) {
    if (match.confirmed_score1 == null || match.confirmed_score2 == null) continue;
    if (upToRound != null && match.round_number > upToRound) continue;

    const p1 = stats.get(match.player1_id);
    const p2 = stats.get(match.player2_id);
    if (!p1 || !p2) continue;

    const score1 = match.confirmed_score1;
    const score2 = match.confirmed_score2;
    const [p1Points, p2Points] = matchPoints(score1, score2);

    p1.played += 1;
    p2.played += 1;
    p1.goals_for += score1;
    p1.goals_against += score2;
    p2.goals_for += score2;
    p2.goals_against += score1;
    p1.points += p1Points;
    p2.points += p2Points;

    if (upToRound != null && match.round_number === upToRound) {
      p1.round_points += p1Points;
      p2.round_points += p2Points;
    }

    if (score1 > score2) {
      p1.wins += 1;
      p2.losses += 1;
    } else if (score2 > score1) {
      p2.wins += 1;
      p1.losses += 1;
    } else {
      p1.draws += 1;
      p2.draws += 1;
    }
  }

  const rows = [...stats.values()];
  rows.sort(
    (a, b) =>
      b.points - a.points ||
      (b.goals_for - b.goals_against) - (a.goals_for - a.goals_against) ||
      b.goals_for - a.goals_for ||
      a.display_name.localeCompare(b.display_name, undefined, {sensitivity: 'base'}),
  );

  return rows.map((row, index) => ({
    position: index + 1,
    player_id: row.player_id,
    handle: row.handle,
    display_name: row.display_name,
    played: row.played,
    wins: row.wins,
    draws: row.draws,
    losses: row.losses,
    goals_for: row.goals_for,
    goals_against: row.goals_against,
    goal_difference: row.goals_for - row.goals_against,
    sum_round_points: row.goals_for,
    sum_opponent_round_points: row.goals_against,
    net_game_points_difference: row.goals_for - row.goals_against,
    round_points: row.round_points,
    points: row.points,
  }));
}

async function fetchMatchDtos(
  userId: number | null,
  tournamentId: number,
): Promise<MatchDto[]> {
  const [users, players, matches, confirmations] = await Promise.all([
    fetchAllUsers(),
    playersRepository.list(),
    fetchAllMatches(tournamentId),
    fetchAllConfirmations(),
  ]);

  const usersById = new Map<number, UserRecord>(users.map((user) => [user.id, user]));
  const playersByUserId = new Map<number, PlayerModel>(
    players.map((player) => [player.userId, player]),
  );
  const confirmationsByMatch = new Map<number, ScoreConfirmationRecord[]>();
  const myConfirmationByMatch = new Map<number, ScoreConfirmationRecord>();

  for (const confirmation of confirmations) {
    const bucket = confirmationsByMatch.get(confirmation.match_id) ?? [];
    bucket.push(confirmation);
    confirmationsByMatch.set(confirmation.match_id, bucket);

    if (userId != null && confirmation.player_id === userId) {
      myConfirmationByMatch.set(confirmation.match_id, confirmation);
    }
  }

  return matches.map((match) => {
    const player1 = usersById.get(match.player1_id);
    const player2 = usersById.get(match.player2_id);
    if (!player1 || !player2) {
      throw new HttpError(500, `Missing player data for match ${match.id}.`);
    }
    const player1Profile = playersByUserId.get(player1.id);
    const player2Profile = playersByUserId.get(player2.id);

    const matchConfirmations = confirmationsByMatch.get(match.id) ?? [];
    const distinctConfirmations = new Set(
      matchConfirmations.map((row) => confirmationSignature(row)),
    ).size;
    const confirmed =
      match.confirmed_score1 != null && match.confirmed_score2 != null;

    const status: MatchStatus = confirmed
      ? 'confirmed'
      : distinctConfirmations > 1
      ? 'disputed'
      : 'pending';

    const myConfirmation = myConfirmationByMatch.get(match.id);

    return {
      id: match.id,
      tournament_id: match.tournament_id,
      group_number: match.group_number,
      round_number: match.round_number,
      table_number: match.table_number,
      player1: {
        id: player1.id,
        handle: player1.handle,
        display_name: player1.display_name,
        country: player1Profile?.country ?? null,
      },
      player2: {
        id: player2.id,
        handle: player2.handle,
        display_name: player2.display_name,
        country: player2Profile?.country ?? null,
      },
      status,
      confirmed_score1: match.confirmed_score1,
      confirmed_score2: match.confirmed_score2,
      confirmations: matchConfirmations.length,
      my_confirmation: myConfirmation
        ? {score1: myConfirmation.score1, score2: myConfirmation.score2}
        : null,
      toss: match.toss,
      boards: match.boards,
      sudden_death: match.sudden_death,
    };
  });
}

async function fetchRounds(
  userId: number | null,
  tournamentId: number,
): Promise<RoundDto[]> {
  const matches = await fetchMatchDtos(userId, tournamentId);
  const grouped = new Map<number, MatchDto[]>();

  for (const match of matches) {
    const bucket = grouped.get(match.round_number) ?? [];
    bucket.push(match);
    grouped.set(match.round_number, bucket);
  }

  const rounds = [...grouped.entries()]
    .sort((a, b) => a[0] - b[0])
    .map(([roundNumber, roundMatches]) => ({
      round_number: roundNumber,
      is_complete: roundMatches.every((match) => match.status === 'confirmed'),
      matches: roundMatches,
    }));

  return rounds;
}

async function fetchStandingsPlayers(
  tournamentId: number,
): Promise<UserRecord[]> {
  const [users, tournamentPlayers] = await Promise.all([
    fetchAllUsers(),
    fetchTournamentPlayers(tournamentId),
  ]);

  if (tournamentPlayers.length === 0) {
    return users.filter((user) => user.role === 'player');
  }

  const allowedIds = new Set<number>(tournamentPlayers.map((entry) => entry.id));
  return users.filter((user) => user.role === 'player' && allowedIds.has(user.id));
}

async function fetchStandings(
  upToRound: number | null,
  tournamentId: number,
): Promise<StandingRowDto[]> {
  const [players, matches] = await Promise.all([
    fetchStandingsPlayers(tournamentId),
    fetchAllMatches(tournamentId),
  ]);
  return buildStandings(players, matches, upToRound);
}

async function fetchRoundPoints(tournamentId: number): Promise<RoundPointsDto[]> {
  const [players, matches] = await Promise.all([
    fetchStandingsPlayers(tournamentId),
    fetchAllMatches(tournamentId),
  ]);
  players.sort((a, b) =>
    a.display_name.localeCompare(b.display_name, undefined, {sensitivity: 'base'}),
  );

  const roundNumbers = [...new Set(matches.map((match) => match.round_number))].sort(
    (a, b) => a - b,
  );

  return roundNumbers.map((roundNumber) => {
    const totals = new Map<number, number>(players.map((player) => [player.id, 0]));
    const confirmedMatches = matches.filter(
      (match) =>
        match.round_number === roundNumber &&
        match.confirmed_score1 != null &&
        match.confirmed_score2 != null,
    );

    for (const match of confirmedMatches) {
      totals.set(
        match.player1_id,
        (totals.get(match.player1_id) ?? 0) + (match.confirmed_score1 as number),
      );
      totals.set(
        match.player2_id,
        (totals.get(match.player2_id) ?? 0) + (match.confirmed_score2 as number),
      );
    }

    const pointsRows = players.map((player) => ({
      player_id: player.id,
      display_name: player.display_name,
      points: totals.get(player.id) ?? 0,
    }));
    pointsRows.sort(
      (a, b) =>
        b.points - a.points ||
        a.display_name.localeCompare(b.display_name, undefined, {sensitivity: 'base'}),
    );

    return {
      round_number: roundNumber,
      points: pointsRows,
    };
  });
}

async function fetchStandingsByRound(
  tournamentId: number,
): Promise<RoundStandingsDto[]> {
  const [matches] = await Promise.all([fetchAllMatches(tournamentId)]);
  const roundNumbers = [...new Set(matches.map((match) => match.round_number))].sort(
    (a, b) => a - b,
  );

  const output: RoundStandingsDto[] = [];
  for (const roundNumber of roundNumbers) {
    const isComplete = matches
      .filter((match) => match.round_number === roundNumber)
      .every(
        (match) =>
          match.confirmed_score1 != null && match.confirmed_score2 != null,
      );
    output.push({
      round_number: roundNumber,
      is_complete: isComplete,
      standings: await fetchStandings(roundNumber, tournamentId),
    });
  }
  return output;
}

async function fetchCurrentRound(tournamentId: number): Promise<number | null> {
  const matches = await fetchAllMatches(tournamentId);
  const pendingRounds = matches
    .filter((match) => match.confirmed_score1 == null || match.confirmed_score2 == null)
    .map((match) => match.round_number);

  if (pendingRounds.length > 0) {
    return Math.min(...pendingRounds);
  }

  if (matches.length > 0) {
    return Math.max(...matches.map((match) => match.round_number));
  }
  return null;
}

async function confirmScoresIfConsensus(matchId: number): Promise<void> {
  const matchRef = db.collection(COLLECTIONS.matches).doc(String(matchId));
  await db.runTransaction(async (tx) => {
    const matchSnap = await tx.get(matchRef);
    const match = toMatchRecord(matchSnap);
    if (!match) return;
    if (match.confirmed_score1 != null && match.confirmed_score2 != null) return;

    const confirmationsQuery = db
      .collection(COLLECTIONS.scoreConfirmations)
      .where('match_id', '==', matchId);
    const confirmationsSnap = await tx.get(confirmationsQuery);
    const confirmations = confirmationsSnap.docs
      .map((doc) => toScoreConfirmationRecord(doc))
      .filter((row): row is ScoreConfirmationRecord => row !== null)
      .sort((a, b) => a.player_id - b.player_id);

    if (confirmations.length < 2) return;

    const first = confirmations[0];
    const signature = confirmationSignature(first);
    const consensus = confirmations.every(
      (row) => confirmationSignature(row) === signature,
    );
    if (!consensus) return;

    tx.update(matchRef, {
      confirmed_score1: first.score1,
      confirmed_score2: first.score2,
      confirmed_at: utcNow(),
      toss: first.toss,
      boards: first.boards,
      sudden_death: first.sudden_death,
    });
  });
}

async function fetchMatchDto(matchId: number, userId: number | null): Promise<MatchDto | null> {
  const [match, users, players, confirmations] = await Promise.all([
    fetchMatchById(matchId),
    fetchAllUsers(),
    playersRepository.list(),
    fetchConfirmationsForMatch(matchId),
  ]);
  if (!match) return null;

  const usersById = new Map<number, UserRecord>(users.map((user) => [user.id, user]));
  const playersByUserId = new Map<number, PlayerModel>(
    players.map((player) => [player.userId, player]),
  );
  const player1 = usersById.get(match.player1_id);
  const player2 = usersById.get(match.player2_id);
  if (!player1 || !player2) {
    throw new HttpError(500, `Missing player data for match ${match.id}.`);
  }
  const player1Profile = playersByUserId.get(player1.id);
  const player2Profile = playersByUserId.get(player2.id);

  const distinctConfirmations = new Set(
    confirmations.map((row) => confirmationSignature(row)),
  ).size;
  const status: MatchStatus =
    match.confirmed_score1 != null && match.confirmed_score2 != null
      ? 'confirmed'
      : distinctConfirmations > 1
      ? 'disputed'
      : 'pending';

  const myConfirmation =
    userId == null
      ? null
      : confirmations.find((row) => row.player_id === userId) ?? null;

  return {
    id: match.id,
    tournament_id: match.tournament_id,
    group_number: match.group_number,
    round_number: match.round_number,
    table_number: match.table_number,
    player1: {
      id: player1.id,
      handle: player1.handle,
      display_name: player1.display_name,
      country: player1Profile?.country ?? null,
    },
    player2: {
      id: player2.id,
      handle: player2.handle,
      display_name: player2.display_name,
      country: player2Profile?.country ?? null,
    },
    status,
    confirmed_score1: match.confirmed_score1,
    confirmed_score2: match.confirmed_score2,
    confirmations: confirmations.length,
    my_confirmation: myConfirmation
      ? {score1: myConfirmation.score1, score2: myConfirmation.score2}
      : null,
    toss: match.toss,
    boards: match.boards,
    sudden_death: match.sudden_death,
  };
}

async function findUserByHandle(handle: string): Promise<UserRecord | null> {
  const user = await usersRepository.findByHandle(normalizeHandle(handle));
  return user == null ? null : userModelToRecord(user);
}

async function findUserByEmail(email: string): Promise<UserRecord | null> {
  const user = await usersRepository.findByEmail(normalizeEmail(email));
  return user == null ? null : userModelToRecord(user);
}

function assertLength(value: string, field: string, min: number, max: number): void {
  if (value.length < min || value.length > max) {
    throw new HttpError(422, `${field} must be between ${min} and ${max} characters.`);
  }
}

function sendError(res: Response, statusCode: number, detail: string): void {
  res.status(statusCode).json({detail});
}

type AsyncRoute = (req: Request, res: Response) => Promise<void>;
function route(handler: AsyncRoute) {
  return (req: Request, res: Response, next: NextFunction) => {
    handler(req, res).catch(next);
  };
}

function objectEntries(source: unknown): Array<[string, string]> {
  if (source == null || typeof source !== 'object') return [];
  const out: Array<[string, string]> = [];

  for (const [key, rawValue] of Object.entries(source as Record<string, unknown>)) {
    if (rawValue == null) continue;
    if (Array.isArray(rawValue)) {
      for (const entry of rawValue) {
        if (entry == null) continue;
        out.push([key, String(entry)]);
      }
      continue;
    }
    out.push([key, String(rawValue)]);
  }

  return out;
}

function splitNameParts(displayName: string): {firstName: string; lastName: string} {
  const normalized = displayName.trim().replace(/\s+/g, ' ');
  const parts = normalized.split(' ').filter((entry) => entry.length > 0);
  if (parts.length === 0) {
    return {firstName: '', lastName: ''};
  }
  if (parts.length === 1) {
    return {firstName: parts[0], lastName: ''};
  }
  return {
    firstName: parts[0],
    lastName: parts.slice(1).join(' '),
  };
}

async function ensureConfiguredBootstrapAdmin(): Promise<void> {
  const handleRaw = runtimeConfig.bootstrapAdminHandle.trim();
  const password = runtimeConfig.bootstrapAdminPassword;
  if (handleRaw.length === 0 || password.length === 0) {
    return;
  }

  const handle = normalizeHandle(handleRaw);
  assertLength(handle, 'BOOTSTRAP_ADMIN_HANDLE', 3, 32);
  if (!/^[a-zA-Z0-9_.-]+$/.test(handle)) {
    throw new HttpError(
      500,
      'BOOTSTRAP_ADMIN_HANDLE must match ^[a-zA-Z0-9_.-]+$.',
    );
  }
  assertLength(password, 'BOOTSTRAP_ADMIN_PASSWORD', 8, 128);

  const existing = await findUserByHandle(handle);
  if (existing != null) {
    return;
  }

  await createUserWithHandle({
    handle,
    displayName: 'Tournament Admin',
    firstName: 'Tournament',
    lastName: 'Admin',
    password,
    role: 'admin',
  });
}

let initPromise: Promise<void> | null = null;
async function ensureCountersInitialized(): Promise<void> {
  await db.runTransaction(async (tx) => {
    const countersSnap = await tx.get(countersRef);
    const existing = countersSnap.exists ? countersSnap.data() ?? {} : {};

    const nextUserId = Math.max(1, toInt(existing.next_user_id, 1));
    const nextMatchId = Math.max(1, toInt(existing.next_match_id, 1));
    const nextRoundId = Math.max(1, toInt(existing.next_round_id, 1));
    const nextTournamentId = Math.max(1, toInt(existing.next_tournament_id, 1));

    tx.set(
      countersRef,
      {
        next_user_id: nextUserId,
        next_match_id: nextMatchId,
        next_round_id: nextRoundId,
        next_tournament_id: nextTournamentId,
      },
      {merge: true},
    );
  });
}

function ensureInitialized(): Promise<void> {
  if (initPromise == null) {
    initPromise = ensureCountersInitialized()
      .then(async () => {
        await ensureConfiguredBootstrapAdmin();
        if (runtimeConfig.autoBootstrapDemo) {
          await seedDemoData(false);
        }
      })
      .then(() => undefined)
      .catch((error) => {
        initPromise = null;
        throw error;
      });
  }
  return initPromise;
}

const app = express();
const router = express.Router();

app.use(cors({origin: true}));
app.use(express.json());
app.use(express.urlencoded({extended: true}));
app.use((req, _res, next) => {
  ensureInitialized().then(() => next()).catch(next);
});

router.get('/health', route(async (_req, res) => {
  res.json({status: 'ok'});
}));

router.post('/setup/seed', route(async (req, res) => {
  if (!runtimeConfig.allowDemoSeed) {
    throw new HttpError(
      403,
      'Seeding is disabled. Set ALLOW_DEMO_SEED=true to enable this endpoint.',
    );
  }
  if (runtimeConfig.seedApiKey.length > 0) {
    const supplied = req.header('x-seed-key')?.trim() ?? '';
    if (supplied !== runtimeConfig.seedApiKey) {
      throw new HttpError(403, 'Invalid seed key.');
    }
  }

  const force = parseBooleanQuery(req.query.force);
  const prestart =
    parseBooleanQuery(req.query.prestart) ||
    parseBooleanQuery(req.query.no_rounds) ||
    parseBooleanQuery(req.query.no_fixtures);
  const details = await seedDemoData(force, !prestart);
  res.json(details);
}));

router.post('/tournament/setup', route(async (req, res) => {
  await requireAdminUser(req);

  const tournamentName = toText(
    req.body?.tournament_name ?? req.body?.name,
  ).trim();
  const defaultPassword = toText(
    req.body?.default_password ?? 'pass123',
  ).trim();
  const metadata = parseTournamentSetupMetadata(
    (req.body ?? {}) as Record<string, unknown>,
  );
  const players = parseTournamentSetupPlayers(req.body?.players);

  const result = await setupTournamentFromPlayers({
    tournamentName,
    defaultPassword,
    metadata,
    players,
  });
  res.json(result);
}));

router.get('/tournaments', route(async (req, res) => {
  await requireAdminUser(req);
  const tournaments = await tournamentsRepository.list();
  tournaments.sort((a, b) => b.id - a.id);
  res.json(tournaments.map((tournament) => tournamentDtoFromModel(tournament)));
}));

router.get('/tournaments/active', route(async (req, res) => {
  await requireUser(req);
  const tournaments = await tournamentsRepository.list();
  const active = tournaments.find((entry) => entry.status === 'active') ?? null;
  res.json({
    has_active_tournament: active != null,
    tournament: active == null ? null : tournamentDtoFromModel(active),
  });
}));

router.post('/tournaments', route(async (req, res) => {
  await requireAdminUser(req);

  const tournamentName = toText(
    req.body?.tournament_name ?? req.body?.name,
  ).trim();
  assertLength(tournamentName, 'tournament_name', 2, 120);

  const payload = (req.body ?? {}) as Record<string, unknown>;
  const hasMetadataInput =
    payload.tournament_type != null ||
    payload.type != null ||
    payload.tournament_sub_type != null ||
    payload.sub_type != null ||
    payload.subType != null ||
    payload.tournament_strength != null ||
    payload.strength != null ||
    payload.tournament_srr_rounds != null ||
    payload.tournament_no_of_srr_rounds != null ||
    payload.srr_rounds != null ||
    payload.number_of_srr_rounds != null ||
    payload.srrRounds != null ||
    payload.tournament_limits_singles_max_participants != null ||
    payload.singles_max_participants != null ||
    payload.singlesMaxParticipants != null ||
    payload.tournament_limits_doubles_max_teams != null ||
    payload.doubles_max_teams != null ||
    payload.doublesMaxTeams != null;
  const metadataInput = hasMetadataInput
    ? parseTournamentSetupMetadata(payload)
    : defaultTournamentMetadataInput();
  const nextStatus = parseTournamentStatus(req.body?.status, 'setup');
  const now = utcNow();
  if (nextStatus === 'active') {
    const allTournaments = await tournamentsRepository.list();
    const currentlyActive = allTournaments.filter(
      (tournament) => tournament.status === 'active',
    );
    for (const activeTournament of currentlyActive) {
      await tournamentsRepository.update({
        tournamentId: activeTournament.id,
        name: activeTournament.name,
        status: 'setup',
        metadata: activeTournament.metadata ?? null,
        now,
      });
    }
  }

  const created = await tournamentsRepository.create({
    name: tournamentName,
    status: nextStatus,
    metadata: tournamentMetadataInputToModel(metadataInput),
    now,
  });
  res.status(201).json(tournamentDtoFromModel(created));
}));

router.get('/tournaments/:tournament_id', route(async (req, res) => {
  await requireAdminUser(req);
  const tournamentId = parsePositiveInt(req.params.tournament_id, 'tournament_id');
  const tournament = await requireTournamentById(tournamentId);
  res.json(tournamentDtoFromModel(tournament));
}));

router.post('/tournaments/:tournament_id/replicate', route(async (req, res) => {
  await requireAdminUser(req);
  const sourceTournamentId = parsePositiveInt(
    req.params.tournament_id,
    'tournament_id',
  );
  const source = await requireTournamentById(sourceTournamentId);
  const tournamentName = toText(
    req.body?.tournament_name ?? req.body?.name,
  ).trim();
  assertLength(tournamentName, 'tournament_name', 2, 120);

  const replicated = await tournamentsRepository.create({
    name: tournamentName,
    status: 'setup',
    metadata: source.metadata ?? null,
    now: utcNow(),
  });
  res.status(201).json(tournamentDtoFromModel(replicated));
}));

router.patch('/tournaments/:tournament_id', route(async (req, res) => {
  await requireAdminUser(req);
  const tournamentId = parsePositiveInt(req.params.tournament_id, 'tournament_id');
  const existing = await requireTournamentById(tournamentId);
  assertTournamentSetupEditable(existing);

  const tournamentName = toText(
    req.body?.tournament_name ?? req.body?.name ?? existing.name,
  ).trim();
  assertLength(tournamentName, 'tournament_name', 2, 120);

  const metadataInput = parseTournamentSetupMetadata(
    (req.body ?? {}) as Record<string, unknown>,
  );
  const nextStatus = parseTournamentStatus(req.body?.status, existing.status);
  const now = utcNow();
  if (nextStatus === 'active') {
    const allTournaments = await tournamentsRepository.list();
    const currentlyActive = allTournaments.filter(
      (tournament) =>
        tournament.id !== tournamentId && tournament.status === 'active',
    );
    for (const activeTournament of currentlyActive) {
      await tournamentsRepository.update({
        tournamentId: activeTournament.id,
        name: activeTournament.name,
        status: 'setup',
        metadata: activeTournament.metadata ?? null,
        now,
      });
    }
  }
  const updated = await tournamentsRepository.update({
    tournamentId,
    name: tournamentName,
    status: nextStatus,
    metadata: tournamentMetadataInputToModel(metadataInput),
    now,
  });
  if (!updated) {
    throw new HttpError(404, 'Tournament not found.');
  }
  await tournamentSeedingsRepository.clearByTournament(tournamentId);
  await tournamentGroupsRepository.clearByTournament(tournamentId);
  let tournamentWithWorkflow =
    (await tournamentsRepository.updateWorkflowStepStatus({
      tournamentId,
      stepKey: 'create_tournament_seeding',
      status: 'pending',
      now,
    })) ?? updated;
  tournamentWithWorkflow =
    (await tournamentsRepository.updateWorkflowStepStatus({
      tournamentId,
      stepKey: 'create_tournament_groups',
      status: 'pending',
      now,
    })) ?? tournamentWithWorkflow;
  res.json(tournamentDtoFromModel(tournamentWithWorkflow));
}));

router.patch('/tournaments/:tournament_id/workflow', route(async (req, res) => {
  await requireAdminUser(req);
  const tournamentId = parsePositiveInt(req.params.tournament_id, 'tournament_id');
  await requireTournamentById(tournamentId);

  const payload = (req.body ?? {}) as Record<string, unknown>;
  const stepKey = parseTournamentWorkflowStepKey(
    payload.step_key ?? payload.stepKey ?? payload.key,
  );
  const status = parseTournamentWorkflowStepStatus(payload.status, 'completed');
  const updated = await tournamentsRepository.updateWorkflowStepStatus({
    tournamentId,
    stepKey,
    status,
    now: utcNow(),
  });
  if (!updated) {
    throw new HttpError(404, 'Tournament not found.');
  }
  res.json(tournamentDtoFromModel(updated));
}));

router.post('/tournaments/:tournament_id/ranking-selection', route(async (req, res) => {
  await requireAdminUser(req);
  const tournamentId = parsePositiveInt(req.params.tournament_id, 'tournament_id');
  const tournament = await requireTournamentById(tournamentId);
  assertTournamentSetupEditable(tournament);
  const rankingYear = parseRankingYear(
    req.body?.ranking_year ?? req.body?.rankingYear ?? req.body?.year,
  );
  const rankingDescription = parseRankingDescription(
    req.body?.ranking_description ??
      req.body?.rankingDescription ??
      req.body?.description,
  );
  const rankingExists = await nationalRankingsRepository.hasRanking(
    rankingYear,
    rankingDescription,
  );
  if (!rankingExists) {
    throw new HttpError(
      422,
      `No national ranking list found for year ${rankingYear} with description "${rankingDescription}".`,
    );
  }

  const now = utcNow();
  const updated = await tournamentsRepository.selectNationalRankingYear({
    tournamentId,
    rankingYear,
    rankingDescription,
    now,
  });
  if (!updated) {
    throw new HttpError(404, 'Tournament not found.');
  }
  await tournamentSeedingsRepository.clearByTournament(tournamentId);
  await tournamentGroupsRepository.clearByTournament(tournamentId);
  let tournamentWithWorkflow =
    (await tournamentsRepository.updateWorkflowStepStatus({
      tournamentId,
      stepKey: 'create_tournament_seeding',
      status: 'pending',
      now,
    })) ?? updated;
  tournamentWithWorkflow =
    (await tournamentsRepository.updateWorkflowStepStatus({
      tournamentId,
      stepKey: 'create_tournament_groups',
      status: 'pending',
      now,
    })) ?? tournamentWithWorkflow;
  res.json(tournamentDtoFromModel(tournamentWithWorkflow));
}));

router.delete('/tournaments/:tournament_id', route(async (req, res) => {
  await requireAdminUser(req);
  const tournamentId = parsePositiveInt(req.params.tournament_id, 'tournament_id');
  await requireTournamentById(tournamentId);

  await deleteTournamentArtifacts(tournamentId);
  const deleted = await tournamentsRepository.delete(tournamentId);
  if (!deleted) {
    throw new HttpError(404, 'Tournament not found.');
  }
  res.json({deleted: true, tournament_id: tournamentId});
}));

router.get('/tournaments/:tournament_id/players', route(async (req, res) => {
  await requireAdminUser(req);
  const tournamentId = parsePositiveInt(req.params.tournament_id, 'tournament_id');
  await requireTournamentById(tournamentId);
  const players = await fetchTournamentPlayers(tournamentId);
  res.json(players);
}));

router.delete('/tournaments/:tournament_id/players', route(async (req, res) => {
  await requireAdminUser(req);
  const tournamentId = parsePositiveInt(req.params.tournament_id, 'tournament_id');
  const tournament = await requireTournamentById(tournamentId);
  assertTournamentSetupEditable(tournament);
  const playersDeleted = await clearTournamentPlayerLinks(tournamentId);
  await tournamentSeedingsRepository.clearByTournament(tournamentId);
  await tournamentGroupsRepository.clearByTournament(tournamentId);
  let tournamentWithWorkflow =
    (await tournamentsRepository.updateWorkflowStepStatus({
      tournamentId,
      stepKey: 'load_registered_players',
      status: 'pending',
      now: utcNow(),
    })) ?? tournament;
  tournamentWithWorkflow =
    (await tournamentsRepository.updateWorkflowStepStatus({
      tournamentId,
      stepKey: 'create_tournament_seeding',
      status: 'pending',
      now: utcNow(),
    })) ?? tournamentWithWorkflow;
  tournamentWithWorkflow =
    (await tournamentsRepository.updateWorkflowStepStatus({
      tournamentId,
      stepKey: 'create_tournament_groups',
      status: 'pending',
      now: utcNow(),
    })) ?? tournamentWithWorkflow;
  const players = await fetchTournamentPlayers(tournamentId);
  res.json({
    tournament: tournamentDtoFromModel(tournamentWithWorkflow),
    players_deleted: playersDeleted,
    players,
  });
}));

router.post('/tournaments/:tournament_id/players/upload', route(async (req, res) => {
  await requireAdminUser(req);
  const tournamentId = parsePositiveInt(req.params.tournament_id, 'tournament_id');
  const tournament = await requireTournamentById(tournamentId);
  assertTournamentSetupEditable(tournament);

  const parsedPlayers = parseTournamentSetupPlayers(req.body?.players);
  if (tournament.metadata != null) {
    const participantLimit =
      tournament.metadata.subType === 'singles'
        ? tournament.metadata.singlesMaxParticipants
        : tournament.metadata.doublesMaxTeams;
    if (parsedPlayers.length > participantLimit) {
      throw new HttpError(
        422,
        `Uploaded participants (${parsedPlayers.length}) exceed limit (${participantLimit}).`,
      );
    }
  }

  const uploadedPlayers: TournamentPlayerDto[] = [];
  const seenIds = new Set<number>();
  for (let i = 0; i < parsedPlayers.length; i += 1) {
    const inputPlayer = parsedPlayers[i];
    const resolved = await resolveTournamentUploadPlayer({
      input: inputPlayer,
      fallbackIndex: i,
    });
    await syncPlayerModelFromUser(resolved.user, {
      playerName: inputPlayer.displayName,
      state: inputPlayer.state,
      country: inputPlayer.country,
      emailId: inputPlayer.emailId,
      registeredFlag: inputPlayer.registeredFlag,
      tshirtSize: inputPlayer.tshirtSize,
      feesPaidFlag: inputPlayer.feesPaidFlag,
      phoneNumber: inputPlayer.phoneNumber,
    });
    const dto: TournamentPlayerDto = {
      ...tournamentPlayerDtoFromUser(resolved.user),
      state: inputPlayer.state,
      country: inputPlayer.country,
      email_id: inputPlayer.emailId,
      registered_flag: inputPlayer.registeredFlag,
      t_shirt_size: inputPlayer.tshirtSize,
      fees_paid_flag: inputPlayer.feesPaidFlag,
      phone_number: inputPlayer.phoneNumber,
    };
    if (seenIds.has(dto.id)) continue;
    seenIds.add(dto.id);
    uploadedPlayers.push(dto);
  }

  await upsertTournamentPlayerLinks(tournamentId, uploadedPlayers);
  const players = await fetchTournamentPlayers(tournamentId);
  await tournamentSeedingsRepository.clearByTournament(tournamentId);
  await tournamentGroupsRepository.clearByTournament(tournamentId);
  let tournamentWithWorkflow =
    (await tournamentsRepository.updateWorkflowStepStatus({
      tournamentId,
      stepKey: 'load_registered_players',
      status: 'completed',
      now: utcNow(),
    })) ?? tournament;
  tournamentWithWorkflow =
    (await tournamentsRepository.updateWorkflowStepStatus({
      tournamentId,
      stepKey: 'create_tournament_seeding',
      status: 'pending',
      now: utcNow(),
    })) ?? tournamentWithWorkflow;
  tournamentWithWorkflow =
    (await tournamentsRepository.updateWorkflowStepStatus({
      tournamentId,
      stepKey: 'create_tournament_groups',
      status: 'pending',
      now: utcNow(),
    })) ?? tournamentWithWorkflow;

  res.json({
    tournament: tournamentDtoFromModel(tournamentWithWorkflow),
    players_uploaded: uploadedPlayers.length,
    players,
  });
}));

router.get('/tournaments/:tournament_id/seeding', route(async (req, res) => {
  await requireAdminUser(req);
  const tournamentId = parsePositiveInt(req.params.tournament_id, 'tournament_id');
  const context = await resolveTournamentSeedingContext(tournamentId);

  let tournamentForResponse = context.tournament;
  let seededRows = await tournamentSeedingsRepository.listByTournament(tournamentId);
  if (seededRows.length > 0) {
    const currentPlayerIds = new Set(context.players.map((player) => player.id));
    const isStale =
      seededRows.length !== currentPlayerIds.size ||
      seededRows.some((row) => !currentPlayerIds.has(row.playerId));
    if (isStale) {
      await tournamentSeedingsRepository.clearByTournament(tournamentId);
      const now = utcNow();
      tournamentForResponse =
        (await tournamentsRepository.updateWorkflowStepStatus({
          tournamentId,
          stepKey: 'create_tournament_seeding',
          status: 'pending',
          now,
        })) ?? tournamentForResponse;
      seededRows = [];
    }
  }

  if (seededRows.length > 0) {
    const rowsDto = seededRows.map((row) => tournamentSeedingRowDtoFromModel(row));
    const response: TournamentSeedingSnapshotDto = {
      tournament: tournamentDtoFromModel(tournamentForResponse),
      ranking_year: context.rankingYear,
      ranking_description: context.rankingDescription,
      national_country: context.nationalCountry,
      seeded: true,
      generated_at: lastSeedingGeneratedAt(rowsDto),
      summary: summarizeTournamentSeedingRows(rowsDto),
      rows: rowsDto,
    };
    res.json(response);
    return;
  }

  const previewAt = utcNow();
  const previewRows = context.computedRows.map((row) =>
    tournamentSeedingPreviewRowDto(row, previewAt),
  );
  const response: TournamentSeedingSnapshotDto = {
    tournament: tournamentDtoFromModel(tournamentForResponse),
    ranking_year: context.rankingYear,
    ranking_description: context.rankingDescription,
    national_country: context.nationalCountry,
    seeded: false,
    generated_at: null,
    summary: summarizeTournamentSeedingRows(previewRows),
    rows: previewRows,
  };
  res.json(response);
}));

router.post('/tournaments/:tournament_id/seeding/generate', route(async (req, res) => {
  await requireAdminUser(req);
  const tournamentId = parsePositiveInt(req.params.tournament_id, 'tournament_id');
  const context = await resolveTournamentSeedingContext(tournamentId);
  assertTournamentSetupEditable(context.tournament);
  const now = utcNow();

  await tournamentSeedingsRepository.clearByTournament(tournamentId);
  await tournamentSeedingsRepository.upsertRows({
    tournamentId,
    rows: context.computedRows,
    now,
  });
  await tournamentGroupsRepository.clearByTournament(tournamentId);

  let tournamentWithWorkflow =
    (await tournamentsRepository.updateWorkflowStepStatus({
      tournamentId,
      stepKey: 'create_tournament_seeding',
      status: 'completed',
      now,
    })) ?? context.tournament;
  tournamentWithWorkflow =
    (await tournamentsRepository.updateWorkflowStepStatus({
      tournamentId,
      stepKey: 'create_tournament_groups',
      status: 'pending',
      now,
    })) ?? tournamentWithWorkflow;
  const seededRows = await tournamentSeedingsRepository.listByTournament(tournamentId);
  const rowsDto = seededRows.map((row) => tournamentSeedingRowDtoFromModel(row));
  const response: TournamentSeedingSnapshotDto = {
    tournament: tournamentDtoFromModel(tournamentWithWorkflow),
    ranking_year: context.rankingYear,
    ranking_description: context.rankingDescription,
    national_country: context.nationalCountry,
    seeded: true,
    generated_at: lastSeedingGeneratedAt(rowsDto) ?? now,
    summary: summarizeTournamentSeedingRows(rowsDto),
    rows: rowsDto,
  };
  res.json(response);
}));

router.patch('/tournaments/:tournament_id/seeding/order', route(async (req, res) => {
  await requireAdminUser(req);
  const tournamentId = parsePositiveInt(req.params.tournament_id, 'tournament_id');
  const context = await resolveTournamentSeedingContext(tournamentId);
  assertTournamentSetupEditable(context.tournament);
  const payload = (req.body ?? {}) as Record<string, unknown>;
  const orderedPlayerIds = parseOrderedPlayerIds(
    payload.ordered_player_ids ?? payload.orderedPlayerIds ?? payload.player_ids,
  );
  const now = utcNow();

  let seededRows: TournamentSeedingModel[];
  try {
    seededRows = await tournamentSeedingsRepository.reorder({
      tournamentId,
      orderedPlayerIds,
      now,
    });
  } catch (error) {
    if (error instanceof Error) {
      throw new HttpError(422, error.message);
    }
    throw error;
  }
  if (seededRows.length === 0) {
    throw new HttpError(
      422,
      'No seeded rows found for this tournament. Generate seeding first.',
    );
  }
  await tournamentGroupsRepository.clearByTournament(tournamentId);

  let tournamentWithWorkflow =
    (await tournamentsRepository.updateWorkflowStepStatus({
      tournamentId,
      stepKey: 'create_tournament_seeding',
      status: 'completed',
      now,
    })) ?? context.tournament;
  tournamentWithWorkflow =
    (await tournamentsRepository.updateWorkflowStepStatus({
      tournamentId,
      stepKey: 'create_tournament_groups',
      status: 'pending',
      now,
    })) ?? tournamentWithWorkflow;
  const rowsDto = seededRows.map((row) => tournamentSeedingRowDtoFromModel(row));
  const response: TournamentSeedingSnapshotDto = {
    tournament: tournamentDtoFromModel(tournamentWithWorkflow),
    ranking_year: context.rankingYear,
    ranking_description: context.rankingDescription,
    national_country: context.nationalCountry,
    seeded: true,
    generated_at: lastSeedingGeneratedAt(rowsDto) ?? now,
    summary: summarizeTournamentSeedingRows(rowsDto),
    rows: rowsDto,
  };
  res.json(response);
}));

router.delete('/tournaments/:tournament_id/seeding', route(async (req, res) => {
  await requireAdminUser(req);
  const tournamentId = parsePositiveInt(req.params.tournament_id, 'tournament_id');
  const tournament = await requireTournamentById(tournamentId);
  assertTournamentSetupEditable(tournament);
  const now = utcNow();
  const deletedRows = await tournamentSeedingsRepository.clearByTournament(
    tournamentId,
  );
  const deletedGroupRows = await tournamentGroupsRepository.clearByTournament(
    tournamentId,
  );
  let tournamentWithWorkflow =
    (await tournamentsRepository.updateWorkflowStepStatus({
      tournamentId,
      stepKey: 'create_tournament_seeding',
      status: 'pending',
      now,
    })) ?? tournament;
  tournamentWithWorkflow =
    (await tournamentsRepository.updateWorkflowStepStatus({
      tournamentId,
      stepKey: 'create_tournament_groups',
      status: 'pending',
      now,
    })) ?? tournamentWithWorkflow;

  res.json({
    tournament: tournamentDtoFromModel(tournamentWithWorkflow),
    deleted_rows: deletedRows,
    deleted_group_rows: deletedGroupRows,
  });
}));

router.get('/tournaments/:tournament_id/groups', route(async (req, res) => {
  await requireAdminUser(req);
  const tournamentId = parsePositiveInt(req.params.tournament_id, 'tournament_id');
  const tournament = await requireTournamentById(tournamentId);

  const existingRows = await tournamentGroupsRepository.listByTournament(tournamentId);
  if (existingRows.length > 0) {
    const rowsDto = existingRows.map((row) => tournamentGroupRowDtoFromModel(row));
    const response: TournamentGroupsSnapshotDto = {
      tournament: tournamentDtoFromModel(tournament),
      generated: true,
      method: rowsDto[0].method,
      group_count: rowsDto[0].group_count,
      generated_at: lastGroupsGeneratedAt(rowsDto),
      rows: rowsDto,
    };
    res.json(response);
    return;
  }

  const seededRows = await tournamentSeedingsRepository.listByTournament(tournamentId);
  const response: TournamentGroupsSnapshotDto = {
    tournament: tournamentDtoFromModel(tournament),
    generated: false,
    method: null,
    group_count: tournamentGroupCountForGeneration(tournament, seededRows.length),
    generated_at: null,
    rows: [],
  };
  res.json(response);
}));

router.post('/tournaments/:tournament_id/groups/generate', route(async (req, res) => {
  await requireAdminUser(req);
  const tournamentId = parsePositiveInt(req.params.tournament_id, 'tournament_id');
  const tournament = await requireTournamentById(tournamentId);
  assertTournamentSetupEditable(tournament);
  const method = parseTournamentGroupingMethod(
    req.body?.method ??
      req.body?.grouping_method ??
      req.body?.groupingMethod ??
      req.query.method,
  );

  const seededRows = await tournamentSeedingsRepository.listByTournament(tournamentId);
  if (seededRows.length === 0) {
    throw new HttpError(
      422,
      'Generate tournament seeding before creating groups.',
    );
  }
  const groupCount = tournamentGroupCountForGeneration(tournament, seededRows.length);
  const generatedRows = buildTournamentGroupRows({
    seededRows,
    groupCount,
    method,
  });
  const now = utcNow();
  await tournamentGroupsRepository.clearByTournament(tournamentId);
  await tournamentGroupsRepository.upsertRows({
    tournamentId,
    rows: generatedRows,
    now,
  });

  let tournamentWithWorkflow =
    (await tournamentsRepository.updateWorkflowStepStatus({
      tournamentId,
      stepKey: 'create_tournament_seeding',
      status: 'completed',
      now,
    })) ?? tournament;
  tournamentWithWorkflow =
    (await tournamentsRepository.updateWorkflowStepStatus({
      tournamentId,
      stepKey: 'create_tournament_groups',
      status: 'completed',
      now,
    })) ?? tournamentWithWorkflow;

  const persistedRows = await tournamentGroupsRepository.listByTournament(tournamentId);
  const rowsDto = persistedRows.map((row) => tournamentGroupRowDtoFromModel(row));
  const response: TournamentGroupsSnapshotDto = {
    tournament: tournamentDtoFromModel(tournamentWithWorkflow),
    generated: true,
    method,
    group_count: groupCount,
    generated_at: lastGroupsGeneratedAt(rowsDto) ?? now,
    rows: rowsDto,
  };
  res.json(response);
}));

router.delete('/tournaments/:tournament_id/groups', route(async (req, res) => {
  await requireAdminUser(req);
  const tournamentId = parsePositiveInt(req.params.tournament_id, 'tournament_id');
  const tournament = await requireTournamentById(tournamentId);
  assertTournamentSetupEditable(tournament);
  const now = utcNow();
  const deletedRows = await tournamentGroupsRepository.clearByTournament(
    tournamentId,
  );
  const tournamentWithWorkflow =
    (await tournamentsRepository.updateWorkflowStepStatus({
      tournamentId,
      stepKey: 'create_tournament_groups',
      status: 'pending',
      now,
    })) ?? tournament;
  res.json({
    tournament: tournamentDtoFromModel(tournamentWithWorkflow),
    deleted_rows: deletedRows,
  });
}));

router.post('/tournaments/:tournament_id/matchups/generate', route(async (req, res) => {
  await requireAdminUser(req);
  const tournamentId = parsePositiveInt(req.params.tournament_id, 'tournament_id');
  const tournament = await requireTournamentById(tournamentId);
  if (tournament.status === 'completed') {
    throw new HttpError(409, 'Tournament is completed. Match-up generation is locked.');
  }

  const groupNumber = parseGroupNumber(
    req.body?.group_number ?? req.body?.groupNumber ?? req.query.group_number,
  );
  const roundOneMethod = parseRoundOnePairingMethod(
    req.body?.round_one_method ?? req.body?.roundOneMethod,
  );
  const groupedAssignments = await fetchTournamentGroupAssignments(tournamentId);
  const groupPlayers = groupedAssignments.get(groupNumber) ?? [];
  if (groupPlayers.length < 2) {
    throw new HttpError(
      422,
      `No grouped players found for group ${groupNumber}. Create groups first.`,
    );
  }

  const maxRounds = Math.max(1, Math.trunc(tournament.metadata?.srrRounds ?? 7));
  const groupMatches = (await fetchAllMatches(tournamentId)).filter(
    (match) => match.group_number === groupNumber,
  );
  const currentRound = groupMatches.length == 0
    ? 0
    : Math.max(...groupMatches.map((match) => match.round_number));
  if (currentRound >= maxRounds) {
    throw new HttpError(
      422,
      `All ${maxRounds} rounds are already generated for group ${groupNumber}.`,
    );
  }
  if (currentRound > 0) {
    const currentRoundHasPendingMatches = groupMatches.some(
      (match) =>
        match.round_number === currentRound &&
        (match.confirmed_score1 == null || match.confirmed_score2 == null),
    );
    if (currentRoundHasPendingMatches) {
      throw new HttpError(
        409,
        `Round ${currentRound} in group ${groupNumber} has pending scores. Complete it before generating next round.`,
      );
    }
  }

  const nextRound = currentRound + 1;
  let methodUsed: RoundOnePairingMethod | 'swiss';
  let pairs: Array<[TournamentGroupModel, TournamentGroupModel]>;
  if (nextRound === 1) {
    methodUsed = roundOneMethod;
    pairs = buildRoundOnePairs({
      players: groupPlayers,
      method: roundOneMethod,
    });
  } else {
    methodUsed = 'swiss';
    pairs = buildSwissPairs({
      players: groupPlayers,
      historicalMatches: groupMatches,
    });
  }

  if (pairs.length === 0) {
    throw new HttpError(
      422,
      `Unable to generate match-ups for group ${groupNumber}.`,
    );
  }

  const tableAssignments = buildRandomTableAssignments({
    matchCount: pairs.length,
    tableCount: Math.max(
      1,
      Math.trunc(tournament.metadata?.numberOfTables ?? pairs.length),
    ),
  });

  for (let index = 0; index < pairs.length; index += 1) {
    const [left, right] = pairs[index];
    await createMatch({
      tournamentId,
      groupNumber,
      roundNumber: nextRound,
      tableNumber: tableAssignments[index] ?? index + 1,
      player1Id: left.playerId,
      player2Id: right.playerId,
    });
  }

  const now = utcNow();
  let tournamentForResponse = tournament;
  if (tournament.status !== 'active') {
    const allTournaments = await tournamentsRepository.list();
    const currentlyActive = allTournaments.filter(
      (entry) => entry.id !== tournamentId && entry.status === 'active',
    );
    for (const activeTournament of currentlyActive) {
      await tournamentsRepository.update({
        tournamentId: activeTournament.id,
        name: activeTournament.name,
        status: 'setup',
        metadata: activeTournament.metadata ?? null,
        selectedRankingYear: activeTournament.selectedRankingYear,
        selectedRankingDescription: activeTournament.selectedRankingDescription,
        workflow: activeTournament.workflow,
        now,
      });
    }
    tournamentForResponse =
      (await tournamentsRepository.update({
        tournamentId,
        name: tournament.name,
        status: 'active',
        metadata: tournament.metadata ?? null,
        selectedRankingYear: tournament.selectedRankingYear,
        selectedRankingDescription: tournament.selectedRankingDescription,
        workflow: tournament.workflow,
        now,
      })) ?? tournamentForResponse;
  }
  tournamentForResponse =
    (await tournamentsRepository.updateWorkflowStepStatus({
      tournamentId,
      stepKey: 'generate_matchups_next_round',
      status: 'completed',
      now,
    })) ?? tournamentForResponse;

  await syncDomainReadModels(utcNow(), tournamentId);
  const refreshedGroupMatches = (await fetchAllMatches(tournamentId)).filter(
    (match) => match.group_number === groupNumber,
  );
  const response: MatchupGenerateResultDto = {
    tournament: tournamentDtoFromModel(tournamentForResponse),
    group_number: groupNumber,
    round_number: nextRound,
    method: methodUsed,
    matches_created: pairs.length,
    summary: groupMatchupSummary({
      groupNumber,
      playerCount: groupPlayers.length,
      matches: refreshedGroupMatches,
      maxRounds,
    }),
  };
  res.json(response);
}));

router.delete('/tournaments/:tournament_id/matchups/current', route(async (req, res) => {
  await requireAdminUser(req);
  const tournamentId = parsePositiveInt(req.params.tournament_id, 'tournament_id');
  const tournament = await requireTournamentById(tournamentId);
  if (tournament.status === 'completed') {
    throw new HttpError(409, 'Tournament is completed. Match-up deletion is locked.');
  }
  const groupNumber = parseGroupNumber(
    req.query.group_number ?? req.body?.group_number ?? req.body?.groupNumber,
  );
  const groupedAssignments = await fetchTournamentGroupAssignments(tournamentId);
  const groupPlayers = groupedAssignments.get(groupNumber) ?? [];
  if (groupPlayers.length == 0) {
    throw new HttpError(
      422,
      `No grouped players found for group ${groupNumber}.`,
    );
  }

  const maxRounds = Math.max(1, Math.trunc(tournament.metadata?.srrRounds ?? 7));
  const groupMatches = (await fetchAllMatches(tournamentId)).filter(
    (match) => match.group_number === groupNumber,
  );
  if (groupMatches.length === 0) {
    throw new HttpError(404, `No match-ups found for group ${groupNumber}.`);
  }
  const currentRound = Math.max(...groupMatches.map((match) => match.round_number));
  const currentRoundMatches = groupMatches.filter(
    (match) => match.round_number === currentRound,
  );
  const deletedMatches = await deleteMatchesByIds(
    currentRoundMatches.map((match) => match.id),
  );
  await syncDomainReadModels(utcNow(), tournamentId);

  const remainingMatches = await fetchAllMatches(tournamentId);
  let tournamentForResponse = tournament;
  if (remainingMatches.length === 0 && tournament.status === 'active') {
    const now = utcNow();
    tournamentForResponse =
      (await tournamentsRepository.update({
        tournamentId,
        name: tournament.name,
        status: 'setup',
        metadata: tournament.metadata ?? null,
        selectedRankingYear: tournament.selectedRankingYear,
        selectedRankingDescription: tournament.selectedRankingDescription,
        workflow: tournament.workflow,
        now,
      })) ?? tournamentForResponse;
    tournamentForResponse =
      (await tournamentsRepository.updateWorkflowStepStatus({
        tournamentId,
        stepKey: 'generate_matchups_next_round',
        status: 'pending',
        now,
      })) ?? tournamentForResponse;
  }

  const refreshedGroupMatches = remainingMatches.filter(
    (match) => match.group_number === groupNumber,
  );
  const response: MatchupDeleteResultDto = {
    tournament: tournamentDtoFromModel(tournamentForResponse),
    group_number: groupNumber,
    deleted_round_number: currentRound,
    deleted_matches: deletedMatches,
    summary: groupMatchupSummary({
      groupNumber,
      playerCount: groupPlayers.length,
      matches: refreshedGroupMatches,
      maxRounds,
    }),
  };
  res.json(response);
}));

router.get('/players', route(async (_req, res) => {
  const players = await playersRepository.list();
  players.sort((a, b) =>
    a.displayName.localeCompare(b.displayName, undefined, {
      sensitivity: 'base',
    }),
  );
  res.json(
    players.map((player) => ({
      id: player.id,
      handle: player.handle,
      display_name: player.displayName,
      player_name: player.playerName,
      state: player.state,
      country: player.country,
      email_id: player.emailId,
      registered_flag: player.registeredFlag,
      t_shirt_size: player.tshirtSize,
      fees_paid_flag: player.feesPaidFlag,
      phone_number: player.phoneNumber,
    })),
  );
}));

router.get('/rankings', route(async (req, res) => {
  await requireUser(req);
  const rankingYear = parseRankingYear(
    req.query.ranking_year ?? req.query.rankingYear ?? req.query.year,
  );
  const rankingDescription = parseRankingDescription(
    req.query.ranking_description ??
      req.query.rankingDescription ??
      req.query.description,
  );
  const rows = await nationalRankingsRepository.listRows({
    rankingYear,
    rankingDescription,
  });
  res.json({
    ranking_year: rankingYear,
    ranking_description: rankingDescription,
    rows: rows.map((row) => ({
      rank: row.rank,
      player_name: row.playerName,
      state: row.state,
      country: row.country,
      email_id: row.emailId,
      ranking_points: row.rankingPoints,
      ranking_year: row.rankingYear,
      ranking_description: row.rankingDescription,
      last_updated: row.lastUpdated,
    })),
  });
}));

router.get('/rankings/years', route(async (req, res) => {
  await requireUser(req);
  const rankings = await nationalRankingsRepository.listDistinctRankings();
  const years = [...new Set(rankings.map((entry) => entry.rankingYear))].sort(
    (a, b) => b - a,
  );
  res.json({
    years,
    rankings: rankings.map((entry) => ({
      ranking_year: entry.rankingYear,
      ranking_description: entry.rankingDescription,
    })),
  });
}));

router.post('/rankings/upload', route(async (req, res) => {
  await requireAdminUser(req);
  const payload = (req.body ?? {}) as Record<string, unknown>;
  const rankingDescription = parseRankingDescription(
    payload.ranking_description ?? payload.rankingDescription ?? payload.description,
  );
  const rows = parseNationalRankingRows(
    payload.rows ?? payload.rankings,
    rankingDescription,
  );
  const result = await nationalRankingsRepository.upsertRows({
    rows,
    now: utcNow(),
  });
  res.json({
    uploaded_rows: result.upsertedRows,
    years: result.years,
    rankings: result.rankings.map((entry) => ({
      ranking_year: entry.rankingYear,
      ranking_description: entry.rankingDescription,
    })),
  });
}));

router.post('/rankings/delete', route(async (req, res) => {
  await requireAdminUser(req);
  const payload = (req.body ?? {}) as Record<string, unknown>;
  const rankingYear = parseRankingYear(
    payload.ranking_year ?? payload.rankingYear ?? payload.year,
  );
  const rankingDescription = parseRankingDescription(
    payload.ranking_description ?? payload.rankingDescription ?? payload.description,
  );
  const deletedRows = await nationalRankingsRepository.deleteRankingList({
    rankingYear,
    rankingDescription,
  });

  const normalizedDescription = rankingDescription.trim().toLowerCase();
  const affectedTournamentIds: number[] = [];
  if (deletedRows > 0) {
    const now = utcNow();
    const tournaments = await tournamentsRepository.list();
    for (const tournament of tournaments) {
      const selectedYear = tournament.selectedRankingYear;
      const selectedDescription = toText(
        tournament.selectedRankingDescription,
      ).trim().toLowerCase();
      if (
        selectedYear !== rankingYear ||
        selectedDescription !== normalizedDescription
      ) {
        continue;
      }
      const cleared = await tournamentsRepository.update({
        tournamentId: tournament.id,
        name: tournament.name,
        status: tournament.status,
        metadata: tournament.metadata ?? null,
        selectedRankingYear: null,
        selectedRankingDescription: null,
        now,
      });
      if (cleared == null) continue;
      await tournamentsRepository.updateWorkflowStepStatus({
        tournamentId: tournament.id,
        stepKey: 'load_current_national_ranking',
        status: 'pending',
        now,
      });
      await tournamentsRepository.updateWorkflowStepStatus({
        tournamentId: tournament.id,
        stepKey: 'create_tournament_seeding',
        status: 'pending',
        now,
      });
      await tournamentsRepository.updateWorkflowStepStatus({
        tournamentId: tournament.id,
        stepKey: 'create_tournament_groups',
        status: 'pending',
        now,
      });
      await tournamentSeedingsRepository.clearByTournament(tournament.id);
      await tournamentGroupsRepository.clearByTournament(tournament.id);
      affectedTournamentIds.push(tournament.id);
    }
  }

  const rankings = await nationalRankingsRepository.listDistinctRankings();
  const years = [...new Set(rankings.map((entry) => entry.rankingYear))].sort(
    (a, b) => b - a,
  );
  res.json({
    deleted_rows: deletedRows,
    ranking_year: rankingYear,
    ranking_description: rankingDescription,
    affected_tournament_ids: affectedTournamentIds,
    years,
    rankings: rankings.map((entry) => ({
      ranking_year: entry.rankingYear,
      ranking_description: entry.rankingDescription,
    })),
  });
}));

router.all('/callbacks/sign_in_with_apple', route(async (req, res) => {
  const pairs =
    req.method.toUpperCase() === 'POST'
      ? objectEntries(req.body)
      : objectEntries(req.query);
  const params = new URLSearchParams();
  for (const [key, value] of pairs) {
    params.append(key, value);
  }

  const queryString = params.toString();
  const intentUrl = `intent://callback${queryString ? `?${queryString}` : ''}#Intent;package=${runtimeConfig.appleAndroidPackage};scheme=signinwithapple;end`;

  if (req.method.toUpperCase() === 'POST') {
    res.redirect(302, intentUrl);
    return;
  }

  const escapedHref = intentUrl.replace(/"/g, '&quot;');
  res.status(200).type('html').send(
    `<!doctype html>
<html>
  <head><meta charset="utf-8"><title>Sign in with Apple Callback</title></head>
  <body>
    <p>Returning to app...</p>
    <p><a href="${escapedHref}">Tap here if not redirected</a></p>
    <script>window.location.replace(${JSON.stringify(intentUrl)});</script>
  </body>
</html>`,
  );
}));

router.post('/auth/register', route(async (_req, _res) => {
  throw new HttpError(
    410,
    'Use Firebase Authentication in the client, then call /auth/firebase.',
  );
}));

router.post('/auth/login', route(async (_req, _res) => {
  throw new HttpError(
    410,
    'Use Firebase Authentication in the client, then call /auth/firebase.',
  );
}));

router.post('/auth/social', route(async (_req, _res) => {
  throw new HttpError(
    410,
    'Use Firebase Authentication in the client, then call /auth/firebase.',
  );
}));

router.post('/auth/firebase', route(async (req, res) => {
  const token = tokenFromHeader(req.header('authorization') ?? undefined);
  if (!token) {
    throw new HttpError(401, 'Missing bearer token.');
  }

  const displayName = toText(req.body?.display_name).trim() || undefined;
  const handleHint = toText(
    req.body?.handle_hint ?? req.body?.handle,
  ).trim() || undefined;
  const roleHint = parseFirebaseRoleHint(req.body?.role);
  const user = await userFromFirebaseBearerToken(token, {
    displayName,
    handleHint,
    roleHint,
  });
  if (!user) {
    throw new HttpError(401, 'Invalid Firebase ID token.');
  }

  await syncPlayerModelFromUser(user, {
    playerName: user.display_name,
  });
  res.json(userDto(user));
}));

router.post('/auth/logout', route(async (_req, res) => {
  res.json({ok: true});
}));

router.get('/auth/me', route(async (req, res) => {
  const user = await requireUser(req);
  res.json(userDto(user));
}));

router.post('/auth/profile', route(async (req, res) => {
  const user = await requireUser(req);
  const firstName = toText(req.body?.first_name ?? req.body?.firstName).trim();
  const lastName = toText(req.body?.last_name ?? req.body?.lastName).trim();
  if (!firstName || !lastName) {
    throw new HttpError(422, 'first_name and last_name are required.');
  }
  assertLength(firstName, 'first_name', 1, 80);
  assertLength(lastName, 'last_name', 1, 80);

  const requestedRoleRaw = toText(req.body?.role).trim().toLowerCase();
  let role: Role = user.role;
  if (user.role !== 'admin') {
    if (requestedRoleRaw !== 'player' && requestedRoleRaw !== 'viewer') {
      throw new HttpError(422, 'role must be player or viewer.');
    }
    role = requestedRoleRaw;
  }

  const displayName = `${firstName} ${lastName}`.trim();
  const userRef = db.collection(COLLECTIONS.users).doc(String(user.id));
  await userRef.set(
    {
      first_name: firstName,
      last_name: lastName,
      display_name: displayName,
      role,
    },
    {merge: true},
  );

  const updated = await fetchUserById(user.id);
  if (!updated) {
    throw new HttpError(500, 'Updated user profile could not be loaded.');
  }
  await syncPlayerModelFromUser(updated);
  res.json(userDto(updated));
}));

router.get('/rounds', route(async (req, res) => {
  const tournamentId = await resolveTournamentId(req.query.tournament_id);
  const user = await optionalUser(req);
  const rounds = await fetchRounds(user?.id ?? null, tournamentId);
  res.json(rounds);
}));

router.post('/matches/:match_id/confirm', route(async (req, res) => {
  const matchId = parsePositiveInt(req.params.match_id, 'match_id');

  const user = await requireUser(req);
  if (user.role !== 'player') {
    throw new HttpError(403, 'Only players can confirm scores.');
  }

  const matchRef = db.collection(COLLECTIONS.matches).doc(String(matchId));
  await db.runTransaction(async (tx) => {
    const matchSnap = await tx.get(matchRef);
    const match = toMatchRecord(matchSnap);
    if (!match) {
      throw new HttpError(404, 'Match not found.');
    }

    if (user.id !== match.player1_id && user.id !== match.player2_id) {
      throw new HttpError(403, 'You are not assigned to this match.');
    }

    if (match.confirmed_score1 != null && match.confirmed_score2 != null) {
      throw new HttpError(409, 'Scores are already confirmed for this match.');
    }

    const carromSubmission = parseCarromSubmission(
      req.body,
      match.player1_id,
      match.player2_id,
    );
    const hasScore1 = Object.prototype.hasOwnProperty.call(req.body ?? {}, 'score1');
    const hasScore2 = Object.prototype.hasOwnProperty.call(req.body ?? {}, 'score2');
    const explicitScore1 = hasScore1 ? parseScore(req.body?.score1, 'score1') : null;
    const explicitScore2 = hasScore2 ? parseScore(req.body?.score2, 'score2') : null;

    let score1: number;
    let score2: number;
    if (carromSubmission?.score1 != null && carromSubmission?.score2 != null) {
      score1 = carromSubmission.score1;
      score2 = carromSubmission.score2;
      if (explicitScore1 != null && explicitScore1 !== score1) {
        throw new HttpError(422, 'score1 does not match computed board total.');
      }
      if (explicitScore2 != null && explicitScore2 !== score2) {
        throw new HttpError(422, 'score2 does not match computed board total.');
      }
    } else {
      if (explicitScore1 == null || explicitScore2 == null) {
        throw new HttpError(
          422,
          'score1 and score2 are required unless boards are supplied for carrom scoring.',
        );
      }
      score1 = explicitScore1;
      score2 = explicitScore2;
    }

    const confirmationRef = db
      .collection(COLLECTIONS.scoreConfirmations)
      .doc(`${matchId}_${user.id}`);
    const existingConfirmation = await tx.get(confirmationRef);
    const now = utcNow();
    const createdAt =
      toText((existingConfirmation.data() ?? {}).created_at) || now;

    tx.set(confirmationRef, {
      match_id: matchId,
      player_id: user.id,
      player1_id: match.player1_id,
      player2_id: match.player2_id,
      score1,
      score2,
      carrom_digest: carromSubmission?.digest ?? null,
      toss: carromSubmission?.toss ?? null,
      boards: carromSubmission?.boards ?? [],
      sudden_death: carromSubmission?.sudden_death ?? null,
      created_at: createdAt,
      updated_at: now,
    });
  });

  await confirmScoresIfConsensus(matchId);
  const confirmedMatch = await fetchMatchById(matchId);
  await syncDomainReadModels(utcNow(), confirmedMatch?.tournament_id ?? undefined);
  const refreshed = await fetchMatchDto(matchId, user.id);
  if (!refreshed) {
    throw new HttpError(404, 'Match not found after update.');
  }

  res.json(refreshed);
}));

router.get('/standings', route(async (req, res) => {
  const roundParam = req.query.round;
  const round =
    roundParam == null || roundParam === ''
      ? null
      : parsePositiveInt(roundParam, 'round');
  const tournamentId = await resolveTournamentId(req.query.tournament_id);
  const standings = await fetchStandings(round, tournamentId);
  res.json(standings);
}));

router.get('/round-points', route(async (req, res) => {
  const tournamentId = await resolveTournamentId(req.query.tournament_id);
  const points = await fetchRoundPoints(tournamentId);
  res.json(points);
}));

router.get('/standings/by-round', route(async (req, res) => {
  const tournamentId = await resolveTournamentId(req.query.tournament_id);
  const standings = await fetchStandingsByRound(tournamentId);
  res.json(standings);
}));

router.get('/live', route(async (req, res) => {
  const tournamentId = await resolveTournamentId(req.query.tournament_id);
  const user = await optionalUser(req);
  const [currentRound, rounds, standings] = await Promise.all([
    fetchCurrentRound(tournamentId),
    fetchRounds(user?.id ?? null, tournamentId),
    fetchStandings(null, tournamentId),
  ]);

  const payload: LiveSnapshotDto = {
    generated_at: utcNow(),
    current_round: currentRound,
    rounds,
    standings,
  };
  res.json(payload);
}));

app.use(router);
app.use('/api', router);

app.use((error: unknown, _req: Request, res: Response, _next: NextFunction) => {
  if (error instanceof HttpError) {
    sendError(res, error.statusCode, error.detail);
    return;
  }

  const detail =
    error instanceof Error && error.message.trim().length > 0
      ? error.message
      : 'Internal server error.';
  console.error(error);
  sendError(res, 500, detail);
});

export const api = onRequest(app);
