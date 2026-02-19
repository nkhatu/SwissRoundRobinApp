/* ---------------------------------------------------------------------------
 * functions/src/repositories/tournament_groups_repository.ts
 * ---------------------------------------------------------------------------
 *
 * Purpose:
 * - Persists tournament group assignments generated from seeding order.
 * Architecture:
 * - Repository module encapsulating Firestore reads/writes for grouped seeding rows.
 * - Provides typed storage operations consumed by create-groups workflow APIs.
 * Author: Neil Khatu
 * Copyright (c) The Khatu Family Trust
 */
import {Firestore} from 'firebase-admin/firestore';

import {
  TournamentGroupModel,
  TournamentGroupingMethod,
  TournamentSeedingSourceType,
} from '../models/domain_models';

const TOURNAMENT_GROUPS_COLLECTION = 'tournament_groups';

export interface TournamentGroupUpsertInput {
  playerId: number;
  seed: number;
  groupNumber: number;
  groupCount: number;
  method: TournamentGroupingMethod;
  displayName: string;
  handle: string;
  state?: string | null;
  country?: string | null;
  emailId?: string | null;
  sourceType: TournamentSeedingSourceType;
  rankingRank?: number | null;
  rankingYear?: number | null;
  rankingDescription?: string | null;
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

function asMethod(value: unknown): TournamentGroupingMethod | null {
  const normalized = asText(value).trim().toLowerCase();
  if (normalized === 'interleaved') return 'interleaved';
  if (normalized === 'snake') return 'snake';
  return null;
}

function groupDocId(tournamentId: number, playerId: number): string {
  return `${tournamentId}_${playerId}`;
}

function fromDoc(
  snapshot: FirebaseFirestore.DocumentSnapshot,
): TournamentGroupModel | null {
  if (!snapshot.exists) return null;
  const data = snapshot.data() ?? {};
  const tournamentId = asInt(data.tournament_id);
  const playerId = asInt(data.player_id);
  const seed = asInt(data.seed);
  const groupNumber = asInt(data.group_number);
  const groupCount = asInt(data.group_count);
  const method = asMethod(data.method);
  const sourceType = asSourceType(data.source_type);
  if (
    tournamentId < 1 ||
    playerId < 1 ||
    seed < 1 ||
    groupNumber < 1 ||
    groupCount < 1 ||
    method == null ||
    sourceType == null
  ) {
    return null;
  }

  const rankingRank = asInt(data.ranking_rank);
  const rankingYear = asInt(data.ranking_year);
  return {
    id: asText(data.id) || snapshot.id,
    tournamentId,
    playerId,
    seed,
    groupNumber,
    groupCount,
    method,
    displayName: asText(data.display_name).trim(),
    handle: asText(data.handle).trim(),
    state: asOptionalText(data.state),
    country: asOptionalText(data.country),
    emailId: asOptionalText(data.email_id),
    sourceType,
    rankingRank: rankingRank > 0 ? rankingRank : null,
    rankingYear: rankingYear > 0 ? rankingYear : null,
    rankingDescription: asOptionalText(data.ranking_description),
    createdAt: asText(data.created_at),
    updatedAt: asText(data.updated_at),
  };
}

function sortGroups(rows: TournamentGroupModel[]): void {
  rows.sort((a, b) => {
    if (a.groupNumber !== b.groupNumber) {
      return a.groupNumber - b.groupNumber;
    }
    if (a.seed !== b.seed) {
      return a.seed - b.seed;
    }
    return a.displayName.localeCompare(b.displayName, undefined, {
      sensitivity: 'base',
    });
  });
}

export class TournamentGroupsRepository {
  constructor(private readonly db: Firestore) {}

  async listByTournament(tournamentId: number): Promise<TournamentGroupModel[]> {
    const normalizedTournamentId = Math.trunc(tournamentId);
    if (normalizedTournamentId < 1) return [];
    const snapshot = await this.db
      .collection(TOURNAMENT_GROUPS_COLLECTION)
      .where('tournament_id', '==', normalizedTournamentId)
      .get();
    const rows = snapshot.docs
      .map((doc) => fromDoc(doc))
      .filter((row): row is TournamentGroupModel => row !== null);
    sortGroups(rows);
    return rows;
  }

  async clearByTournament(tournamentId: number): Promise<number> {
    const normalizedTournamentId = Math.trunc(tournamentId);
    if (normalizedTournamentId < 1) return 0;
    let deleted = 0;
    while (true) {
      const snapshot = await this.db
        .collection(TOURNAMENT_GROUPS_COLLECTION)
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
    rows: TournamentGroupUpsertInput[];
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
        const groupNumber = Math.trunc(row.groupNumber);
        const groupCount = Math.trunc(row.groupCount);
        if (
          playerId < 1 ||
          seed < 1 ||
          groupNumber < 1 ||
          groupCount < 1 ||
          groupNumber > groupCount
        ) {
          continue;
        }
        const docId = groupDocId(tournamentId, playerId);
        const ref = this.db.collection(TOURNAMENT_GROUPS_COLLECTION).doc(docId);
        batch.set(
          ref,
          {
            id: docId,
            tournament_id: tournamentId,
            player_id: playerId,
            seed,
            group_number: groupNumber,
            group_count: groupCount,
            method: row.method,
            display_name: row.displayName.trim(),
            handle: row.handle.trim().toLowerCase(),
            state: row.state?.trim() || null,
            country: row.country?.trim() || null,
            email_id: row.emailId?.trim().toLowerCase() || null,
            source_type: row.sourceType,
            ranking_rank:
              row.rankingRank == null || !Number.isFinite(row.rankingRank)
                ? null
                : Math.trunc(row.rankingRank),
            ranking_year:
              row.rankingYear == null || !Number.isFinite(row.rankingYear)
                ? null
                : Math.trunc(row.rankingYear),
            ranking_description: row.rankingDescription?.trim() || null,
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
}
