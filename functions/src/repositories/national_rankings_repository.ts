/* ---------------------------------------------------------------------------
 * functions/src/repositories/national_rankings_repository.ts
 * ---------------------------------------------------------------------------
 *
 * Purpose:
 * - Implements persistence operations for national ranking lists and ranking rows.
 * Architecture:
 * - Repository module encapsulating Firestore ranking read/write queries.
 * - Provides typed ranking storage operations for upload and selection workflows.
 * Author: Neil Khatu
 * Copyright (c) The Khatu Family Trust
 */
import {Firestore} from 'firebase-admin/firestore';

import {NationalRankingModel} from '../models/domain_models';

const NATIONAL_RANKINGS_COLLECTION = 'national_rankings';

export interface NationalRankingUpsertInput {
  rank: number;
  playerName: string;
  rankingDescription: string;
  state?: string | null;
  country?: string | null;
  emailId?: string | null;
  rankingPoints?: number | null;
  rankingYear: number;
  lastUpdated?: string | null;
}

export interface NationalRankingListEntry {
  rankingYear: number;
  rankingDescription: string;
}

const DEFAULT_RANKING_DESCRIPTION = 'Default';

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

function asOptionalNumber(value: unknown): number | null {
  if (value == null) return null;
  if (typeof value === 'number' && Number.isFinite(value)) return value;
  if (typeof value === 'string' && value.trim().length > 0) {
    const parsed = Number(value);
    if (Number.isFinite(parsed)) return parsed;
  }
  return null;
}

function asText(value: unknown): string {
  return typeof value === 'string' ? value : '';
}

function asOptionalText(value: unknown): string | null {
  const text = asText(value).trim();
  return text.length > 0 ? text : null;
}

function asIsoDateTime(value: unknown): string | null {
  const raw = asText(value).trim();
  if (!raw) return null;
  const parsed = Date.parse(raw);
  if (Number.isNaN(parsed)) return null;
  return new Date(parsed).toISOString();
}

function normalizeRankingDescription(value: unknown): string {
  const text = asText(value).trim();
  return text.length > 0 ? text : DEFAULT_RANKING_DESCRIPTION;
}

function rankingDescriptionKey(description: string): string {
  const normalized = description
    .trim()
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '_')
    .replace(/_+/g, '_')
    .replace(/^_+|_+$/g, '');
  return normalized.length > 0 ? normalized.slice(0, 64) : 'default';
}

function rankingDocId(
  rankingYear: number,
  rankingDescription: string,
  rank: number,
): string {
  return `${rankingYear}_${rankingDescriptionKey(rankingDescription)}_${rank}`;
}

function fromDoc(
  snapshot: FirebaseFirestore.DocumentSnapshot,
): NationalRankingModel | null {
  if (!snapshot.exists) return null;
  const data = snapshot.data() ?? {};
  const rankingYear = asInt(data.ranking_year);
  const rank = asInt(data.rank);
  if (rankingYear < 1 || rank < 1) return null;
  return {
    id: asText(data.id) || snapshot.id,
    rankingYear,
    rankingDescription: normalizeRankingDescription(data.ranking_description),
    rank,
    playerName: asText(data.player_name),
    state: asOptionalText(data.state),
    country: asOptionalText(data.country),
    emailId: asOptionalText(data.email_id),
    rankingPoints: asOptionalNumber(data.ranking_points),
    lastUpdated: asIsoDateTime(data.last_updated),
    createdAt: asText(data.created_at),
    updatedAt: asText(data.updated_at),
  };
}

function uniqueSortedYears(years: Iterable<number>): number[] {
  return [...new Set<number>(years)].sort((a, b) => b - a);
}

function uniqueSortedRankings(
  rankings: Iterable<NationalRankingListEntry>,
): NationalRankingListEntry[] {
  const deduped = new Map<string, NationalRankingListEntry>();
  for (const entry of rankings) {
    const rankingYear = Math.trunc(entry.rankingYear);
    const rankingDescription = normalizeRankingDescription(
      entry.rankingDescription,
    );
    if (rankingYear < 1) continue;
    const key = `${rankingYear}:${rankingDescription.toLowerCase()}`;
    if (deduped.has(key)) continue;
    deduped.set(key, {
      rankingYear,
      rankingDescription,
    });
  }
  return [...deduped.values()].sort((a, b) => {
    if (a.rankingYear !== b.rankingYear) {
      return b.rankingYear - a.rankingYear;
    }
    return a.rankingDescription.localeCompare(b.rankingDescription, undefined, {
      sensitivity: 'base',
    });
  });
}

export class NationalRankingsRepository {
  constructor(private readonly db: Firestore) {}

  async listDistinctYears(): Promise<number[]> {
    const rankings = await this.listDistinctRankings();
    return uniqueSortedYears(rankings.map((entry) => entry.rankingYear));
  }

  async listDistinctRankings(): Promise<NationalRankingListEntry[]> {
    const snapshot = await this.db.collection(NATIONAL_RANKINGS_COLLECTION).get();
    const rankings: NationalRankingListEntry[] = [];
    for (const doc of snapshot.docs) {
      const model = fromDoc(doc);
      if (model == null) continue;
      rankings.push({
        rankingYear: model.rankingYear,
        rankingDescription: model.rankingDescription,
      });
    }
    return uniqueSortedRankings(rankings);
  }

  async hasYear(rankingYear: number): Promise<boolean> {
    const snapshot = await this.db
      .collection(NATIONAL_RANKINGS_COLLECTION)
      .where('ranking_year', '==', rankingYear)
      .limit(1)
      .get();
    return !snapshot.empty;
  }

  async hasRanking(
    rankingYear: number,
    rankingDescription: string,
  ): Promise<boolean> {
    const normalizedDescription = normalizeRankingDescription(rankingDescription);
    const snapshot = await this.db
      .collection(NATIONAL_RANKINGS_COLLECTION)
      .where('ranking_year', '==', rankingYear)
      .get();
    for (const doc of snapshot.docs) {
      const model = fromDoc(doc);
      if (model == null) continue;
      if (
        model.rankingDescription.localeCompare(normalizedDescription, undefined, {
          sensitivity: 'base',
        }) === 0
      ) {
        return true;
      }
    }
    return false;
  }

  async deleteRankingList(params: {
    rankingYear: number;
    rankingDescription: string;
  }): Promise<number> {
    const rankingYear = Math.trunc(params.rankingYear);
    const normalizedDescription = normalizeRankingDescription(
      params.rankingDescription,
    );
    if (rankingYear < 1) return 0;

    const snapshot = await this.db
      .collection(NATIONAL_RANKINGS_COLLECTION)
      .where('ranking_year', '==', rankingYear)
      .get();
    if (snapshot.empty) return 0;

    const refs = snapshot.docs
      .filter((doc) => {
        const model = fromDoc(doc);
        if (model == null) return false;
        return (
          model.rankingDescription.localeCompare(
            normalizedDescription,
            undefined,
            {sensitivity: 'base'},
          ) === 0
        );
      })
      .map((doc) => doc.ref);
    if (refs.length === 0) return 0;

    for (let offset = 0; offset < refs.length; offset += 400) {
      const batch = this.db.batch();
      const chunk = refs.slice(offset, offset + 400);
      for (const ref of chunk) {
        batch.delete(ref);
      }
      await batch.commit();
    }
    return refs.length;
  }

  async listRows(params: {
    rankingYear: number;
    rankingDescription: string;
  }): Promise<NationalRankingModel[]> {
    const rankingYear = Math.trunc(params.rankingYear);
    const normalizedDescription = normalizeRankingDescription(
      params.rankingDescription,
    );
    if (rankingYear < 1) return [];

    const snapshot = await this.db
      .collection(NATIONAL_RANKINGS_COLLECTION)
      .where('ranking_year', '==', rankingYear)
      .get();
    if (snapshot.empty) return [];

    const rows = snapshot.docs
      .map((doc) => fromDoc(doc))
      .filter((row): row is NationalRankingModel => row !== null)
      .filter(
        (row) =>
          row.rankingDescription.localeCompare(normalizedDescription, undefined, {
            sensitivity: 'base',
          }) === 0,
      );
    rows.sort((a, b) => {
      if (a.rank !== b.rank) return a.rank - b.rank;
      return a.playerName.localeCompare(b.playerName, undefined, {
        sensitivity: 'base',
      });
    });
    return rows;
  }

  async upsertRows(params: {
    rows: NationalRankingUpsertInput[];
    now: string;
  }): Promise<{
    upsertedRows: number;
    years: number[];
    rankings: NationalRankingListEntry[];
  }> {
    const years = new Set<number>();
    const rankings = new Map<string, NationalRankingListEntry>();
    let upsertedRows = 0;
    const rows = params.rows;

    for (let offset = 0; offset < rows.length; offset += 400) {
      const batch = this.db.batch();
      const chunk = rows.slice(offset, offset + 400);
      for (const row of chunk) {
        const rank = Math.trunc(row.rank);
        const rankingYear = Math.trunc(row.rankingYear);
        const rankingDescription = normalizeRankingDescription(
          row.rankingDescription,
        );
        if (rank < 1 || rankingYear < 1) continue;

        const docId = rankingDocId(rankingYear, rankingDescription, rank);
        const ref = this.db.collection(NATIONAL_RANKINGS_COLLECTION).doc(docId);
        batch.set(
          ref,
          {
            id: docId,
            ranking_year: rankingYear,
            ranking_description: rankingDescription,
            rank,
            player_name: row.playerName.trim(),
            state: row.state?.trim() || null,
            country: row.country?.trim() || null,
            email_id: row.emailId?.trim().toLowerCase() || null,
            ranking_points:
              row.rankingPoints == null || !Number.isFinite(row.rankingPoints)
                ? null
                : row.rankingPoints,
            last_updated: asIsoDateTime(row.lastUpdated) ?? null,
            created_at: params.now,
            updated_at: params.now,
          },
          {merge: true},
        );
        years.add(rankingYear);
        rankings.set(`${rankingYear}:${rankingDescription.toLowerCase()}`, {
          rankingYear,
          rankingDescription,
        });
        upsertedRows += 1;
      }
      await batch.commit();
    }

    return {
      upsertedRows,
      years: uniqueSortedYears(years),
      rankings: uniqueSortedRankings(rankings.values()),
    };
  }
}
