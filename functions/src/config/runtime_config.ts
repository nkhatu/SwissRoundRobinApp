/* ---------------------------------------------------------------------------
 * functions/src/config/runtime_config.ts
 * ---------------------------------------------------------------------------
 *
 * Purpose:
 * - Loads and validates runtime environment flags for the functions backend.
 * Architecture:
 * - Configuration boundary that parses environment variables into typed options.
 * - Keeps env-specific behavior centralized and explicit for route handlers.
 * Author: Neil Khatu
 * Copyright (c) The Khatu Family Trust
 */
function parseBooleanEnv(
  name: string,
  fallback = false,
): boolean {
  const raw = process.env[name];
  if (raw == null) return fallback;
  const normalized = raw.trim().toLowerCase();
  if (!normalized) return fallback;
  return (
    normalized === '1' ||
    normalized === 'true' ||
    normalized === 'yes' ||
    normalized === 'y'
  );
}

function parseCsvEnv(name: string): string[] {
  const raw = process.env[name];
  if (raw == null) return [];
  return raw
    .split(',')
    .map((entry) => entry.trim())
    .filter((entry) => entry.length > 0);
}

const DEFAULT_GOOGLE_WEB_CLIENT_ID = '';

function resolveGoogleClientIds(): string[] {
  const explicit = parseCsvEnv('GOOGLE_OAUTH_CLIENT_IDS');
  if (explicit.length > 0) return explicit;

  const legacy = [
    process.env.GOOGLE_WEB_CLIENT_ID,
    process.env.GOOGLE_IOS_CLIENT_ID,
    process.env.GOOGLE_SERVER_CLIENT_ID,
    DEFAULT_GOOGLE_WEB_CLIENT_ID,
  ]
    .map((entry) => entry?.trim() ?? '')
    .filter((entry) => entry.length > 0);

  return [...new Set(legacy)];
}

function resolveAppleServiceIds(): string[] {
  const explicit = parseCsvEnv('APPLE_SERVICE_IDS');
  if (explicit.length > 0) return explicit;

  const legacy = [
    process.env.APPLE_SERVICE_ID,
    process.env.APPLE_CLIENT_ID,
    'com.example.carrom',
  ]
    .map((entry) => entry?.trim() ?? '')
    .filter((entry) => entry.length > 0);

  return [...new Set(legacy)];
}

export const runtimeConfig = {
  allowDemoSeed: parseBooleanEnv('ALLOW_DEMO_SEED', false),
  autoBootstrapDemo: parseBooleanEnv('AUTO_BOOTSTRAP_DEMO', false),
  seedApiKey: process.env.SEED_API_KEY?.trim() ?? '',
  bootstrapAdminHandle: process.env.BOOTSTRAP_ADMIN_HANDLE?.trim() ?? '',
  bootstrapAdminPassword: process.env.BOOTSTRAP_ADMIN_PASSWORD?.trim() ?? '',
  demoAdminHandle: process.env.DEMO_ADMIN_HANDLE?.trim() || 'admin',
  demoAdminPassword: process.env.DEMO_ADMIN_PASSWORD?.trim() || 'admin123',
  appleAndroidPackage:
    process.env.APPLE_ANDROID_PACKAGE?.trim() || 'com.example.carrom_srr',
  googleClientIds: resolveGoogleClientIds(),
  appleServiceIds: resolveAppleServiceIds(),
};
