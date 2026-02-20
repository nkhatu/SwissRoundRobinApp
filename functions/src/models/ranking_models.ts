/* ---------------------------------------------------------------------------
 * functions/src/models/ranking_models.ts
 * ---------------------------------------------------------------------------
 *
 * Purpose:
 * - Captures the national ranking document shape.
 * Architecture:
 * - Mirrors the Firestore ranking collection used for seeding.
 * Author: Neil Khatu
 * Copyright (c) The Khatu Family Trust
 */

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
