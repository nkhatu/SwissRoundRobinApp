/* ---------------------------------------------------------------------------
 * functions/src/repositories/rounds_repository.ts
 * ---------------------------------------------------------------------------
 *
 * Purpose:
 * - Implements persistence operations for round records and scheduling metadata.
 * Architecture:
 * - Repository module encapsulating Firestore reads/writes for round entities.
 * - Provides typed round storage operations consumed by matchup and standings flows.
 * Author: Neil Khatu
 * Copyright (c) The Khatu Family Trust
 */
import {Firestore} from 'firebase-admin/firestore';

import {RoundModel} from '../models/domain_models';
import {CounterRepository} from './counter_repository';

const ROUNDS_COLLECTION = 'rounds';

export interface RoundSyncInput {
  roundNumber: number;
  isComplete: boolean;
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

function asBool(value: unknown): boolean {
  return value === true;
}

function asText(value: unknown): string {
  return typeof value === 'string' ? value : '';
}

function fromDoc(
  snapshot: FirebaseFirestore.DocumentSnapshot,
): RoundModel | null {
  if (!snapshot.exists) return null;
  const data = snapshot.data() ?? {};
  return {
    id: asInt(data.id) || asInt(snapshot.id),
    tournamentId: asInt(data.tournament_id),
    roundNumber: asInt(data.round_number),
    isComplete: asBool(data.is_complete),
    createdAt: asText(data.created_at),
    updatedAt: asText(data.updated_at),
  };
}

function roundKey(tournamentId: number, roundNumber: number): string {
  return `${tournamentId}_${roundNumber}`;
}

export class RoundsRepository {
  constructor(
    private readonly db: Firestore,
    private readonly counters: CounterRepository,
  ) {}

  async listByTournament(tournamentId: number): Promise<RoundModel[]> {
    const snapshot = await this.db
      .collection(ROUNDS_COLLECTION)
      .where('tournament_id', '==', tournamentId)
      .get();
    return snapshot.docs
      .map((doc) => fromDoc(doc))
      .filter((item): item is RoundModel => item !== null)
      .sort((a, b) => a.roundNumber - b.roundNumber);
  }

  async findByTournamentRound(
    tournamentId: number,
    roundNumber: number,
  ): Promise<RoundModel | null> {
    const snapshot = await this.db
      .collection(ROUNDS_COLLECTION)
      .doc(roundKey(tournamentId, roundNumber))
      .get();
    return fromDoc(snapshot);
  }

  async upsertRound(input: {
    tournamentId: number;
    roundNumber: number;
    isComplete: boolean;
    now: string;
  }): Promise<RoundModel> {
    const ref = this.db
      .collection(ROUNDS_COLLECTION)
      .doc(roundKey(input.tournamentId, input.roundNumber));
    const current = fromDoc(await ref.get());
    const id = current?.id ?? (await this.counters.next('next_round_id'));
    const createdAt = current?.createdAt ?? input.now;

    const row: RoundModel = {
      id,
      tournamentId: input.tournamentId,
      roundNumber: input.roundNumber,
      isComplete: input.isComplete,
      createdAt,
      updatedAt: input.now,
    };

    await ref.set(
      {
        id: row.id,
        tournament_id: row.tournamentId,
        round_number: row.roundNumber,
        is_complete: row.isComplete,
        created_at: row.createdAt,
        updated_at: row.updatedAt,
      },
      {merge: true},
    );
    return row;
  }

  async syncFromRoundSummaries(params: {
    tournamentId: number;
    rounds: RoundSyncInput[];
    now: string;
  }): Promise<RoundModel[]> {
    const output: RoundModel[] = [];
    for (const round of params.rounds) {
      output.push(
        await this.upsertRound({
          tournamentId: params.tournamentId,
          roundNumber: round.roundNumber,
          isComplete: round.isComplete,
          now: params.now,
        }),
      );
    }
    return output;
  }
}
