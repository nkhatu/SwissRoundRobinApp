# SRR Firebase Functions API (Firestore Source of Truth)

This service mirrors the existing SRR REST API on Firebase Cloud Functions and stores all state in Firestore.

## Data Model and Repositories

Repository-backed domain models are now defined for:

- `users`
- `players`
- `tournaments`
- `rounds`
- `scores`

Authentication is Firebase Auth-first.
Client apps authenticate with Firebase, send Firebase ID tokens as Bearer tokens,
and call `POST /auth/firebase` to create/link an SRR user record.

Useful env vars:

- `BOOTSTRAP_ADMIN_HANDLE` / `BOOTSTRAP_ADMIN_PASSWORD` (optional initial admin)
- `ALLOW_DEMO_SEED` and optional `SEED_API_KEY` for `/setup/seed`

Source files:

- Models: `src/models/domain_models.ts`
- Repositories:
  - `src/repositories/users_repository.ts`
  - `src/repositories/players_repository.ts`
  - `src/repositories/tournaments_repository.ts`
  - `src/repositories/rounds_repository.ts`
  - `src/repositories/scores_repository.ts`

## Endpoints

All existing app endpoints are preserved:

- `GET /health`
- `POST /setup/seed`
- `POST /tournament/setup` (admin only)
- `GET /tournaments` (admin only)
- `GET /tournaments/{tournament_id}` (admin only)
- `POST /tournaments/{tournament_id}/replicate` (admin only)
- `PATCH /tournaments/{tournament_id}` (admin only)
- `GET /tournaments/{tournament_id}/players` (admin only)
- `POST /tournaments/{tournament_id}/players/upload` (admin only)
- `GET /players`
- `POST /auth/firebase`
- `POST /auth/logout`
- `GET /auth/me`
- `GET /rounds`
- `POST /matches/{match_id}/confirm`
- `GET /standings`
- `GET /round-points`
- `GET /standings/by-round`
- `GET /live`
- `GET|POST /callbacks/sign_in_with_apple`

`POST /auth/register`, `POST /auth/login`, and `POST /auth/social` are legacy
endpoints and now return `410 Gone`.

Tournament-aware reads:

- `GET /rounds?tournament_id=<id>`
- `GET /standings?tournament_id=<id>[&round=<n>]`
- `GET /round-points?tournament_id=<id>`
- `GET /standings/by-round?tournament_id=<id>`
- `GET /live?tournament_id=<id>`

If `tournament_id` is omitted, backend uses the active tournament, or the latest
available tournament if none is active.

Both root and `/api` prefixes are supported, so these work:

- `https://...cloudfunctions.net/api/health`
- `https://example.com/api/health` (if fronted by Hosting/proxy)

## Local build

```bash
export SRR_ROOT="${SRR_ROOT:-$(git rev-parse --show-toplevel)}"
cd "$SRR_ROOT/functions"
cp .env.example .env
npm install
npm run build
```

## Deploy

From repo root:

```bash
export SRR_ROOT="${SRR_ROOT:-$(git rev-parse --show-toplevel)}"
cd "$SRR_ROOT"
firebase deploy --only functions,firestore:rules
```

## Flutter runtime base URL

Use your deployed function base URL:

```bash
export FIREBASE_PROJECT_ID="${FIREBASE_PROJECT_ID:-your-firebase-project-id}"
flutter run \
  --dart-define=SRR_API_URL="https://us-central1-${FIREBASE_PROJECT_ID}.cloudfunctions.net/api"
```

If you front Functions behind `https://example.com/api`, use:

```bash
flutter run --dart-define=SRR_API_URL=https://example.com/api
```

## Apple Sign-In callback URL

Set:

- `APPLE_REDIRECT_URI=https://example.com/api/callbacks/sign_in_with_apple`

Set function env in `functions/.env` (or in Firebase console for production):

```bash
FUNCTION_REGION=us-central1
APPLE_ANDROID_PACKAGE=com.example.carrom_srr
```
