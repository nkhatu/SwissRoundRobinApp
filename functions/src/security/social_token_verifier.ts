/* ---------------------------------------------------------------------------
 * functions/src/security/social_token_verifier.ts
 * ---------------------------------------------------------------------------
 *
 * Purpose:
 * - Verifies social provider tokens and normalizes provider identity payloads.
 * Architecture:
 * - Security utility module abstracting provider-specific token verification details.
 * - Keeps social auth parsing isolated from endpoint orchestration code.
 * Author: Neil Khatu
 * Copyright (c) The Khatu Family Trust
 */
import crypto from 'crypto';

const GOOGLE_JWKS_URL = 'https://www.googleapis.com/oauth2/v3/certs';
const APPLE_JWKS_URL = 'https://appleid.apple.com/auth/keys';
const DEFAULT_JWKS_TTL_SECONDS = 60 * 60;

interface JwtHeader {
  alg?: string;
  kid?: string;
  typ?: string;
}

interface JwtClaims {
  iss?: string;
  sub?: string;
  aud?: string | string[];
  exp?: number;
  iat?: number;
  email?: string;
  name?: string;
  email_verified?: boolean | string;
}

interface JwkRecord {
  kid?: string;
  alg?: string;
  kty?: string;
  use?: string;
  n?: string;
  e?: string;
  x?: string;
  y?: string;
  crv?: string;
}

interface JwksPayload {
  keys: JwkRecord[];
}

interface JwksCacheEntry {
  expiresAt: number;
  keys: JwkRecord[];
}

interface ParsedJwt {
  header: JwtHeader;
  claims: JwtClaims;
  signingInput: string;
  signature: Buffer;
}

export interface VerifiedSocialIdentity {
  subject: string;
  email: string | null;
  displayName: string | null;
}

const jwksCache = new Map<string, JwksCacheEntry>();

function parseMaxAgeSeconds(cacheControl: string | null): number {
  if (!cacheControl) return DEFAULT_JWKS_TTL_SECONDS;
  const match = cacheControl.match(/max-age=(\d+)/i);
  if (!match) return DEFAULT_JWKS_TTL_SECONDS;
  const parsed = Number.parseInt(match[1], 10);
  if (!Number.isFinite(parsed) || parsed < 1) {
    return DEFAULT_JWKS_TTL_SECONDS;
  }
  return parsed;
}

async function fetchJwks(
  jwksUrl: string,
  forceRefresh = false,
): Promise<JwkRecord[]> {
  const cached = jwksCache.get(jwksUrl);
  if (!forceRefresh && cached != null && cached.expiresAt > Date.now()) {
    return cached.keys;
  }

  const response = await fetch(jwksUrl, {
    headers: {Accept: 'application/json'},
  });
  if (!response.ok) {
    throw new Error(`Unable to load JWKS (${response.status}) from ${jwksUrl}.`);
  }

  const payload = (await response.json()) as JwksPayload;
  if (!Array.isArray(payload.keys) || payload.keys.length === 0) {
    throw new Error(`JWKS response from ${jwksUrl} did not contain any keys.`);
  }

  const maxAgeSeconds = parseMaxAgeSeconds(response.headers.get('cache-control'));
  const entry: JwksCacheEntry = {
    keys: payload.keys,
    expiresAt: Date.now() + maxAgeSeconds * 1000,
  };
  jwksCache.set(jwksUrl, entry);
  return entry.keys;
}

function decodeBase64UrlJson<T>(segment: string, fieldName: string): T {
  try {
    const normalized = segment
      .replace(/-/g, '+')
      .replace(/_/g, '/')
      .padEnd(Math.ceil(segment.length / 4) * 4, '=');
    const decoded = Buffer.from(normalized, 'base64').toString('utf8');
    return JSON.parse(decoded) as T;
  } catch {
    throw new Error(`Invalid JWT ${fieldName}.`);
  }
}

function decodeBase64UrlBytes(segment: string, fieldName: string): Buffer {
  try {
    const normalized = segment
      .replace(/-/g, '+')
      .replace(/_/g, '/')
      .padEnd(Math.ceil(segment.length / 4) * 4, '=');
    return Buffer.from(normalized, 'base64');
  } catch {
    throw new Error(`Invalid JWT ${fieldName}.`);
  }
}

function parseJwt(token: string): ParsedJwt {
  const parts = token.split('.');
  if (parts.length !== 3) {
    throw new Error('Invalid JWT format.');
  }

  const [encodedHeader, encodedClaims, encodedSignature] = parts;
  const header = decodeBase64UrlJson<JwtHeader>(encodedHeader, 'header');
  const claims = decodeBase64UrlJson<JwtClaims>(encodedClaims, 'payload');
  const signature = decodeBase64UrlBytes(encodedSignature, 'signature');

  return {
    header,
    claims,
    signature,
    signingInput: `${encodedHeader}.${encodedClaims}`,
  };
}

function ensureClaimString(
  value: unknown,
  claimName: string,
  provider: string,
): string {
  if (typeof value !== 'string' || value.trim().length === 0) {
    throw new Error(`Missing ${provider} token claim: ${claimName}.`);
  }
  return value.trim();
}

function ensureExpiration(
  exp: unknown,
  provider: string,
): void {
  if (typeof exp !== 'number' || !Number.isFinite(exp)) {
    throw new Error(`Missing ${provider} token claim: exp.`);
  }
  const nowSeconds = Math.floor(Date.now() / 1000);
  if (exp <= nowSeconds) {
    throw new Error(`${provider} token is expired.`);
  }
}

function ensureAudience(
  audience: unknown,
  allowedAudiences: string[],
  provider: string,
): void {
  const values = Array.isArray(audience)
    ? audience.filter((value): value is string => typeof value === 'string')
    : typeof audience === 'string'
    ? [audience]
    : [];
  if (values.length === 0) {
    throw new Error(`Missing ${provider} token claim: aud.`);
  }

  if (!values.some((value) => allowedAudiences.includes(value))) {
    throw new Error(
      `${provider} token audience mismatch. Expected one of: ${allowedAudiences.join(', ')}.`,
    );
  }
}

function ensureIssuer(
  issuer: unknown,
  expectedIssuers: string[],
  provider: string,
): void {
  if (typeof issuer !== 'string' || !expectedIssuers.includes(issuer)) {
    throw new Error(
      `${provider} token issuer mismatch. Expected one of: ${expectedIssuers.join(', ')}.`,
    );
  }
}

function verifySignature(
  parsed: ParsedJwt,
  jwk: JwkRecord,
  provider: string,
): void {
  if (parsed.header.alg !== 'RS256') {
    throw new Error(`${provider} token algorithm must be RS256.`);
  }
  if (jwk.kty !== 'RSA') {
    throw new Error(`${provider} JWK key type must be RSA.`);
  }

  const keyObject = crypto.createPublicKey({
    key: jwk as unknown as crypto.JsonWebKey,
    format: 'jwk',
  } as crypto.JsonWebKeyInput);

  const valid = crypto.verify(
    'RSA-SHA256',
    Buffer.from(parsed.signingInput, 'utf8'),
    keyObject,
    parsed.signature,
  );
  if (!valid) {
    throw new Error(`${provider} token signature is invalid.`);
  }
}

async function verifyTokenWithJwks(params: {
  token: string;
  provider: 'Google' | 'Apple';
  jwksUrl: string;
  expectedIssuers: string[];
  allowedAudiences: string[];
}): Promise<VerifiedSocialIdentity> {
  const parsed = parseJwt(params.token);
  const keyId = ensureClaimString(parsed.header.kid, 'kid', params.provider);

  let keys = await fetchJwks(params.jwksUrl);
  let key = keys.find((entry) => entry.kid === keyId);
  if (key == null) {
    keys = await fetchJwks(params.jwksUrl, true);
    key = keys.find((entry) => entry.kid === keyId);
  }
  if (key == null) {
    throw new Error(`${params.provider} token key id ${keyId} not found in JWKS.`);
  }

  verifySignature(parsed, key, params.provider);
  ensureIssuer(parsed.claims.iss, params.expectedIssuers, params.provider);
  ensureAudience(parsed.claims.aud, params.allowedAudiences, params.provider);
  ensureExpiration(parsed.claims.exp, params.provider);

  const subject = ensureClaimString(parsed.claims.sub, 'sub', params.provider);
  const email =
    typeof parsed.claims.email === 'string' && parsed.claims.email.trim().length > 0
      ? parsed.claims.email.trim().toLowerCase()
      : null;
  const displayName =
    typeof parsed.claims.name === 'string' && parsed.claims.name.trim().length > 0
      ? parsed.claims.name.trim()
      : null;

  return {subject, email, displayName};
}

export async function verifyGoogleIdToken(params: {
  idToken: string;
  allowedAudiences: string[];
}): Promise<VerifiedSocialIdentity> {
  if (params.allowedAudiences.length === 0) {
    throw new Error('Google OAuth client IDs are not configured on backend.');
  }
  return verifyTokenWithJwks({
    token: params.idToken,
    provider: 'Google',
    jwksUrl: GOOGLE_JWKS_URL,
    expectedIssuers: ['https://accounts.google.com', 'accounts.google.com'],
    allowedAudiences: params.allowedAudiences,
  });
}

export async function verifyAppleIdentityToken(params: {
  identityToken: string;
  allowedAudiences: string[];
}): Promise<VerifiedSocialIdentity> {
  if (params.allowedAudiences.length === 0) {
    throw new Error('Apple Service IDs are not configured on backend.');
  }
  return verifyTokenWithJwks({
    token: params.identityToken,
    provider: 'Apple',
    jwksUrl: APPLE_JWKS_URL,
    expectedIssuers: ['https://appleid.apple.com'],
    allowedAudiences: params.allowedAudiences,
  });
}
