# Swiss Round Robin (Catu-based Rewrite)

This rewrite uses:

- `catu_framework` for auth flow, app shell, theme controller, and support/settings/legal pages.
- Catu-style dependency injection via `AppFrameworkDependencies` at app startup.
- A Firebase Cloud Functions backend with **Firestore as the single source of truth**.
- A Flutter app (`srr_app`) for player and viewer experiences (mobile + web).

## Documentation

- `docs/srr_architecture.md` — production-ready architecture narrative, data model, workflows, and diagrams aligned with the current Flutter + Functions layout.
- `docs/srr_architecture_slides.md` — slide-style summary you can reuse for presentations or handoffs.

## UI helpers

- `srr_app/lib/src/ui/helpers/srr_form_helpers.dart` provides shared form widgets (inline error banners, string extensions) so tournament/setup screens stay focused on layout and the Catu-inspired theme scale is consistent.

## Why Firestore + Functions

For live viewing by non-players and multi-device score confirmation, Firestore gives one shared canonical state and Cloud Functions exposes a stable API for Android/iOS/web clients.

## Project layout

- `functions` - Firebase Functions + Firestore backend
  - `functions/src/models/domain_models.ts`
  - `functions/src/repositories/*`
- `api` - legacy FastAPI + SQLite backend (kept for reference)
- `srr_app` - Flutter app
  - `srr_app/lib/src/di/srr_dependencies.dart`
  - `srr_app/lib/src/repositories/*`

## Features implemented

- Player and viewer accounts
- Score entry/confirmation per match by each participating player
- Automatic match confirmation only when both players submit matching scores
- Automatic points allocation on confirmed matches
- Automatic standings computation (live + after each round)
- Web-friendly viewer mode (read-only)
- Web tournament setup page with CSV/XLSX player upload
- Carrom-aware score model: toss state, board-by-board entries, tie-break board, sudden-death result
- Tournament setup metadata: flag/type/category/sub-category, venue/director/referees, strength, participant limits and auto-derived table count
- Admin-only management pages: tournament setup, player upload, round matchup, ranking upload
- Post-login profile completion flow: first name, last name, and player/viewer role selection

## Firebase backend quick start

```bash
export SRR_ROOT="${SRR_ROOT:-$(git rev-parse --show-toplevel)}"
cd "$SRR_ROOT/functions"
npm install
npm run build

cd "$SRR_ROOT"
firebase deploy --only functions,firestore:rules
```

### Recommended function env

Set env vars in your Functions runtime (or `functions/.env` for local/dev):

- `GOOGLE_OAUTH_CLIENT_IDS`
- `APPLE_SERVICE_IDS`
- `BOOTSTRAP_ADMIN_HANDLE`
- `BOOTSTRAP_ADMIN_PASSWORD`

### Demo accounts

When demo seeding is enabled (`ALLOW_DEMO_SEED=true`) and `/setup/seed` is run:

- `admin / admin123` (admin)
- `alice / pass123` (player)
- `bob / pass123` (player)
- `carla / pass123` (player)
- `diego / pass123` (player)
- `viewer / viewer123` (viewer)

## Flutter app quick start

```bash
export SRR_ROOT="${SRR_ROOT:-$(git rev-parse --show-toplevel)}"
export FIREBASE_PROJECT_ID="${FIREBASE_PROJECT_ID:-your-firebase-project-id}"
cd "$SRR_ROOT/srr_app"
flutter pub get
flutter run --dart-define=SRR_API_URL="https://us-central1-${FIREBASE_PROJECT_ID}.cloudfunctions.net/api"
```

For your custom domain:

```bash
flutter run --dart-define=SRR_API_URL=https://example.com/api
```

For web:

```bash
flutter run -d chrome --dart-define=SRR_API_URL=https://example.com/api
```

## Google and Apple sign-in (Firebase Auth)

Buttons on the Catu sign-in page now call real provider SDKs and then use
Firebase Auth. Backend endpoints consume Firebase ID tokens and provision SRR
users automatically via `POST /auth/firebase` and `GET /auth/me`.

### Google

1. Configure Android/iOS/Web for `google_sign_in`:
   - Android setup: follow `google_sign_in_android` integration and add your app SHA-1/SHA-256.
   - iOS setup:
     - add `ios/Runner/GoogleService-Info.plist` to Runner target resources,
     - ensure iOS bundle ID matches plist `BUNDLE_ID`,
     - add `REVERSED_CLIENT_ID` from plist to `ios/Runner/Info.plist` `CFBundleURLTypes`.
   - Web setup: configure Google Identity Services client.
2. On Android, pass a Web OAuth client ID as `GOOGLE_SERVER_CLIENT_ID` (required by current SDK). If you only have one client ID, you can pass it to both values.
3. Pass client IDs at run time:

```bash
flutter run \
  --dart-define=SRR_API_URL=https://example.com/api \
  --dart-define=GOOGLE_WEB_CLIENT_ID=YOUR_GOOGLE_WEB_CLIENT_ID \
  --dart-define=GOOGLE_SERVER_CLIENT_ID=YOUR_GOOGLE_SERVER_CLIENT_ID
```

### Apple

For Android/Web, Apple requires web auth options.

```bash
flutter run \
  --dart-define=SRR_API_URL=https://example.com/api \
  --dart-define=APPLE_CLIENT_ID=YOUR_APPLE_SERVICE_ID \
  --dart-define=APPLE_REDIRECT_URI=https://example.com/api/callbacks/sign_in_with_apple
```

`APPLE_SERVICE_ID` is also accepted as an alias for `APPLE_CLIENT_ID`.
If neither is provided, SRR defaults to `com.example.carrom`.
If `APPLE_REDIRECT_URI` is not provided, SRR defaults to:
`https://example.com/api/callbacks/sign_in_with_apple`.

`APPLE_REDIRECT_URI` should point to your deployed API callback endpoint:

- `https://example.com/api/callbacks/sign_in_with_apple`
- this endpoint then redirects to Android deep link `signinwithapple://callback`

For iOS/macOS:

1. `ios/Runner/Runner.entitlements` includes `com.apple.developer.applesignin` and is wired for Debug/Release/Profile.
2. Ensure your Apple Developer App ID for bundle `com.example.your-firebase-project-id` has Sign in with Apple enabled.

## Security note

Social login now validates Google/Apple identity token signatures server-side
before issuing sessions. Keep OAuth audiences configured on backend
(`GOOGLE_OAUTH_CLIENT_IDS`, `APPLE_SERVICE_IDS`) so token verification remains strict.
Demo seeding is disabled by default and can only be enabled via env
(`ALLOW_DEMO_SEED=true`, optional `SEED_API_KEY`).

## Core API endpoints

- `POST /auth/login`
- `POST /auth/register`
- `POST /auth/social`
- `POST /auth/firebase` (Firebase Auth bootstrap/provision)
- `GET /auth/me`
- `POST /tournament/setup` (admin only)
- `GET /tournaments` (admin only)
- `GET /tournaments/{tournament_id}` (admin only)
- `POST /tournaments/{tournament_id}/replicate` (admin only)
- `PATCH /tournaments/{tournament_id}` (admin only)
- `GET /tournaments/{tournament_id}/players` (admin only)
- `POST /tournaments/{tournament_id}/players/upload` (admin only)
- `GET /players`
- `GET /rounds`
- `POST /matches/{match_id}/confirm`
- `GET /standings`
- `GET /standings/by-round`
- `GET /round-points`
- `GET /live`

## Player upload template

Excel template with required headers:

- `templates/players_list_template.xlsx`

Generated sample with 100 players:

- `templates/players_list_100.xlsx`

For `GET /rounds`, `GET /standings`, `GET /standings/by-round`, `GET /round-points`, and `GET /live`,
you can pass `?tournament_id=<id>`. If omitted, backend uses the active tournament (or latest available).

### Carrom match confirmation payload

`POST /matches/{match_id}/confirm` now supports either:

1. Flat totals:
   - `{ "score1": 25, "score2": 21 }`
2. Carrom detail payload (totals auto-computed):
   - `toss` state (winner, decision, first striker/color)
   - `boards[]` with board points or pocket stats
   - optional `sudden_death` winner/hits/attempts

Example:

```json
{
  "toss": {
    "toss_winner_player_id": 1,
    "toss_decision": "strike_first",
    "first_striker_player_id": 2,
    "first_striker_color": "white"
  },
  "boards": [
    {
      "board_number": 1,
      "striker_player_id": 2,
      "striker_color": "white",
      "player1_points": 4,
      "player2_points": 8
    }
  ],
  "sudden_death": {
    "winner_player_id": 1,
    "player1_hits": 2,
    "player2_hits": 1,
    "attempts": 3
  }
}
```
