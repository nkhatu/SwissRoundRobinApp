/* ---------------------------------------------------------------------------
 * functions/src/models/domain_models.ts
 * ---------------------------------------------------------------------------
 *
 * Purpose:
 * - Defines TypeScript domain contracts for tournaments, matches, scores, and users.
 * Architecture:
 * - Model contract layer shared by route handlers and repositories.
 * - Reduces cross-module drift by centralizing core data type definitions.
 * Author: Neil Khatu
 * Copyright (c) The Khatu Family Trust
 */
export type UserRole = 'player' | 'viewer' | 'admin';

export interface UserModel {
  id: number;
  email?: string | null;
  handle: string;
  displayName: string;
  firstName?: string | null;
  lastName?: string | null;
  passwordHash: string;
  role: UserRole;
  createdAt: string;
}

export interface PlayerModel {
  id: number;
  userId: number;
  handle: string;
  playerName: string;
  displayName: string;
  state: string | null;
  country: string | null;
  emailId: string | null;
  registeredFlag: boolean;
  tshirtSize: string | null;
  feesPaidFlag: boolean;
  phoneNumber: string | null;
  createdAt: string;
}

export interface NationalRankingModel {
  id: string;
  rankingYear: number;
  rankingDescription: string;
  rank: number;
  playerName: string;
  state: string | null;
  country: string | null;
  emailId: string | null;
  rankingPoints: number | null;
  lastUpdated: string | null;
  createdAt: string;
  updatedAt: string;
}

export type TournamentStatus = 'setup' | 'active' | 'completed';
export type TournamentType = 'national' | 'open' | 'regional' | 'club';
export type TournamentSubType = 'singles' | 'doubles';
export type TournamentCategory = 'men' | 'women';
export type TournamentSubCategory = 'junior' | 'senior';
export type TournamentWorkflowStepStatus = 'pending' | 'completed';
export type TournamentWorkflowStepKey =
  | 'create_tournament'
  | 'load_registered_players'
  | 'load_current_national_ranking'
  | 'create_tournament_seeding'
  | 'create_tournament_groups'
  | 'generate_matchups_next_round'
  | 'create_final_srr_standings'
  | 'generate_knockout_brackets'
  | 'generate_final_tournament_standings'
  | 'announce_winners';

export interface TournamentWorkflowStepModel {
  key: TournamentWorkflowStepKey;
  status: TournamentWorkflowStepStatus;
  completedAt: string | null;
}

export interface TournamentWorkflowModel {
  steps: TournamentWorkflowStepModel[];
  updatedAt: string;
}

export interface PersonNameModel {
  firstName: string;
  lastName: string;
}

export interface TournamentMetadataModel {
  type: TournamentType;
  subType: TournamentSubType;
  strength: number;
  startDateTime: string;
  endDateTime: string;
  srrRounds: number;
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

export interface TournamentModel {
  id: number;
  name: string;
  status: TournamentStatus;
  metadata?: TournamentMetadataModel | null;
  selectedRankingYear: number | null;
  selectedRankingDescription: string | null;
  workflow: TournamentWorkflowModel;
  createdAt: string;
  updatedAt: string;
}

export type TournamentSeedingSourceType =
  | 'national'
  | 'international'
  | 'new';
export type TournamentSeedingMatchedBy = 'email' | 'name' | 'none';

export interface TournamentSeedingModel {
  id: string;
  tournamentId: number;
  playerId: number;
  seed: number;
  sourceType: TournamentSeedingSourceType;
  matchedBy: TournamentSeedingMatchedBy;
  rankingRank: number | null;
  rankingYear: number | null;
  rankingDescription: string | null;
  displayName: string;
  handle: string;
  state: string | null;
  country: string | null;
  emailId: string | null;
  isManual: boolean;
  createdAt: string;
  updatedAt: string;
}

export interface RoundModel {
  id: number;
  tournamentId: number;
  roundNumber: number;
  isComplete: boolean;
  createdAt: string;
  updatedAt: string;
}

export type ScoreStatus = 'pending' | 'disputed' | 'confirmed';

export type TossDecision = 'strike_first' | 'choose_side';
export type CarromColor = 'white' | 'black';
export type QueenPocketedBy = 'none' | 'striker' | 'non_striker';

export interface MatchTossStateModel {
  tossWinnerPlayerId: number | null;
  tossDecision: TossDecision | null;
  firstStrikerPlayerId: number | null;
  firstStrikerColor: CarromColor | null;
}

export interface CarromBoardScoreModel {
  boardNumber: number;
  strikerPlayerId: number | null;
  strikerColor: CarromColor | null;
  strikerPocketed: number | null;
  nonStrikerPocketed: number | null;
  queenPocketedBy: QueenPocketedBy;
  pointsPlayer1: number;
  pointsPlayer2: number;
  winnerPlayerId: number | null;
  isTiebreaker: boolean;
  isSuddenDeath: boolean;
  notes: string;
}

export interface CarromSuddenDeathModel {
  winnerPlayerId: number;
  player1Hits: number;
  player2Hits: number;
  attempts: number;
}

export interface ScoreModel {
  id: string;
  tournamentId: number;
  roundId: number | null;
  matchId: number;
  roundNumber: number;
  tableNumber: number;
  player1Id: number;
  player2Id: number;
  confirmedScore1: number | null;
  confirmedScore2: number | null;
  confirmations: number;
  status: ScoreStatus;
  toss?: MatchTossStateModel | null;
  boards?: CarromBoardScoreModel[];
  suddenDeath?: CarromSuddenDeathModel | null;
  createdAt: string;
  updatedAt: string;
}
