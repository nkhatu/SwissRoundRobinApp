/* ---------------------------------------------------------------------------
 * functions/src/helpers/utils.ts
 * ---------------------------------------------------------------------------
 *
 * Purpose:
 * - Collection of shared normalization, parsing, and validation helpers used by
 *   the SRR backend services.
 * Architecture:
 * - Provides a focused surface for data conversion logic so route handlers
 *   and services remain lean.
 * Author: Neil Khatu
 * Copyright (c) The Khatu Family Trust
 */

export type Role = 'player' | 'viewer' | 'admin';
export class HttpError extends Error {
  constructor(
    public readonly statusCode: number,
    public readonly detail: string,
  ) {
    super(detail);
  }
}

export function utcNow(): string {
  return new Date().toISOString();
}

export function normalizeHandle(handle: string): string {
  return handle.trim().toLowerCase();
}

export function normalizeEmail(value: string): string {
  return value.trim().toLowerCase();
}

export function isValidEmail(value: string): boolean {
  return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(value);
}

export function matchPoints(
  score1: number,
  score2: number,
): [number, number] {
  if (score1 > score2) return [3, 0];
  if (score2 > score1) return [0, 3];
  return [1, 1];
}

export function toInt(value: unknown, fallback: number): number {
  if (typeof value === 'number' && Number.isFinite(value)) {
    return Math.trunc(value);
  }
  if (typeof value === 'string' && value.trim().length > 0) {
    const parsed = Number(value);
    if (Number.isFinite(parsed)) return Math.trunc(parsed);
  }
  return fallback;
}

export function toOptionalInt(value: unknown): number | null {
  if (value === null || value === undefined) return null;
  if (typeof value === 'number' && Number.isFinite(value)) {
    return Math.trunc(value);
  }
  if (typeof value === 'string' && value.trim().length > 0) {
    const parsed = Number(value);
    if (Number.isFinite(parsed)) return Math.trunc(parsed);
  }
  return null;
}

export function toText(value: unknown, fallback = ''): string {
  if (typeof value === 'string') return value;
  return fallback;
}

export function parseBooleanQuery(value: unknown): boolean {
  if (typeof value === 'boolean') return value;
  if (typeof value !== 'string') return false;
  const normalized = value.trim().toLowerCase();
  return normalized === '1' || normalized === 'true' || normalized === 'yes';
}

export function parsePositiveInt(
  value: unknown,
  fieldName: string,
): number {
  const parsed = toInt(value, -1);
  if (parsed < 1) {
    throw new HttpError(422, `${fieldName} must be a positive integer.`);
  }
  return parsed;
}

export function parsePositiveEvenInt(
  value: unknown,
  fieldName: string,
): number {
  const parsed = parsePositiveInt(value, fieldName);
  if (parsed % 2 !== 0) {
    throw new HttpError(422, `${fieldName} must be an even integer.`);
  }
  return parsed;
}

export function parseScore(value: unknown, fieldName: string): number {
  const parsed = toInt(value, Number.NaN);
  if (!Number.isInteger(parsed) || parsed < 0 || parsed > 999) {
    throw new HttpError(
      422,
      `${fieldName} must be an integer between 0 and 999.`,
    );
  }
  return parsed;
}

export function parseNumberInRange(
  value: unknown,
  fieldName: string,
  min: number,
  max: number,
): number {
  let parsed = Number.NaN;
  if (typeof value === 'number') {
    parsed = value;
  } else if (typeof value === 'string' && value.trim().length > 0) {
    parsed = Number(value);
  }
  if (!Number.isFinite(parsed) || parsed < min || parsed > max) {
    throw new HttpError(
      422,
      `${fieldName} must be between ${min} and ${max}.`,
    );
  }
  return parsed;
}

export function parseIsoDateTime(value: unknown, fieldName: string): string {
  const raw = toText(value).trim();
  if (!raw) {
    throw new HttpError(422, `${fieldName} is required.`);
  }
  const parsed = Date.parse(raw);
  if (Number.isNaN(parsed)) {
    throw new HttpError(
      422,
      `${fieldName} must be a valid date-time.`,
    );
  }
  return new Date(parsed).toISOString();
}

export function parseEnumValue<T extends string>(
  value: unknown,
  fieldName: string,
  allowed: readonly T[],
  aliases?: Record<string, T>,
): T {
  const normalized = toText(value).trim().toLowerCase();
  const mapped = (aliases?.[normalized] as T) ?? (normalized as T);
  if (!allowed.includes(mapped as T)) {
    throw new HttpError(
      422,
      `${fieldName} must be one of: ${allowed.join(', ')}.`,
    );
  }
  return mapped;
}

export function toBool(value: unknown, fallback = false): boolean {
  if (typeof value === 'boolean') return value;
  if (typeof value === 'string') {
    const normalized = value.trim().toLowerCase();
    return normalized === '1' || normalized === 'true' || normalized === 'yes';
  }
  if (typeof value === 'number') {
    return value !== 0;
  }
  return fallback;
}

export function assertLength(
  value: string,
  field: string,
  min: number,
  max: number,
): void {
  if (value.length < min || value.length > max) {
    throw new HttpError(
      422,
      `${field} must be between ${min} and ${max} characters.`,
    );
  }
}

export function parseOptionalPlayerText(
  value: unknown,
  fieldName: string,
  maxLength: number,
): string | undefined {
  const text = toText(value).trim();
  if (!text) return undefined;
  assertLength(text, fieldName, 1, maxLength);
  return text;
}

export function parseOptionalPlayerFlag(value: unknown): boolean | undefined {
  if (value == null) return undefined;
  if (typeof value === 'string' && value.trim().length === 0) return undefined;
  return toBool(value, false);
}

export function parseOptionalPlayerEmail(value: unknown): string | undefined {
  const email = parseOptionalPlayerText(value, 'email_id', 160);
  if (!email) return undefined;
  if (!isValidEmail(email)) {
    throw new HttpError(422, 'email_id must be a valid email address.');
  }
  return email.toLowerCase();
}

export function normalizeHandleSeed(value: string): string {
  return value
    .trim()
    .toLowerCase()
    .replace(/[^a-z0-9_.-]+/g, '_')
    .replace(/_+/g, '_')
    .replace(/^[_\-.]+|[_\-.]+$/g, '');
}

export function handleSeedFromDisplayName(
  displayName: string,
  index: number,
): string {
  const normalized = normalizeHandleSeed(displayName);
  if (normalized.length >= 3) {
    return normalized.slice(0, 32);
  }
  return `player_${index + 1}`;
}

export function handleWithSuffix(
  baseHandle: string,
  collisionIndex: number,
): string {
  const suffix = collisionIndex === 0 ? '' : `_${collisionIndex}`;
  const safeBaseHandle = baseHandle.slice(0, 32 - suffix.length);
  return `${safeBaseHandle}${suffix}`;
}

export function tokenFromHeader(authorization?: string): string | null {
  if (!authorization) return null;
  const parts = authorization.split(' ');
  if (parts.length !== 2) return null;
  const [scheme, value] = parts;
  if (scheme.toLowerCase() !== 'bearer') return null;
  if (!value) return null;
  return value;
}

export function parseFirebaseRoleHint(value: unknown): Role | undefined {
  if (typeof value !== 'string') return undefined;
  const normalized = value.trim().toLowerCase();
  if (normalized === 'player') return 'player';
  if (normalized === 'viewer') return 'viewer';
  return undefined;
}

export function splitNameParts(displayName: string): {
  firstName: string;
  lastName: string;
} {
  const normalized = displayName.trim().replace(/\s+/g, ' ');
  const parts = normalized.split(' ').filter((entry) => entry.length > 0);
  if (parts.length === 0) {
    return {firstName: '', lastName: ''};
  }
  if (parts.length === 1) {
    return {firstName: parts[0], lastName: ''};
  }
  return {
    firstName: parts[0],
    lastName: parts.slice(1).join(' '),
  };
}
