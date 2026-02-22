/* ---------------------------------------------------------------------------
 * functions/src/repositories/players_repository.ts
 * ---------------------------------------------------------------------------
 *
 * Purpose:
 * - Implements persistence operations for player records and user-player synchronization.
 * Architecture:
 * - Repository module encapsulating Firestore reads/writes for player entities.
 * - Provides typed player storage operations used by auth and upload workflows.
 * Author: Neil Khatu
 * Copyright (c) The Khatu Family Trust
 */
import {Firestore} from 'firebase-admin/firestore';

import {PlayerModel, UserModel} from '../models/domain_models';

const PLAYERS_COLLECTION = 'players';

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

function normalizedOptionalText(value: string | null | undefined): string | null {
  const text = (value ?? '').trim();
  return text.length > 0 ? text : null;
}

function asBool(value: unknown, fallback = false): boolean {
  if (typeof value === 'boolean') return value;
  if (typeof value === 'number') return value !== 0;
  if (typeof value !== 'string') return fallback;
  const normalized = value.trim().toLowerCase();
  if (!normalized) return fallback;
  return (
    normalized === '1' ||
    normalized === 'true' ||
    normalized === 'yes' ||
    normalized === 'y'
  );
}

function fromDoc(
  snapshot: FirebaseFirestore.DocumentSnapshot,
): PlayerModel | null {
  if (!snapshot.exists) return null;
  const data = snapshot.data() ?? {};
  const displayName = asText(data.display_name);
  const playerName = asText(data.player_name).trim() || displayName;
  return {
    id: asInt(data.id) || asInt(snapshot.id),
    userId: asInt(data.user_id),
    handle: asText(data.handle),
    playerName,
    displayName,
    state: asOptionalText(data.state),
    country: asOptionalText(data.country),
    emailId: asOptionalText(data.email_id ?? data.email),
    registeredFlag: asBool(data.registered_flag, false),
    tshirtSize: asOptionalText(data.t_shirt_size ?? data.tshirt_size),
    feesPaidFlag: asBool(data.fees_paid_flag, false),
    phoneNumber: asOptionalText(data.phone_number ?? data.phone),
    createdAt: asText(data.created_at),
  };
}

export class PlayersRepository {
  constructor(private readonly db: Firestore) {}

  async upsertFromUser(
    user: UserModel,
    profile?: {
      playerName?: string;
      state?: string;
      country?: string;
      emailId?: string;
      registeredFlag?: boolean;
      tshirtSize?: string;
      feesPaidFlag?: boolean;
      phoneNumber?: string;
    },
  ): Promise<PlayerModel | null> {
    if (user.role === 'viewer') return null;

    const docRef = this.db.collection(PLAYERS_COLLECTION).doc(String(user.id));
    const snapshot = await docRef.get();
    const existing = fromDoc(snapshot);
    const createdAt = existing?.createdAt ?? user.createdAt;

    const player: PlayerModel = {
      id: user.id,
      userId: user.id,
      handle: user.handle,
      playerName:
        profile?.playerName?.trim() ||
        existing?.playerName ||
        user.displayName,
      displayName: user.displayName,
      state: profile?.state?.trim() || existing?.state || null,
      country: profile?.country?.trim() || existing?.country || null,
      emailId:
        normalizedOptionalText(profile?.emailId) ??
        existing?.emailId ??
        normalizedOptionalText(user.email),
      registeredFlag: profile?.registeredFlag ?? existing?.registeredFlag ?? false,
      tshirtSize: profile?.tshirtSize?.trim() || existing?.tshirtSize || null,
      feesPaidFlag: profile?.feesPaidFlag ?? existing?.feesPaidFlag ?? false,
      phoneNumber: profile?.phoneNumber?.trim() || existing?.phoneNumber || null,
      createdAt,
    };

    await docRef.set(
      {
        id: player.id,
        user_id: player.userId,
        handle: player.handle,
        player_name: player.playerName,
        display_name: player.displayName,
        state: player.state,
        country: player.country,
        email_id: player.emailId,
        registered_flag: player.registeredFlag,
        t_shirt_size: player.tshirtSize,
        fees_paid_flag: player.feesPaidFlag,
        phone_number: player.phoneNumber,
        created_at: player.createdAt,
      },
      {merge: true},
    );

    return player;
  }

  async findById(playerId: number): Promise<PlayerModel | null> {
    const snapshot = await this.db
      .collection(PLAYERS_COLLECTION)
      .doc(String(playerId))
      .get();
    return fromDoc(snapshot);
  }

  async findByUserId(userId: number): Promise<PlayerModel | null> {
    return this.findById(userId);
  }

  async list(): Promise<PlayerModel[]> {
    const snapshot = await this.db.collection(PLAYERS_COLLECTION).get();
    return snapshot.docs
      .map((doc) => fromDoc(doc))
      .filter((item): item is PlayerModel => item !== null)
      .sort((a, b) => a.id - b.id);
  }
}
