/* ---------------------------------------------------------------------------
 * functions/src/context.ts
 * ---------------------------------------------------------------------------
 *
 * Purpose:
 * - Provides centralized Firebase context/constants reused across services.
 * Architecture:
 * - Initializes Firebase once and exposes Firestore, collection names, and global counters.
 * Author: Neil Khatu
 * Copyright (c) The Khatu Family Trust
 */
import {initializeApp} from 'firebase-admin/app';
import {getFirestore} from 'firebase-admin/firestore';

initializeApp();

export const db = getFirestore();

export const countersRef = db.doc('meta/counters');

export const COLLECTIONS = {
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

export const CARROM_RULES = {
  regulationBoards: 8,
  tieBreakerBoard: 9,
  maxBoardPoints: 13,
  maxMenPerColor: 9,
  queenPoints: 3,
  suddenDeathBonusPoint: 1,
  maxSuddenDeathAttempts: 3,
};
