/* ---------------------------------------------------------------------------
 * functions/src/repositories/counter_repository.ts
 * ---------------------------------------------------------------------------
 *
 * Purpose:
 * - Implements persistence operations for numeric counters used by record allocation.
 * Architecture:
 * - Repository module encapsulating Firestore counter reads/updates.
 * - Provides atomic counter access used during tournament data creation.
 * Author: Neil Khatu
 * Copyright (c) The Khatu Family Trust
 */
import {Firestore} from 'firebase-admin/firestore';

export class CounterRepository {
  constructor(
    private readonly db: Firestore,
    private readonly counterDocPath = 'meta/counters',
  ) {}

  async next(counterField: string): Promise<number> {
    return this.db.runTransaction(async (tx) => {
      const ref = this.db.doc(this.counterDocPath);
      const snapshot = await tx.get(ref);
      const raw = snapshot.get(counterField);
      const current =
        typeof raw === 'number' && Number.isFinite(raw)
          ? Math.trunc(raw)
          : 1;

      tx.set(ref, {[counterField]: current + 1}, {merge: true});
      return current;
    });
  }
}
