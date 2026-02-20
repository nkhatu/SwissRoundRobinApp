/* ---------------------------------------------------------------------------
 * functions/src/models/enums.ts
 * ---------------------------------------------------------------------------
 *
 * Purpose:
 * - Centralizes the shared enum unions used across the Cloud Functions domain.
 * Architecture:
 * - Exports literal type aliases describing roles, tournament status/metadata, and match/bookkeeping enums.
 * Author: Neil Khatu
 * Copyright (c) The Khatu Family Trust
 */

export type UserRole = 'player' | 'viewer' | 'admin';

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

export type TournamentSeedingSourceType = 'national' | 'international' | 'new';
export type TournamentSeedingMatchedBy = 'email' | 'name' | 'none';
export type TournamentGroupingMethod = 'interleaved' | 'snake';

export type ScoreStatus = 'pending' | 'disputed' | 'confirmed';

export type TossDecision = 'strike_first' | 'choose_side';
export type CarromColor = 'white' | 'black';
export type QueenPocketedBy = 'none' | 'striker' | 'non_striker';
