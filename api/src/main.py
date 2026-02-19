# ---------------------------------------------------------------------------
# api/src/main.py
# ---------------------------------------------------------------------------
# 
# Purpose:
# - Hosts the FastAPI app surface for SRR APIs and supporting endpoints.
# Architecture:
# - Service entrypoint responsible for routing, startup lifecycle, and transport concerns.
# - Separates API request handling from data/domain internals.
# Author: Neil Khatu
# Copyright (c) The Khatu Family Trust
# 
from __future__ import annotations

import hashlib
import os
import re
import secrets
import sqlite3
import urllib.parse
from contextlib import asynccontextmanager, closing
from datetime import datetime, timezone
from pathlib import Path
from typing import Annotated, Literal, Optional, Union

from fastapi import FastAPI, Header, HTTPException, Query, Request, status
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field
from starlette.responses import HTMLResponse, RedirectResponse

Role = Literal['player', 'viewer']

DB_PATH = Path(os.getenv('DB_PATH', Path(__file__).resolve().parents[1] / 'data' / 'srr.sqlite3'))
APPLE_ANDROID_PACKAGE = os.getenv('APPLE_ANDROID_PACKAGE', 'com.example.carrom_srr')


class UserDto(BaseModel):
    id: int
    handle: str
    display_name: str
    role: Role


class AuthResponse(BaseModel):
    token: str
    user: UserDto


class RegisterRequest(BaseModel):
    handle: str = Field(min_length=3, max_length=32, pattern=r'^[a-zA-Z0-9_.-]+$')
    display_name: str = Field(min_length=2, max_length=80)
    password: str = Field(min_length=6, max_length=128)
    role: Role = 'player'


class LoginRequest(BaseModel):
    handle: str = Field(min_length=3, max_length=32)
    password: str = Field(min_length=6, max_length=128)


class SocialLoginRequest(BaseModel):
    provider: Literal['google', 'apple']
    provider_user_id: str = Field(min_length=2, max_length=255)
    display_name: str = Field(min_length=1, max_length=120)
    email: Optional[str] = Field(default=None, max_length=255)
    handle_hint: Optional[str] = Field(default=None, max_length=64)


class ScoreConfirmRequest(BaseModel):
    score1: int = Field(ge=0, le=999)
    score2: int = Field(ge=0, le=999)


class ScoreConfirmationDto(BaseModel):
    score1: int
    score2: int


class PlayerLiteDto(BaseModel):
    id: int
    handle: str
    display_name: str


class MatchDto(BaseModel):
    id: int
    round_number: int
    table_number: int
    player1: PlayerLiteDto
    player2: PlayerLiteDto
    status: Literal['pending', 'disputed', 'confirmed']
    confirmed_score1: Optional[int]
    confirmed_score2: Optional[int]
    confirmations: int
    my_confirmation: Optional[ScoreConfirmationDto] = None


class RoundDto(BaseModel):
    round_number: int
    is_complete: bool
    matches: list[MatchDto]


class StandingRowDto(BaseModel):
    position: int
    player_id: int
    handle: str
    display_name: str
    played: int
    wins: int
    draws: int
    losses: int
    goals_for: int
    goals_against: int
    goal_difference: int
    round_points: int
    points: int


class PlayerRoundPointsDto(BaseModel):
    player_id: int
    display_name: str
    points: int


class RoundPointsDto(BaseModel):
    round_number: int
    points: list[PlayerRoundPointsDto]


class RoundStandingsDto(BaseModel):
    round_number: int
    is_complete: bool
    standings: list[StandingRowDto]


class LiveSnapshotDto(BaseModel):
    generated_at: str
    current_round: Optional[int]
    rounds: list[RoundDto]
    standings: list[StandingRowDto]


def _utc_now() -> str:
    return datetime.now(timezone.utc).isoformat()


def _get_connection() -> sqlite3.Connection:
    DB_PATH.parent.mkdir(parents=True, exist_ok=True)
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    conn.execute('PRAGMA foreign_keys = ON')
    return conn


def _normalize_handle(handle: str) -> str:
    return handle.strip().lower()


def _social_handle_base(
    *,
    provider: str,
    provider_user_id: str,
    handle_hint: Optional[str],
    email: Optional[str],
    display_name: str,
) -> str:
    for raw in (
        handle_hint,
        email.split('@', 1)[0] if email else None,
        display_name,
        f'{provider}_{provider_user_id[:12]}',
    ):
        if raw is None:
            continue
        normalized = re.sub(r'[^a-z0-9_.-]+', '_', raw.strip().lower())
        normalized = re.sub(r'_+', '_', normalized).strip('_')
        if len(normalized) >= 3:
            return normalized[:32]
    return f'{provider}_{secrets.token_hex(4)}'


def _ensure_unique_handle(conn: sqlite3.Connection, base_handle: str) -> str:
    candidate = base_handle
    suffix = 1
    while True:
        existing = conn.execute(
            'SELECT 1 FROM users WHERE handle = ?',
            (candidate,),
        ).fetchone()
        if existing is None:
            return candidate
        suffix += 1
        trimmed = base_handle[: max(3, 32 - len(str(suffix)) - 1)]
        candidate = f'{trimmed}_{suffix}'


def _issue_session(conn: sqlite3.Connection, user_id: int) -> str:
    token = secrets.token_urlsafe(32)
    conn.execute('INSERT INTO sessions (token, user_id) VALUES (?, ?)', (token, user_id))
    return token


def _hash_password(password: str) -> str:
    salt = secrets.token_hex(16)
    digest = hashlib.pbkdf2_hmac('sha256', password.encode(), salt.encode(), 200_000)
    return f'{salt}${digest.hex()}'


def _verify_password(password: str, password_hash: str) -> bool:
    try:
        salt, saved_digest = password_hash.split('$', 1)
    except ValueError:
        return False
    digest = hashlib.pbkdf2_hmac('sha256', password.encode(), salt.encode(), 200_000)
    return secrets.compare_digest(saved_digest, digest.hex())


def _token_from_header(authorization: Optional[str]) -> Optional[str]:
    if not authorization:
        return None
    prefix, _, token = authorization.partition(' ')
    if prefix.lower() != 'bearer' or not token:
        return None
    return token.strip()


def _row_to_user(row: sqlite3.Row) -> UserDto:
    return UserDto(
        id=int(row['id']),
        handle=str(row['handle']),
        display_name=str(row['display_name']),
        role=str(row['role']),
    )


def _require_user(authorization: Optional[str]) -> UserDto:
    token = _token_from_header(authorization)
    if token is None:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail='Missing bearer token.')

    with closing(_get_connection()) as conn:
        row = conn.execute(
            '''
            SELECT u.id, u.handle, u.display_name, u.role
            FROM sessions s
            JOIN users u ON u.id = s.user_id
            WHERE s.token = ?
            ''',
            (token,),
        ).fetchone()

    if row is None:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail='Invalid session token.')

    return _row_to_user(row)


def _optional_user(authorization: Optional[str]) -> Optional[UserDto]:
    token = _token_from_header(authorization)
    if token is None:
        return None

    with closing(_get_connection()) as conn:
        row = conn.execute(
            '''
            SELECT u.id, u.handle, u.display_name, u.role
            FROM sessions s
            JOIN users u ON u.id = s.user_id
            WHERE s.token = ?
            ''',
            (token,),
        ).fetchone()

    if row is None:
        return None
    return _row_to_user(row)


def _match_points(score1: int, score2: int) -> tuple[int, int]:
    if score1 > score2:
        return (3, 0)
    if score2 > score1:
        return (0, 3)
    return (1, 1)


def _generate_round_robin(player_ids: list[int]) -> list[list[tuple[int, int]]]:
    participants: list[Optional[int]] = list(player_ids)
    if len(participants) % 2 == 1:
        participants.append(None)

    rounds: list[list[tuple[int, int]]] = []
    count = len(participants)
    half = count // 2

    for round_index in range(count - 1):
        pairs: list[tuple[int, int]] = []
        for i in range(half):
            left = participants[i]
            right = participants[count - 1 - i]
            if left is None or right is None:
                continue

            if round_index % 2 == 0 and i == 0:
                pairs.append((right, left))
            else:
                pairs.append((left, right))

        rounds.append(pairs)
        participants = [participants[0], participants[-1], *participants[1:-1]]

    return rounds


def _seed_demo_data(conn: sqlite3.Connection, force: bool = False) -> dict[str, int]:
    if force:
        conn.execute('DELETE FROM score_confirmations')
        conn.execute('DELETE FROM matches')
        conn.execute('DELETE FROM social_identities')
        conn.execute('DELETE FROM sessions')
        conn.execute('DELETE FROM users')
        conn.commit()

    existing = conn.execute('SELECT COUNT(*) AS count FROM users').fetchone()
    if existing and existing['count'] > 0:
        players_count = conn.execute("SELECT COUNT(*) AS count FROM users WHERE role = 'player'").fetchone()['count']
        matches_count = conn.execute('SELECT COUNT(*) AS count FROM matches').fetchone()['count']
        return {'players': int(players_count), 'matches': int(matches_count), 'seeded': 0}

    demo_users = [
        ('alice', 'Alice Mercer', 'pass123', 'player'),
        ('bob', 'Bob Singh', 'pass123', 'player'),
        ('carla', 'Carla Diaz', 'pass123', 'player'),
        ('diego', 'Diego Kim', 'pass123', 'player'),
        ('viewer', 'Live Viewer', 'viewer123', 'viewer'),
    ]

    for handle, display_name, password, role in demo_users:
        conn.execute(
            '''
            INSERT INTO users (handle, display_name, password_hash, role)
            VALUES (?, ?, ?, ?)
            ''',
            (handle, display_name, _hash_password(password), role),
        )

    player_rows = conn.execute("SELECT id FROM users WHERE role = 'player' ORDER BY id").fetchall()
    player_ids = [int(row['id']) for row in player_rows]
    rounds = _generate_round_robin(player_ids)

    for round_number, fixtures in enumerate(rounds, start=1):
        for table_number, (player1_id, player2_id) in enumerate(fixtures, start=1):
            conn.execute(
                '''
                INSERT INTO matches (round_number, table_number, player1_id, player2_id)
                VALUES (?, ?, ?, ?)
                ''',
                (round_number, table_number, player1_id, player2_id),
            )

    conn.commit()
    return {'players': len(player_ids), 'matches': sum(len(round_matches) for round_matches in rounds), 'seeded': 1}


def _build_match_dto(row: sqlite3.Row) -> MatchDto:
    distinct_confirmations = int(row['distinct_confirmations'])
    confirmed = row['confirmed_score1'] is not None and row['confirmed_score2'] is not None

    if confirmed:
        status_value: Literal['pending', 'disputed', 'confirmed'] = 'confirmed'
    elif distinct_confirmations > 1:
        status_value = 'disputed'
    else:
        status_value = 'pending'

    my_confirmation: Optional[ScoreConfirmationDto] = None
    if row['my_score1'] is not None and row['my_score2'] is not None:
        my_confirmation = ScoreConfirmationDto(score1=int(row['my_score1']), score2=int(row['my_score2']))

    return MatchDto(
        id=int(row['id']),
        round_number=int(row['round_number']),
        table_number=int(row['table_number']),
        player1=PlayerLiteDto(
            id=int(row['player1_id']),
            handle=str(row['player1_handle']),
            display_name=str(row['player1_name']),
        ),
        player2=PlayerLiteDto(
            id=int(row['player2_id']),
            handle=str(row['player2_handle']),
            display_name=str(row['player2_name']),
        ),
        status=status_value,
        confirmed_score1=int(row['confirmed_score1']) if row['confirmed_score1'] is not None else None,
        confirmed_score2=int(row['confirmed_score2']) if row['confirmed_score2'] is not None else None,
        confirmations=int(row['confirmations']),
        my_confirmation=my_confirmation,
    )


def _fetch_matches(conn: sqlite3.Connection, user_id: Optional[int] = None) -> list[MatchDto]:
    rows = conn.execute(
        '''
        SELECT
          m.id,
          m.round_number,
          m.table_number,
          m.player1_id,
          m.player2_id,
          m.confirmed_score1,
          m.confirmed_score2,
          u1.handle AS player1_handle,
          u1.display_name AS player1_name,
          u2.handle AS player2_handle,
          u2.display_name AS player2_name,
          (SELECT COUNT(*) FROM score_confirmations sc WHERE sc.match_id = m.id) AS confirmations,
          (
            SELECT COUNT(DISTINCT sc.score1 || ':' || sc.score2)
            FROM score_confirmations sc
            WHERE sc.match_id = m.id
          ) AS distinct_confirmations,
          my.score1 AS my_score1,
          my.score2 AS my_score2
        FROM matches m
        JOIN users u1 ON u1.id = m.player1_id
        JOIN users u2 ON u2.id = m.player2_id
        LEFT JOIN score_confirmations my
          ON my.match_id = m.id
         AND my.player_id = ?
        ORDER BY m.round_number, m.table_number, m.id
        ''',
        (user_id,),
    ).fetchall()
    return [_build_match_dto(row) for row in rows]


def _fetch_rounds(conn: sqlite3.Connection, user_id: Optional[int] = None) -> list[RoundDto]:
    matches = _fetch_matches(conn, user_id=user_id)
    grouped: dict[int, list[MatchDto]] = {}
    for match in matches:
        grouped.setdefault(match.round_number, []).append(match)

    rounds: list[RoundDto] = []
    for round_number in sorted(grouped.keys()):
        round_matches = grouped[round_number]
        rounds.append(
            RoundDto(
                round_number=round_number,
                is_complete=all(match.status == 'confirmed' for match in round_matches),
                matches=round_matches,
            )
        )
    return rounds


def _confirm_scores_if_consensus(conn: sqlite3.Connection, match_id: int) -> None:
    match = conn.execute(
        'SELECT confirmed_score1, confirmed_score2 FROM matches WHERE id = ?', (match_id,)
    ).fetchone()
    if match is None:
        return

    if match['confirmed_score1'] is not None and match['confirmed_score2'] is not None:
        return

    confirmations = conn.execute(
        '''
        SELECT player_id, score1, score2
        FROM score_confirmations
        WHERE match_id = ?
        ORDER BY player_id
        ''',
        (match_id,),
    ).fetchall()

    if len(confirmations) < 2:
        return

    first = confirmations[0]
    consensus = all(
        int(row['score1']) == int(first['score1']) and int(row['score2']) == int(first['score2'])
        for row in confirmations[1:]
    )

    if not consensus:
        return

    conn.execute(
        '''
        UPDATE matches
        SET confirmed_score1 = ?, confirmed_score2 = ?, confirmed_at = ?
        WHERE id = ?
        ''',
        (int(first['score1']), int(first['score2']), _utc_now(), match_id),
    )


def _standings(conn: sqlite3.Connection, up_to_round: Optional[int] = None) -> list[StandingRowDto]:
    where_clause = 'WHERE m.confirmed_score1 IS NOT NULL AND m.confirmed_score2 IS NOT NULL'
    params: tuple[object, ...] = ()
    if up_to_round is not None:
        where_clause += ' AND m.round_number <= ?'
        params = (up_to_round,)

    players = conn.execute(
        "SELECT id, handle, display_name FROM users WHERE role = 'player' ORDER BY display_name"
    ).fetchall()

    stats: dict[int, dict[str, Union[int, str]]] = {
        int(player['id']): {
            'player_id': int(player['id']),
            'handle': str(player['handle']),
            'display_name': str(player['display_name']),
            'played': 0,
            'wins': 0,
            'draws': 0,
            'losses': 0,
            'goals_for': 0,
            'goals_against': 0,
            'points': 0,
            'round_points': 0,
        }
        for player in players
    }

    matches = conn.execute(
        f'''
        SELECT
          m.round_number,
          m.player1_id,
          m.player2_id,
          m.confirmed_score1,
          m.confirmed_score2
        FROM matches m
        {where_clause}
        ORDER BY m.round_number, m.id
        ''',
        params,
    ).fetchall()

    for match in matches:
        player1_id = int(match['player1_id'])
        player2_id = int(match['player2_id'])
        score1 = int(match['confirmed_score1'])
        score2 = int(match['confirmed_score2'])
        p1_points, p2_points = _match_points(score1, score2)

        p1 = stats[player1_id]
        p2 = stats[player2_id]

        p1['played'] = int(p1['played']) + 1
        p2['played'] = int(p2['played']) + 1
        p1['goals_for'] = int(p1['goals_for']) + score1
        p1['goals_against'] = int(p1['goals_against']) + score2
        p2['goals_for'] = int(p2['goals_for']) + score2
        p2['goals_against'] = int(p2['goals_against']) + score1
        p1['points'] = int(p1['points']) + p1_points
        p2['points'] = int(p2['points']) + p2_points

        if up_to_round is not None and int(match['round_number']) == up_to_round:
            p1['round_points'] = int(p1['round_points']) + p1_points
            p2['round_points'] = int(p2['round_points']) + p2_points

        if score1 > score2:
            p1['wins'] = int(p1['wins']) + 1
            p2['losses'] = int(p2['losses']) + 1
        elif score2 > score1:
            p2['wins'] = int(p2['wins']) + 1
            p1['losses'] = int(p1['losses']) + 1
        else:
            p1['draws'] = int(p1['draws']) + 1
            p2['draws'] = int(p2['draws']) + 1

    ordered = sorted(
        stats.values(),
        key=lambda row: (
            -int(row['points']),
            -(int(row['goals_for']) - int(row['goals_against'])),
            -int(row['goals_for']),
            str(row['display_name']).lower(),
        ),
    )

    standings: list[StandingRowDto] = []
    for position, row in enumerate(ordered, start=1):
        goals_for = int(row['goals_for'])
        goals_against = int(row['goals_against'])
        standings.append(
            StandingRowDto(
                position=position,
                player_id=int(row['player_id']),
                handle=str(row['handle']),
                display_name=str(row['display_name']),
                played=int(row['played']),
                wins=int(row['wins']),
                draws=int(row['draws']),
                losses=int(row['losses']),
                goals_for=goals_for,
                goals_against=goals_against,
                goal_difference=goals_for - goals_against,
                round_points=int(row['round_points']),
                points=int(row['points']),
            )
        )

    return standings


def _round_points(conn: sqlite3.Connection) -> list[RoundPointsDto]:
    players = conn.execute(
        "SELECT id, display_name FROM users WHERE role = 'player' ORDER BY display_name"
    ).fetchall()
    player_names = {int(row['id']): str(row['display_name']) for row in players}

    rounds = [
        int(row['round_number'])
        for row in conn.execute('SELECT DISTINCT round_number FROM matches ORDER BY round_number').fetchall()
    ]

    result: list[RoundPointsDto] = []
    for round_number in rounds:
        totals = {player_id: 0 for player_id in player_names.keys()}
        confirmed = conn.execute(
            '''
            SELECT player1_id, player2_id, confirmed_score1, confirmed_score2
            FROM matches
            WHERE round_number = ?
              AND confirmed_score1 IS NOT NULL
              AND confirmed_score2 IS NOT NULL
            ''',
            (round_number,),
        ).fetchall()

        for match in confirmed:
            p1_points, p2_points = _match_points(int(match['confirmed_score1']), int(match['confirmed_score2']))
            totals[int(match['player1_id'])] += p1_points
            totals[int(match['player2_id'])] += p2_points

        points_rows = [
            PlayerRoundPointsDto(player_id=player_id, display_name=player_names[player_id], points=points)
            for player_id, points in totals.items()
        ]
        points_rows.sort(key=lambda row: (-row.points, row.display_name.lower()))
        result.append(RoundPointsDto(round_number=round_number, points=points_rows))

    return result


def _current_round(conn: sqlite3.Connection) -> Optional[int]:
    pending = conn.execute(
        '''
        SELECT MIN(round_number) AS round_number
        FROM matches
        WHERE confirmed_score1 IS NULL OR confirmed_score2 IS NULL
        '''
    ).fetchone()
    if pending and pending['round_number'] is not None:
        return int(pending['round_number'])

    latest = conn.execute('SELECT MAX(round_number) AS round_number FROM matches').fetchone()
    if latest and latest['round_number'] is not None:
        return int(latest['round_number'])
    return None


def _standings_by_round(conn: sqlite3.Connection) -> list[RoundStandingsDto]:
    round_rows = conn.execute(
        'SELECT DISTINCT round_number FROM matches ORDER BY round_number'
    ).fetchall()
    output: list[RoundStandingsDto] = []

    for row in round_rows:
        round_number = int(row['round_number'])
        pending = conn.execute(
            '''
            SELECT COUNT(*) AS pending_count
            FROM matches
            WHERE round_number = ?
              AND (confirmed_score1 IS NULL OR confirmed_score2 IS NULL)
            ''',
            (round_number,),
        ).fetchone()
        is_complete = int(pending['pending_count']) == 0 if pending is not None else False
        output.append(
            RoundStandingsDto(
                round_number=round_number,
                is_complete=is_complete,
                standings=_standings(conn, up_to_round=round_number),
            )
        )

    return output


def _init_db() -> None:
    with closing(_get_connection()) as conn:
        conn.executescript(
            '''
            CREATE TABLE IF NOT EXISTS users (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              handle TEXT NOT NULL UNIQUE,
              display_name TEXT NOT NULL,
              password_hash TEXT NOT NULL,
              role TEXT NOT NULL CHECK(role IN ('player', 'viewer')),
              created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
            );

            CREATE TABLE IF NOT EXISTS sessions (
              token TEXT PRIMARY KEY,
              user_id INTEGER NOT NULL,
              created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
              FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
            );

            CREATE TABLE IF NOT EXISTS social_identities (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              provider TEXT NOT NULL CHECK(provider IN ('google', 'apple')),
              provider_user_id TEXT NOT NULL,
              user_id INTEGER NOT NULL,
              created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
              UNIQUE(provider, provider_user_id),
              FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
            );

            CREATE TABLE IF NOT EXISTS matches (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              round_number INTEGER NOT NULL,
              table_number INTEGER NOT NULL,
              player1_id INTEGER NOT NULL,
              player2_id INTEGER NOT NULL,
              confirmed_score1 INTEGER,
              confirmed_score2 INTEGER,
              confirmed_at TEXT,
              FOREIGN KEY (player1_id) REFERENCES users(id) ON DELETE CASCADE,
              FOREIGN KEY (player2_id) REFERENCES users(id) ON DELETE CASCADE
            );

            CREATE TABLE IF NOT EXISTS score_confirmations (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              match_id INTEGER NOT NULL,
              player_id INTEGER NOT NULL,
              score1 INTEGER NOT NULL,
              score2 INTEGER NOT NULL,
              created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
              updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
              UNIQUE(match_id, player_id),
              FOREIGN KEY (match_id) REFERENCES matches(id) ON DELETE CASCADE,
              FOREIGN KEY (player_id) REFERENCES users(id) ON DELETE CASCADE
            );

            CREATE INDEX IF NOT EXISTS idx_matches_round ON matches(round_number);
            CREATE INDEX IF NOT EXISTS idx_confirmations_match ON score_confirmations(match_id);
            CREATE INDEX IF NOT EXISTS idx_sessions_user ON sessions(user_id);
            CREATE INDEX IF NOT EXISTS idx_social_identity_user ON social_identities(user_id);
            '''
        )
        _seed_demo_data(conn, force=False)
        conn.commit()


@asynccontextmanager
async def _lifespan(_: FastAPI):
    _init_db()
    yield


app = FastAPI(
    title='Swiss Round Robin API',
    version='0.1.0',
    lifespan=_lifespan,
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=['*'],
    allow_methods=['*'],
    allow_headers=['*'],
)


@app.get('/health')
def health() -> dict[str, str]:
    return {'status': 'ok'}


@app.post('/setup/seed')
def seed_data(force: bool = Query(default=False)) -> dict[str, int]:
    with closing(_get_connection()) as conn:
        details = _seed_demo_data(conn, force=force)
        conn.commit()
    return details


@app.api_route('/callbacks/sign_in_with_apple', methods=['GET', 'POST'])
async def apple_sign_in_callback(request: Request):
    if request.method == 'POST':
        form = await request.form()
        pairs = list(form.multi_items())
    else:
        pairs = list(request.query_params.multi_items())

    encoded = urllib.parse.urlencode(pairs, doseq=True)
    intent_url = (
        f'intent://callback?{encoded}'
        f'#Intent;package={APPLE_ANDROID_PACKAGE};scheme=signinwithapple;end'
    )

    if request.method == 'POST':
        # Apple sends form_post on Android flow; immediately bounce to app deep link.
        return RedirectResponse(url=intent_url, status_code=status.HTTP_302_FOUND)

    html = f'''
    <!doctype html>
    <html>
      <head><meta charset="utf-8"><title>Sign in with Apple Callback</title></head>
      <body>
        <p>Returning to app…</p>
        <p><a href="{intent_url}">Tap here if not redirected</a></p>
        <script>window.location.replace("{intent_url}");</script>
      </body>
    </html>
    '''
    return HTMLResponse(content=html)


@app.post('/auth/register', response_model=AuthResponse)
def register(payload: RegisterRequest) -> AuthResponse:
    handle = _normalize_handle(payload.handle)

    with closing(_get_connection()) as conn:
        try:
            cursor = conn.execute(
                '''
                INSERT INTO users (handle, display_name, password_hash, role)
                VALUES (?, ?, ?, ?)
                ''',
                (handle, payload.display_name.strip(), _hash_password(payload.password), payload.role),
            )
        except sqlite3.IntegrityError as error:
            raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail='Handle already exists.') from error

        user_id = int(cursor.lastrowid)
        token = secrets.token_urlsafe(32)

        conn.execute('INSERT INTO sessions (token, user_id) VALUES (?, ?)', (token, user_id))
        conn.commit()

        user_row = conn.execute(
            'SELECT id, handle, display_name, role FROM users WHERE id = ?', (user_id,)
        ).fetchone()

    if user_row is None:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail='User creation failed.')

    return AuthResponse(token=token, user=_row_to_user(user_row))


@app.post('/auth/login', response_model=AuthResponse)
def login(payload: LoginRequest) -> AuthResponse:
    handle = _normalize_handle(payload.handle)

    with closing(_get_connection()) as conn:
        user_row = conn.execute(
            'SELECT id, handle, display_name, role, password_hash FROM users WHERE handle = ?',
            (handle,),
        ).fetchone()

        if user_row is None or not _verify_password(payload.password, str(user_row['password_hash'])):
            raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail='Invalid credentials.')

        token = secrets.token_urlsafe(32)
        conn.execute('INSERT INTO sessions (token, user_id) VALUES (?, ?)', (token, int(user_row['id'])))
        conn.commit()

    return AuthResponse(
        token=token,
        user=UserDto(
            id=int(user_row['id']),
            handle=str(user_row['handle']),
            display_name=str(user_row['display_name']),
            role=str(user_row['role']),
        ),
    )


@app.post('/auth/social', response_model=AuthResponse)
def social_login(payload: SocialLoginRequest) -> AuthResponse:
    provider_user_id = payload.provider_user_id.strip()
    if not provider_user_id:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail='Missing provider user id.')

    display_name = payload.display_name.strip()
    if not display_name:
        display_name = f'{payload.provider.capitalize()} Player'

    normalized_email = payload.email.strip().lower() if payload.email else None
    normalized_hint = payload.handle_hint.strip().lower() if payload.handle_hint else None

    with closing(_get_connection()) as conn:
        existing = conn.execute(
            '''
            SELECT u.id, u.handle, u.display_name, u.role
            FROM social_identities si
            JOIN users u ON u.id = si.user_id
            WHERE si.provider = ? AND si.provider_user_id = ?
            ''',
            (payload.provider, provider_user_id),
        ).fetchone()

        if existing is None:
            base_handle = _social_handle_base(
                provider=payload.provider,
                provider_user_id=provider_user_id,
                handle_hint=normalized_hint,
                email=normalized_email,
                display_name=display_name,
            )
            handle = _ensure_unique_handle(conn, base_handle)

            cursor = conn.execute(
                '''
                INSERT INTO users (handle, display_name, password_hash, role)
                VALUES (?, ?, ?, 'player')
                ''',
                (handle, display_name, _hash_password(secrets.token_urlsafe(32))),
            )
            user_id = int(cursor.lastrowid)
            conn.execute(
                '''
                INSERT INTO social_identities (provider, provider_user_id, user_id)
                VALUES (?, ?, ?)
                ''',
                (payload.provider, provider_user_id, user_id),
            )
            user_row = conn.execute(
                'SELECT id, handle, display_name, role FROM users WHERE id = ?',
                (user_id,),
            ).fetchone()
        else:
            user_id = int(existing['id'])
            user_row = existing

        token = _issue_session(conn, user_id)
        conn.commit()

    if user_row is None:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail='Social login failed.')

    return AuthResponse(token=token, user=_row_to_user(user_row))


@app.post('/auth/logout')
def logout(authorization: Annotated[Optional[str], Header()] = None) -> dict[str, bool]:
    token = _token_from_header(authorization)
    if token is None:
        return {'ok': True}

    with closing(_get_connection()) as conn:
        conn.execute('DELETE FROM sessions WHERE token = ?', (token,))
        conn.commit()
    return {'ok': True}


@app.get('/auth/me', response_model=UserDto)
def me(authorization: Annotated[Optional[str], Header()] = None) -> UserDto:
    return _require_user(authorization)


@app.get('/rounds', response_model=list[RoundDto])
def rounds(authorization: Annotated[Optional[str], Header()] = None) -> list[RoundDto]:
    user = _optional_user(authorization)
    user_id = user.id if user is not None else None
    with closing(_get_connection()) as conn:
        return _fetch_rounds(conn, user_id=user_id)


@app.post('/matches/{match_id}/confirm', response_model=MatchDto)
def confirm_match_score(
    match_id: int,
    payload: ScoreConfirmRequest,
    authorization: Annotated[Optional[str], Header()] = None,
) -> MatchDto:
    user = _require_user(authorization)
    if user.role != 'player':
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail='Only players can confirm scores.')

    with closing(_get_connection()) as conn:
        match_row = conn.execute(
            '''
            SELECT id, player1_id, player2_id, confirmed_score1, confirmed_score2
            FROM matches
            WHERE id = ?
            ''',
            (match_id,),
        ).fetchone()

        if match_row is None:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail='Match not found.')

        player1_id = int(match_row['player1_id'])
        player2_id = int(match_row['player2_id'])
        if user.id not in (player1_id, player2_id):
            raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail='You are not assigned to this match.')

        if match_row['confirmed_score1'] is not None and match_row['confirmed_score2'] is not None:
            raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail='Scores are already confirmed for this match.')

        conn.execute(
            '''
            INSERT INTO score_confirmations (match_id, player_id, score1, score2, created_at, updated_at)
            VALUES (?, ?, ?, ?, ?, ?)
            ON CONFLICT(match_id, player_id)
            DO UPDATE SET
              score1 = excluded.score1,
              score2 = excluded.score2,
              updated_at = excluded.updated_at
            ''',
            (match_id, user.id, payload.score1, payload.score2, _utc_now(), _utc_now()),
        )

        _confirm_scores_if_consensus(conn, match_id)
        conn.commit()

        refreshed = conn.execute(
            '''
            SELECT
              m.id,
              m.round_number,
              m.table_number,
              m.player1_id,
              m.player2_id,
              m.confirmed_score1,
              m.confirmed_score2,
              u1.handle AS player1_handle,
              u1.display_name AS player1_name,
              u2.handle AS player2_handle,
              u2.display_name AS player2_name,
              (SELECT COUNT(*) FROM score_confirmations sc WHERE sc.match_id = m.id) AS confirmations,
              (
                SELECT COUNT(DISTINCT sc.score1 || ':' || sc.score2)
                FROM score_confirmations sc
                WHERE sc.match_id = m.id
              ) AS distinct_confirmations,
              my.score1 AS my_score1,
              my.score2 AS my_score2
            FROM matches m
            JOIN users u1 ON u1.id = m.player1_id
            JOIN users u2 ON u2.id = m.player2_id
            LEFT JOIN score_confirmations my
              ON my.match_id = m.id
             AND my.player_id = ?
            WHERE m.id = ?
            ''',
            (user.id, match_id),
        ).fetchone()

    if refreshed is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail='Match not found after update.')

    return _build_match_dto(refreshed)


@app.get('/standings', response_model=list[StandingRowDto])
def standings(round: Optional[int] = Query(default=None, ge=1)) -> list[StandingRowDto]:
    with closing(_get_connection()) as conn:
        return _standings(conn, up_to_round=round)


@app.get('/round-points', response_model=list[RoundPointsDto])
def round_points() -> list[RoundPointsDto]:
    with closing(_get_connection()) as conn:
        return _round_points(conn)


@app.get('/standings/by-round', response_model=list[RoundStandingsDto])
def standings_by_round() -> list[RoundStandingsDto]:
    with closing(_get_connection()) as conn:
        return _standings_by_round(conn)


@app.get('/live', response_model=LiveSnapshotDto)
def live_snapshot(authorization: Annotated[Optional[str], Header()] = None) -> LiveSnapshotDto:
    user = _optional_user(authorization)
    user_id = user.id if user is not None else None

    with closing(_get_connection()) as conn:
        return LiveSnapshotDto(
            generated_at=_utc_now(),
            current_round=_current_round(conn),
            rounds=_fetch_rounds(conn, user_id=user_id),
            standings=_standings(conn),
        )
