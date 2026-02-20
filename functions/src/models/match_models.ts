/* ---------------------------------------------------------------------------
 * functions/src/models/match_models.ts
 * ---------------------------------------------------------------------------
 *
 * Purpose:
 * - Tracks matches, rounds, and associated carrom board data.
 * Architecture:
 * - Keeps match scoring contracts separate from tournament metadata for clarity.
 * Author: Neil Khatu
 * Copyright (c) The Khatu Family Trust
 */

import {
  CarromColor,
  QueenPocketedBy,
  ScoreStatus,
  TossDecision,
} from './enums';

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

export interface MatchModel {
  id: number;
  tournamentId: number | null;
  groupNumber: number | null;
  roundNumber: number;
  tableNumber: number;
  player1Id: number;
  player2Id: number;
  confirmedScore1: number | null;
  confirmedScore2: number | null;
  confirmedAt: string | null;
  toss: MatchTossStateModel | null;
  boards: CarromBoardScoreModel[];
  suddenDeath: CarromSuddenDeathModel | null;
}

export interface RoundModel {
  id: number;
  tournamentId: number;
  roundNumber: number;
  isComplete: boolean;
  createdAt: string;
  updatedAt: string;
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
