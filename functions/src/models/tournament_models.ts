/* ---------------------------------------------------------------------------
 * functions/src/models/tournament_models.ts
 * ---------------------------------------------------------------------------
 *
 * Purpose:
 * - Houses tournament metadata, workflow, seeding, and grouping DTOs.
 * Architecture:
 * - Organizes tournament-centric contracts for repository use.
 * Author: Neil Khatu
 * Copyright (c) The Khatu Family Trust
 */

import {
  TournamentCategory,
  TournamentGroupingMethod,
  TournamentSeedingMatchedBy,
  TournamentSeedingSourceType,
  TournamentStatus,
  TournamentSubCategory,
  TournamentSubType,
  TournamentType,
  TournamentWorkflowStepKey,
  TournamentWorkflowStepStatus,
} from './enums';

export interface PersonNameModel {
  fullName?: string;
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

export interface TournamentWorkflowStepModel {
  key: TournamentWorkflowStepKey;
  status: TournamentWorkflowStepStatus;
  completedAt: string | null;
}

export interface TournamentWorkflowModel {
  steps: TournamentWorkflowStepModel[];
  updatedAt: string;
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

export interface TournamentGroupModel {
  id: string;
  tournamentId: number;
  playerId: number;
  seed: number;
  groupNumber: number;
  groupCount: number;
  method: TournamentGroupingMethod;
  displayName: string;
  handle: string;
  state: string | null;
  country: string | null;
  emailId: string | null;
  sourceType: TournamentSeedingSourceType;
  rankingRank: number | null;
  rankingYear: number | null;
  rankingDescription: string | null;
  createdAt: string;
  updatedAt: string;
}
