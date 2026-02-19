/* ---------------------------------------------------------------------------
 * functions/src/repositories/scores_repository.ts
 * ---------------------------------------------------------------------------
 *
 * Purpose:
 * - Implements persistence operations for score submissions and confirmations.
 * Architecture:
 * - Repository module encapsulating Firestore reads/writes for score entities.
 * - Provides typed score storage operations for match confirmation workflows.
 * Author: Neil Khatu
 * Copyright (c) The Khatu Family Trust
 */
import {Firestore} from 'firebase-admin/firestore';

import {ScoreModel, ScoreStatus} from '../models/domain_models';

const SCORES_COLLECTION = 'scores';

export interface ScoreSyncInput {
  matchId: number;
  roundNumber: number;
  tableNumber: number;
  player1Id: number;
  player2Id: number;
  confirmedScore1: number | null;
  confirmedScore2: number | null;
  confirmations: number;
  distinctConfirmations: number;
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

function asOptionalInt(value: unknown): number | null {
  if (value == null) return null;
  if (typeof value === 'number' && Number.isFinite(value)) {
    return Math.trunc(value);
  }
  if (typeof value === 'string' && value.trim().length > 0) {
    const parsed = Number(value);
    if (Number.isFinite(parsed)) return Math.trunc(parsed);
  }
  return null;
}

function asText(value: unknown): string {
  return typeof value === 'string' ? value : '';
}

function fromDoc(
  snapshot: FirebaseFirestore.DocumentSnapshot,
): ScoreModel | null {
  if (!snapshot.exists) return null;
  const data = snapshot.data() ?? {};
  const rawStatus = asText(data.status);
  const status: ScoreStatus =
    rawStatus === 'confirmed' || rawStatus === 'disputed'
      ? rawStatus
      : 'pending';

  return {
    id: asText(data.id) || snapshot.id,
    tournamentId: asInt(data.tournament_id),
    roundId: asOptionalInt(data.round_id),
    matchId: asInt(data.match_id),
    roundNumber: asInt(data.round_number),
    tableNumber: asInt(data.table_number),
    player1Id: asInt(data.player1_id),
    player2Id: asInt(data.player2_id),
    confirmedScore1: asOptionalInt(data.confirmed_score1),
    confirmedScore2: asOptionalInt(data.confirmed_score2),
    confirmations: asInt(data.confirmations),
    status,
    createdAt: asText(data.created_at),
    updatedAt: asText(data.updated_at),
  };
}

function scoreStatusFromInput(input: ScoreSyncInput): ScoreStatus {
  if (input.confirmedScore1 != null && input.confirmedScore2 != null) {
    return 'confirmed';
  }
  if (input.distinctConfirmations > 1) {
    return 'disputed';
  }
  return 'pending';
}

function scoreDocId(tournamentId: number, matchId: number): string {
  return `${tournamentId}_${matchId}`;
}

export class ScoresRepository {
  constructor(private readonly db: Firestore) {}

  async findByMatchId(
    tournamentId: number,
    matchId: number,
  ): Promise<ScoreModel | null> {
    const snapshot = await this.db
      .collection(SCORES_COLLECTION)
      .doc(scoreDocId(tournamentId, matchId))
      .get();
    return fromDoc(snapshot);
  }

  async listByTournament(tournamentId: number): Promise<ScoreModel[]> {
    const snapshot = await this.db
      .collection(SCORES_COLLECTION)
      .where('tournament_id', '==', tournamentId)
      .get();
    return snapshot.docs
      .map((doc) => fromDoc(doc))
      .filter((item): item is ScoreModel => item !== null)
      .sort(
        (a, b) =>
          a.roundNumber - b.roundNumber ||
          a.tableNumber - b.tableNumber ||
          a.matchId - b.matchId,
      );
  }

  async upsertScore(params: {
    tournamentId: number;
    roundId: number | null;
    input: ScoreSyncInput;
    now: string;
  }): Promise<ScoreModel> {
    const docId = scoreDocId(params.tournamentId, params.input.matchId);
    const ref = this.db.collection(SCORES_COLLECTION).doc(docId);
    const current = fromDoc(await ref.get());

    const row: ScoreModel = {
      id: docId,
      tournamentId: params.tournamentId,
      roundId: params.roundId,
      matchId: params.input.matchId,
      roundNumber: params.input.roundNumber,
      tableNumber: params.input.tableNumber,
      player1Id: params.input.player1Id,
      player2Id: params.input.player2Id,
      confirmedScore1: params.input.confirmedScore1,
      confirmedScore2: params.input.confirmedScore2,
      confirmations: params.input.confirmations,
      status: scoreStatusFromInput(params.input),
      createdAt: current?.createdAt ?? params.now,
      updatedAt: params.now,
    };

    await ref.set(
      {
        id: row.id,
        tournament_id: row.tournamentId,
        round_id: row.roundId,
        match_id: row.matchId,
        round_number: row.roundNumber,
        table_number: row.tableNumber,
        player1_id: row.player1Id,
        player2_id: row.player2Id,
        confirmed_score1: row.confirmedScore1,
        confirmed_score2: row.confirmedScore2,
        confirmations: row.confirmations,
        status: row.status,
        created_at: row.createdAt,
        updated_at: row.updatedAt,
      },
      {merge: true},
    );

    return row;
  }

  async syncFromMatches(params: {
    tournamentId: number;
    roundIdByRoundNumber: Map<number, number>;
    scores: ScoreSyncInput[];
    now: string;
  }): Promise<ScoreModel[]> {
    const output: ScoreModel[] = [];
    for (const score of params.scores) {
      output.push(
        await this.upsertScore({
          tournamentId: params.tournamentId,
          roundId: params.roundIdByRoundNumber.get(score.roundNumber) ?? null,
          input: score,
          now: params.now,
        }),
      );
    }
    return output;
  }
}
