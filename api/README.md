# SRR API (SQLite Source of Truth)

This API stores all tournament state in a single SQLite database and exposes endpoints for:

- Player/viewer auth
- Match score confirmation by both players
- Automatic confirmation, point allocation, and standings
- Public live snapshot for web viewers

## Quick start

```bash
export SRR_ROOT="${SRR_ROOT:-$(git rev-parse --show-toplevel)}"
cd "$SRR_ROOT/api"
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
uvicorn src.main:app --reload --host 127.0.0.1 --port 8000
```

## Demo accounts

Seed runs automatically on first startup:

- `alice / pass123`
- `bob / pass123`
- `carla / pass123`
- `diego / pass123`
- `viewer / viewer123`

## Core endpoints

- `POST /auth/login`
- `POST /auth/register`
- `POST /auth/social`
- `GET /auth/me`
- `GET /rounds`
- `POST /matches/{match_id}/confirm`
- `GET /standings`
- `GET /standings/by-round`
- `GET /round-points`
- `GET /live`

## Apple callback endpoint (Android)

- `POST /callbacks/sign_in_with_apple`
- `GET /callbacks/sign_in_with_apple`

Set `APPLE_ANDROID_PACKAGE` in API environment if your Android package is not `com.example.carrom_srr`.

## Security note

`POST /auth/social` currently trusts identity details received from mobile/web SDKs and is designed for development. For production, add server-side provider token verification.
