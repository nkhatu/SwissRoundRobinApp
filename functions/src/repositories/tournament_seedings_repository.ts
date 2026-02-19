/* ---------------------------------------------------------------------------
 * functions/src/repositories/tournament_seedings_repository.ts
 * ---------------------------------------------------------------------------
 *
 * Purpose:
 * - Implements persistence operations for tournament seeding rows and ordering.
 * Architecture:
 * - Repository module encapsulating Firestore reads/writes for seeding entities.
 * - Provides typed seeding storage operations for setup and seeding endpoints.
 * Author: Neil Khatu
 * Copyright (c) The Khatu Family Trust
 */
import {Firestore} from 'firebase-admin/firestore';

import {
  TournamentSeedingMatchedBy,
  TournamentSeedingModel,
  TournamentSeedingSourceType,
} from '../models/domain_models';

const TOURNAMENT_SEEDINGS_COLLECTION = 'tournament_seedings';

export interface TournamentSeedingUpsertInput {
  playerId: number;
  seed: number;
  sourceType: TournamentSeedingSourceType;
  matchedBy: TournamentSeedingMatchedBy;
  rankingRank?: number | null;
  rankingYear?: number | null;
  rankingDescription?: string | null;
  displayName: string;
  handle: string;
  state?: string | null;
  country?: string | null;
  emailId?: string | null;
  isManual?: boolean;
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

function asOptionalText(value: unknown): string | null {
  const text = asText(value).trim();
  return text.length > 0 ? text : null;
}

function asSourceType(value: unknown): TournamentSeedingSourceType | null {
  const normalized = asText(value).trim().toLowerCase();
  if (normalized === 'national') return 'national';
  if (normalized === 'international') return 'international';
  if (normalized === 'new') return 'new';
  return null;
}

function asMatchedBy(value: unknown): TournamentSeedingMatchedBy | null {
  const normalized = asText(value).trim().toLowerCase();
  if (normalized === 'email') return 'email';
  if (normalized === 'name') return 'name';
  if (normalized === 'none') return 'none';
  return null;
}

function asBool(value: unknown, fallback = false): boolean {
  if (typeof value === 'boolean') return value;
  if (typeof value === 'number') return value !== 0;
  if (typeof value === 'string') {
    const normalized = value.trim().toLowerCase();
    if (!normalized) return fallback;
    if (normalized === 'true' || normalized === '1' || normalized === 'yes') {
      return true;
    }
    if (normalized === 'false' || normalized === '0' || normalized === 'no') {
      return false;
    }
  }
  return fallback;
}

function tournamentSeedingDocId(tournamentId: number, playerId: number): string {
  return `${tournamentId}_${playerId}`;
}

function fromDoc(
  snapshot: FirebaseFirestore.DocumentSnapshot,
): TournamentSeedingModel | null {
  if (!snapshot.exists) return null;
  const data = snapshot.data() ?? {};
  const tournamentId = asInt(data.tournament_id);
  const playerId = asInt(data.player_id);
  const seed = asInt(data.seed);
  const sourceType = asSourceType(data.source_type);
  const matchedBy = asMatchedBy(data.matched_by) ?? 'none';
  if (tournamentId < 1 || playerId < 1 || seed < 1 || sourceType == null) {
    return null;
  }
  const rankingRank = asInt(data.ranking_rank);
  const rankingYear = asInt(data.ranking_year);
  return {
    id: asText(data.id) || snapshot.id,
    tournamentId,
    playerId,
    seed,
    sourceType,
    matchedBy,
    rankingRank: rankingRank > 0 ? rankingRank : null,
    rankingYear: rankingYear > 0 ? rankingYear : null,
    rankingDescription: asOptionalText(data.ranking_description),
    displayName: asText(data.display_name).trim(),
    handle: asText(data.handle).trim(),
    state: asOptionalText(data.state),
    country: asOptionalText(data.country),
    emailId: asOptionalText(data.email_id),
    isManual: asBool(data.is_manual, false),
    createdAt: asText(data.created_at),
    updatedAt: asText(data.updated_at),
  };
}

function sortSeedings(rows: TournamentSeedingModel[]): void {
  rows.sort((a, b) => {
    if (a.seed !== b.seed) return a.seed - b.seed;
    return a.displayName.localeCompare(b.displayName, undefined, {
      sensitivity: 'base',
    });
  });
}

export class TournamentSeedingsRepository {
  constructor(private readonly db: Firestore) {}

  async listByTournament(tournamentId: number): Promise<TournamentSeedingModel[]> {
    const normalizedTournamentId = Math.trunc(tournamentId);
    if (normalizedTournamentId < 1) return [];
    const snapshot = await this.db
      .collection(TOURNAMENT_SEEDINGS_COLLECTION)
      .where('tournament_id', '==', normalizedTournamentId)
      .get();
    const rows = snapshot.docs
      .map((doc) => fromDoc(doc))
      .filter((row): row is TournamentSeedingModel => row !== null);
    sortSeedings(rows);
    return rows;
  }

  async clearByTournament(tournamentId: number): Promise<number> {
    const normalizedTournamentId = Math.trunc(tournamentId);
    if (normalizedTournamentId < 1) return 0;
    let deleted = 0;
    while (true) {
      const snapshot = await this.db
        .collection(TOURNAMENT_SEEDINGS_COLLECTION)
        .where('tournament_id', '==', normalizedTournamentId)
        .limit(400)
        .get();
      if (snapshot.empty) return deleted;
      deleted += snapshot.docs.length;
      const batch = this.db.batch();
      for (const doc of snapshot.docs) {
        batch.delete(doc.ref);
      }
      await batch.commit();
    }
  }

  async upsertRows(params: {
    tournamentId: number;
    rows: TournamentSeedingUpsertInput[];
    now: string;
  }): Promise<number> {
    const tournamentId = Math.trunc(params.tournamentId);
    if (tournamentId < 1 || params.rows.length === 0) return 0;
    let upserted = 0;
    for (let offset = 0; offset < params.rows.length; offset += 350) {
      const batch = this.db.batch();
      const chunk = params.rows.slice(offset, offset + 350);
      for (const row of chunk) {
        const playerId = Math.trunc(row.playerId);
        const seed = Math.trunc(row.seed);
        if (playerId < 1 || seed < 1) continue;
        const docId = tournamentSeedingDocId(tournamentId, playerId);
        const ref = this.db.collection(TOURNAMENT_SEEDINGS_COLLECTION).doc(docId);
        batch.set(
          ref,
          {
            id: docId,
            tournament_id: tournamentId,
            player_id: playerId,
            seed,
            source_type: row.sourceType,
            matched_by: row.matchedBy,
            ranking_rank:
              row.rankingRank == null || !Number.isFinite(row.rankingRank)
                ? null
                : Math.trunc(row.rankingRank),
            ranking_year:
              row.rankingYear == null || !Number.isFinite(row.rankingYear)
                ? null
                : Math.trunc(row.rankingYear),
            ranking_description: row.rankingDescription?.trim() || null,
            display_name: row.displayName.trim(),
            handle: row.handle.trim().toLowerCase(),
            state: row.state?.trim() || null,
            country: row.country?.trim() || null,
            email_id: row.emailId?.trim().toLowerCase() || null,
            is_manual: row.isManual ?? false,
            created_at: params.now,
            updated_at: params.now,
          },
          {merge: true},
        );
        upserted += 1;
      }
      await batch.commit();
    }
    return upserted;
  }

  async reorder(params: {
    tournamentId: number;
    orderedPlayerIds: number[];
    now: string;
  }): Promise<TournamentSeedingModel[]> {
    const tournamentId = Math.trunc(params.tournamentId);
    const orderedPlayerIds = params.orderedPlayerIds.map((value) =>
      Math.trunc(value),
    );
    if (tournamentId < 1 || orderedPlayerIds.length === 0) return [];
    const existingRows = await this.listByTournament(tournamentId);
    if (existingRows.length === 0) return [];

    const existingByPlayer = new Map<number, TournamentSeedingModel>();
    for (const row of existingRows) {
      existingByPlayer.set(row.playerId, row);
    }

    if (orderedPlayerIds.length !== existingByPlayer.size) {
      throw new Error('ordered_player_ids must include all seeded players.');
    }
    const seen = new Set<number>();
    for (const playerId of orderedPlayerIds) {
      if (playerId < 1) {
        throw new Error('ordered_player_ids must include only valid player ids.');
      }
      if (seen.has(playerId)) {
        throw new Error('ordered_player_ids contains duplicate player ids.');
      }
      if (!existingByPlayer.has(playerId)) {
        throw new Error(
          `ordered_player_ids includes unknown player id ${playerId}.`,
        );
      }
      seen.add(playerId);
    }

    for (let offset = 0; offset < orderedPlayerIds.length; offset += 350) {
      const batch = this.db.batch();
      const chunk = orderedPlayerIds.slice(offset, offset + 350);
      for (let index = 0; index < chunk.length; index += 1) {
        const playerId = chunk[index];
        const absoluteIndex = offset + index;
        const ref = this.db
          .collection(TOURNAMENT_SEEDINGS_COLLECTION)
          .doc(tournamentSeedingDocId(tournamentId, playerId));
        batch.set(
          ref,
          {
            seed: absoluteIndex + 1,
            is_manual: true,
            updated_at: params.now,
          },
          {merge: true},
        );
      }
      await batch.commit();
    }

    return this.listByTournament(tournamentId);
  }
}
