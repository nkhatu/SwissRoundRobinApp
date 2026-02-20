/* ---------------------------------------------------------------------------
 * functions/src/models/user_models.ts
 * ---------------------------------------------------------------------------
 *
 * Purpose:
 * - Defines the Firestore user/player contracts.
 * Architecture:
 * - Aligns with the SQL-style auth tables persisted via Realtime Database/Firestore triggers.
 * Author: Neil Khatu
 * Copyright (c) The Khatu Family Trust
 */

import {UserRole} from './enums';

export interface UserModel {
  id: number;
  email?: string | null;
  handle: string;
  displayName: string;
  firstName?: string | null;
  lastName?: string | null;
  passwordHash: string;
  role: UserRole;
  createdAt: string;
}

export interface PlayerModel {
  id: number;
  userId: number;
  handle: string;
  playerName: string;
  displayName: string;
  state: string | null;
  country: string | null;
  emailId: string | null;
  registeredFlag: boolean;
  tshirtSize: string | null;
  feesPaidFlag: boolean;
  phoneNumber: string | null;
  createdAt: string;
}
