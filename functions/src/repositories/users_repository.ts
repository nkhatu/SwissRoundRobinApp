/* ---------------------------------------------------------------------------
 * functions/src/repositories/users_repository.ts
 * ---------------------------------------------------------------------------
 *
 * Purpose:
 * - Implements persistence operations for user records and role/profile updates.
 * Architecture:
 * - Repository module encapsulating Firestore reads/writes for user entities.
 * - Provides typed user storage operations used by auth and profile endpoints.
 * Author: Neil Khatu
 * Copyright (c) The Khatu Family Trust
 */
import {Firestore} from 'firebase-admin/firestore';

import {UserModel, UserRole} from '../models/domain_models';

const USERS_COLLECTION = 'users';
const USER_EMAILS_COLLECTION = 'user_emails';

function normalizeHandle(handle: string): string {
  return handle.trim().toLowerCase();
}

function normalizeEmail(email: string): string {
  return email.trim().toLowerCase();
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

function fromDoc(
  snapshot: FirebaseFirestore.DocumentSnapshot,
): UserModel | null {
  if (!snapshot.exists) return null;
  const data = snapshot.data() ?? {};
  const handle = asText(data.handle);
  const handleAsEmail = handle.includes('@') ? normalizeEmail(handle) : '';
  const storedEmail = normalizeEmail(asText(data.email));
  const roleRaw = asText(data.role);
  const role: UserRole =
    roleRaw === 'admin' || roleRaw === 'viewer' ? roleRaw : 'player';
  return {
    id: asInt(data.id) || asInt(snapshot.id),
    email: storedEmail || handleAsEmail || null,
    handle,
    displayName: asText(data.display_name),
    firstName: asText(data.first_name) || null,
    lastName: asText(data.last_name) || null,
    passwordHash: asText(data.password_hash),
    role,
    createdAt: asText(data.created_at),
  };
}

export class UsersRepository {
  constructor(private readonly db: Firestore) {}

  async create(params: {
    email?: string | null;
    handle: string;
    displayName: string;
    firstName?: string | null;
    lastName?: string | null;
    passwordHash: string;
    role: UserRole;
    createdAt: string;
  }): Promise<UserModel> {
    const handle = normalizeHandle(params.handle);
    const email = params.email ? normalizeEmail(params.email) : '';

    return this.db.runTransaction(async (tx) => {
      const countersRef = this.db.doc('meta/counters');
      const emailRef = email.length
        ? this.db.collection(USER_EMAILS_COLLECTION).doc(email)
        : null;
      const existingByHandle = await tx.get(
        this.db
          .collection(USERS_COLLECTION)
          .where('handle', '==', handle)
          .limit(1),
      );
      if (!existingByHandle.empty) {
        throw new Error('HANDLE_EXISTS');
      }
      if (emailRef != null) {
        const existingEmail = await tx.get(emailRef);
        if (existingEmail.exists) {
          throw new Error('EMAIL_EXISTS');
        }
      }

      const counterSnapshot = await tx.get(countersRef);
      const userId = asInt(counterSnapshot.get('next_user_id')) || 1;
      const user: UserModel = {
        id: userId,
        email: email || null,
        handle,
        displayName: params.displayName.trim(),
        firstName: params.firstName?.trim() || null,
        lastName: params.lastName?.trim() || null,
        passwordHash: params.passwordHash,
        role: params.role,
        createdAt: params.createdAt,
      };

      tx.set(countersRef, {next_user_id: userId + 1}, {merge: true});
      tx.set(this.db.collection(USERS_COLLECTION).doc(String(userId)), {
        id: user.id,
        email: user.email,
        handle: user.handle,
        display_name: user.displayName,
        first_name: user.firstName,
        last_name: user.lastName,
        password_hash: user.passwordHash,
        role: user.role,
        created_at: user.createdAt,
      });
      if (emailRef != null) {
        tx.set(emailRef, {
          email: email,
          user_id: user.id,
          created_at: user.createdAt,
        });
      }
      return user;
    });
  }

  async findById(userId: number): Promise<UserModel | null> {
    const snapshot = await this.db
      .collection(USERS_COLLECTION)
      .doc(String(userId))
      .get();
    return fromDoc(snapshot);
  }

  async findByHandle(handle: string): Promise<UserModel | null> {
    const normalized = normalizeHandle(handle);
    const snapshot = await this.db
      .collection(USERS_COLLECTION)
      .where('handle', '==', normalized)
      .limit(1)
      .get();
    if (snapshot.empty) return null;
    return fromDoc(snapshot.docs[0]);
  }

  async findByEmail(email: string): Promise<UserModel | null> {
    const normalized = normalizeEmail(email);
    const snapshot = await this.db
      .collection(USERS_COLLECTION)
      .where('email', '==', normalized)
      .limit(1)
      .get();
    if (!snapshot.empty) {
      return fromDoc(snapshot.docs[0]);
    }

    // Backward compatibility for accounts created before email field existed.
    const legacy = await this.findByHandle(normalized);
    return legacy;
  }

  async list(): Promise<UserModel[]> {
    const snapshot = await this.db.collection(USERS_COLLECTION).get();
    return snapshot.docs
      .map((doc) => fromDoc(doc))
      .filter((item): item is UserModel => item !== null)
      .sort((a, b) => a.id - b.id);
  }

  async listPlayers(): Promise<UserModel[]> {
    const users = await this.list();
    return users.filter((user) => user.role === 'player');
  }
}
