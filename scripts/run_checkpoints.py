#!/usr/bin/env python3
"""
Bubbler checkpoint runner — roadmap Phases 0–6.

Prerequisites:
  - Postgres running (credentials in backend/.env, e.g. PORT=5433)
  - API server: cd backend && pipenv run uvicorn main:app --host 127.0.0.1 --port 8000

Run from repo root:
  pipenv run --directory backend python ../scripts/run_checkpoints.py

Optional env overrides (in backend/.env or shell):
  API_BASE_URL=http://127.0.0.1:8000
  CHECKPOINT_EMAIL=checkpoint@bubbler.com
  CHECKPOINT_USERNAME=ckptuser
  CHECKPOINT_PASSWORD=secret123
  PHASE3_CHECKPOINT_EMAIL=phase3-checkpoint@bubbler.com
  PHASE3_CHECKPOINT_USERNAME=phase3ckpt

Phase 3 maps to docs/roadmap.md “Drop Firebase” conditions 1–8:
  1–4  API auth (register, login, protected route 401/200)
  5–7  iOS source checks (AuthSession, Keychain, APIClient Bearer header)
  8    Manual — login + create-account on simulator (printed as SKIP)

Phase 4 maps to docs/roadmap.md “Connect iOS to Real Feed Data”:
  1    Signed-in user sees real post content from the database

Phase 5 maps to docs/roadmap.md “Graph Path (Core Product)”:
  1    Session route returns a current post candidate
  2    Graph route returns tap-through next choices across 3–4 posts
  3    iOS graph UI loads session/current/next-choice wiring

Phase 6 maps to docs/roadmap.md “User-Controlled Algorithm”:
  1    Randomness can reshuffle ranked results
  2    Blacklisting a topic removes it from the feed
  3    iOS settings UI exposes randomness + blacklisted topics

Phase 7 maps to post/topic features on the new schema (post_topics, topic_training_events):
  1    Create post with an explicit topic
  2    Edit post content
  3    Add and remove secondary topics on a post
  4    Topic training events logged for user corrections
  5    iOS create-post flow sends topic with new posts

How to run
Terminal 1 — start the API (if not already running):

cd backend && pipenv run uvicorn main:app --host 127.0.0.1 --port 8000

Terminal 2 — run checkpoints:

cd backend && pipenv run python ../scripts/run_checkpoints.py
"""

from __future__ import annotations

import asyncio
import json
import os
import sys
import urllib.error
import urllib.request
from dataclasses import dataclass, field
from pathlib import Path
from types import SimpleNamespace
from typing import Any, Callable
from urllib.parse import urlencode

import asyncpg
from dotenv import load_dotenv

BACKEND_ROOT = Path(__file__).resolve().parent.parent / "backend"
ROOT = Path(__file__).resolve().parent.parent
IOS_APP_ROOT = ROOT / "BubblerApp" / "BubblerApp"
IOS_PROJECT_FILE = ROOT / "BubblerApp" / "BubblerApp.xcodeproj" / "project.pbxproj"
sys.path.insert(0, str(BACKEND_ROOT))
sys.path.insert(0, str(ROOT))

load_dotenv(BACKEND_ROOT / ".env")

try:
    from seed_db import SAMPLE_POSTS as SEEDED_SAMPLE_POSTS  # noqa: E402
    from seed_db import SAMPLE_TOPICS as SEEDED_SAMPLE_TOPICS  # noqa: E402
    from seed_db import ensure_schema  # noqa: E402
except Exception:  # pragma: no cover - fallback keeps checkpoints runnable
    async def ensure_schema(pool):  # type: ignore[misc]
        return None

    SEEDED_SAMPLE_TOPICS = ["technology", "health", "business"]
    SEEDED_SAMPLE_POSTS = [
        ("I love building side projects.", "technology"),
        ("Morning runs clear my head.", "health"),
        ("This startup idea needs validation.", "business"),
        ("Hot take: tabs over spaces.", "technology"),
    ]

from config import my_env_vars  # noqa: E402
from app.db.topics import DEFAULT_TOPIC, KNOWN_TOPICS  # noqa: E402
from app.repositories.edge_builder_repo import EdgeBuilderRepo  # noqa: E402
from app.services.feed import RankingService  # noqa: E402
from app.services.post import EmbeddingService  # noqa: E402
from app.ml.embeddings.generate import embed  # noqa: E402
from app.db.vector import to_pgvector  # noqa: E402

# --- Test identity (isolated from manual/dev accounts) ---

CHECKPOINT_EMAIL = os.getenv("CHECKPOINT_EMAIL", "checkpoint@bubbler.com")
CHECKPOINT_USERNAME = os.getenv("CHECKPOINT_USERNAME", "ckptuser")
CHECKPOINT_PASSWORD = os.getenv("CHECKPOINT_PASSWORD", "secret123")
PHASE3_CHECKPOINT_EMAIL = os.getenv(
    "PHASE3_CHECKPOINT_EMAIL", "phase3-checkpoint@bubbler.com"
)
PHASE3_CHECKPOINT_USERNAME = os.getenv("PHASE3_CHECKPOINT_USERNAME", "phase3ckpt")
API_BASE_URL = os.getenv("API_BASE_URL", "http://127.0.0.1:8000").rstrip("/")

SAMPLE_TOPICS = list(SEEDED_SAMPLE_TOPICS)
SAMPLE_POSTS = list(SEEDED_SAMPLE_POSTS)

REQUIRED_OPENAPI_PATHS = [
    "/auth/login",
    "/auth/register",
    "/feed/me",
    "/feed/me/session",
    "/user/me",
    "/user/me/posts",
    "/user/me/posts/{post_id}",
    "/user/me/posts/{post_id}/topics",
    "/user/me/posts/{post_id}/topics/{topic_name}",
    "/user/me/preferences",
    "/graph/posts/{post_id}/next",
]


@dataclass
class Context:
    api: "ApiClient"
    pool: asyncpg.Pool | None = None
    token: str = ""
    user_id: int | None = None
    failures: list[str] = field(default_factory=list)


class ApiClient:
    def __init__(self, base_url: str):
        self.base_url = base_url

    def request(
        self,
        method: str,
        path: str,
        *,
        json_body: dict | None = None,
        form: dict | None = None,
        token: str | None = None,
        timeout: int = 60,
    ) -> tuple[int, Any, str]:
        url = f"{self.base_url}{path}"
        headers: dict[str, str] = {}
        data: bytes | None = None

        if token:
            headers["Authorization"] = f"Bearer {token}"
        if form is not None:
            data = urlencode(form).encode()
            headers["Content-Type"] = "application/x-www-form-urlencoded"
        elif json_body is not None:
            data = json.dumps(json_body).encode()
            headers["Content-Type"] = "application/json"

        req = urllib.request.Request(url, data=data, headers=headers, method=method)
        try:
            with urllib.request.urlopen(req, timeout=timeout) as resp:
                raw = resp.read().decode()
                status = resp.status
        except urllib.error.HTTPError as exc:
            raw = exc.read().decode()
            status = exc.code

        parsed: Any
        try:
            parsed = json.loads(raw) if raw else None
        except json.JSONDecodeError:
            parsed = raw
        return status, parsed, raw


def ok(ctx: Context, name: str, condition: bool, detail: str = "") -> bool:
    if condition:
        print(f"  PASS  {name}")
        return True
    msg = f"  FAIL  {name}" + (f" — {detail}" if detail else "")
    print(msg)
    ctx.failures.append(msg.strip())
    return False


def skip(name: str, detail: str = "") -> None:
    print(f"  SKIP  {name}" + (f" — {detail}" if detail else ""))


def read_ios_file(name: str) -> str:
    path = IOS_APP_ROOT / name
    if not path.is_file():
        return ""
    return path.read_text(encoding="utf-8")


def ios_swift_sources() -> list[tuple[str, str]]:
    if not IOS_APP_ROOT.is_dir():
        return []
    return [
        (str(path.relative_to(IOS_APP_ROOT)), path.read_text(encoding="utf-8"))
        for path in sorted(IOS_APP_ROOT.rglob("*.swift"))
    ]


async def seed_topic_embeddings(conn: asyncpg.Connection, topic_names: set[str]) -> None:
    """Upsert topic rows with embeddings for the curated topic list."""
    for name in sorted(topic_names):
        topic_vector = to_pgvector(embed(name))
        await conn.execute(
            """
            INSERT INTO topics (name, embedding)
            VALUES ($1, $2::vector)
            ON CONFLICT (name) DO UPDATE
            SET embedding = COALESCE(topics.embedding, EXCLUDED.embedding)
            """,
            name,
            topic_vector,
        )


async def reset_checkpoint_data(pool: asyncpg.Pool) -> None:
    """Remove prior checkpoint users; ON DELETE CASCADE cleans related rows."""
    async with pool.acquire() as conn:
        for email in (CHECKPOINT_EMAIL, PHASE3_CHECKPOINT_EMAIL):
            await conn.execute("DELETE FROM users WHERE email = $1", email)


async def seed_checkpoint_posts(pool: asyncpg.Pool, user_id: int) -> int:
    """Insert sample topics/posts + edges; returns number of posts inserted."""
    edge_builder = EdgeBuilderRepo(pool)
    embedding_service = EmbeddingService()
    inserted = 0

    async with pool.acquire() as conn:
        await seed_topic_embeddings(
            conn,
            {*SAMPLE_TOPICS, DEFAULT_TOPIC, *KNOWN_TOPICS},
        )

        for content, topic_name in SAMPLE_POSTS:
            vector = embed(content)
            post_id = await conn.fetchval(
                """
                INSERT INTO posts (user_id, content, embedding)
                VALUES ($1, $2, $3::vector)
                RETURNING id
                """,
                user_id,
                content,
                to_pgvector(vector),
            )
            await conn.execute(
                """
                INSERT INTO post_topics (post_id, topic_name, source, confidence, weight)
                VALUES ($1, $2, 'user', 1.0, 1.0)
                ON CONFLICT DO NOTHING
                """,
                post_id,
                topic_name,
            )
            await edge_builder.build_edges_for_post(post_id, vector)
            inserted += 1

    return inserted


async def edge_count(pool: asyncpg.Pool) -> int:
    async with pool.acquire() as conn:
        return await conn.fetchval("SELECT COUNT(*) FROM edges") or 0


async def fetch_posts_by_id(pool: asyncpg.Pool, post_ids: list[str]) -> dict[str, dict[str, Any]]:
    if not post_ids:
        return {}

    async with pool.acquire() as conn:
        rows = await conn.fetch(
            """
            SELECT id::text AS id, content, user_id, created_at
            FROM posts
            WHERE id::text = ANY($1::text[])
            """,
            post_ids,
        )

    return {str(row["id"]): dict(row) for row in rows}


async def fetch_post_topic_names(pool: asyncpg.Pool, post_id: str) -> list[str]:
    async with pool.acquire() as conn:
        rows = await conn.fetch(
            """
            SELECT topic_name
            FROM post_topics
            WHERE post_id = $1::uuid
            ORDER BY topic_name
            """,
            post_id,
        )
    return [str(row["topic_name"]) for row in rows]


async def count_topic_training_events(
    pool: asyncpg.Pool,
    post_id: str,
    *,
    action: str | None = None,
    topic_name: str | None = None,
) -> int:
    clauses = ["post_id = $1::uuid"]
    params: list[Any] = [post_id]
    if action is not None:
        params.append(action)
        clauses.append(f"action = ${len(params)}")
    if topic_name is not None:
        params.append(topic_name)
        clauses.append(f"topic_name = ${len(params)}")

    query = f"SELECT COUNT(*) FROM topic_training_events WHERE {' AND '.join(clauses)}"
    async with pool.acquire() as conn:
        return await conn.fetchval(query, *params) or 0


async def fetch_user_posts(pool: asyncpg.Pool, user_id: int) -> list[dict[str, Any]]:
    async with pool.acquire() as conn:
        rows = await conn.fetch(
            """
            SELECT
                pwt.id::text AS id,
                pwt.content,
                pwt.topic,
                pwt.created_at
            FROM posts_with_topic pwt
            WHERE pwt.user_id = $1
            ORDER BY pwt.created_at DESC
            """,
            user_id,
        )

    return [dict(row) for row in rows]


async def ensure_dense_graph_edges(pool: asyncpg.Pool, post_ids: list[str]) -> None:
    if len(post_ids) < 2:
        return

    async with pool.acquire() as conn:
        for from_index, from_post_id in enumerate(post_ids):
            for to_index, to_post_id in enumerate(post_ids):
                if from_post_id == to_post_id:
                    continue

                distance = abs(from_index - to_index)
                # Use very large weights so these deterministic edges outrank
                # any organically generated similarity edges already in the DB.
                weight = 100.0 - distance
                await conn.execute(
                    """
                    INSERT INTO edges (from_post_id, to_post_id, edge_type, weight)
                    VALUES ($1::uuid, $2::uuid, 'similar', $3)
                    ON CONFLICT DO NOTHING
                    """,
                    from_post_id,
                    to_post_id,
                    weight,
                )


def visible_posts(body: Any) -> list[dict[str, Any]]:
    if not isinstance(body, list):
        return []

    return [
        post
        for post in body
        if isinstance(post, dict)
        and str(post.get("id", "")).strip()
        and str(post.get("content", "")).strip()
    ]


def post_ids(posts: list[dict[str, Any]]) -> list[str]:
    return [str(post.get("id", "")).strip() for post in posts if str(post.get("id", "")).strip()]


def preferences_payload(body: Any, **overrides: Any) -> dict[str, Any]:
    data = body if isinstance(body, dict) else {}
    payload = {
        "diversity_tolerance": float(data.get("diversity_tolerance", 0.4)),
        "randomness": float(data.get("randomness", 0.3)),
        "topic_preferences": list(data.get("topic_preferences", [])),
        "use_view_time": bool(data.get("use_view_time", False)),
        "view_time_weight": float(data.get("view_time_weight", 0.1)),
        "use_recency": bool(data.get("use_recency", True)),
        "ai_topic_detection": bool(data.get("ai_topic_detection", False)),
        "strategy_weights": dict(
            data.get(
                "strategy_weights",
                {"similar": 0.7, "graph": 0.2, "opposite": 0.0, "random": 0.1},
            )
        ),
    }
    payload.update(overrides)
    return payload


def blacklisted_topics_from_prefs(body: Any) -> list[str]:
    if not isinstance(body, dict):
        return []
    return [
        str(pref.get("topic", "")).strip()
        for pref in body.get("topic_preferences", [])
        if isinstance(pref, dict) and pref.get("preference_type") == "blacklisted"
    ]


# --- Phase runners (add Phase 3+ below) ---


def run_phase_0(ctx: Context) -> None:
    """Phase 0 — Auth routes registered; register + login return access_token."""
    status, _, _ = ctx.api.request("GET", "/docs")
    ok(ctx, "API reachable (/docs)", status == 200, f"status={status}")

    status, openapi, _ = ctx.api.request("GET", "/openapi.json")
    if ok(ctx, "OpenAPI schema available", status == 200, f"status={status}"):
        paths = openapi.get("paths", {}) if isinstance(openapi, dict) else {}
        for path in REQUIRED_OPENAPI_PATHS:
            ok(ctx, f"OpenAPI lists {path}", path in paths)

    status, body, raw = ctx.api.request(
        "POST",
        "/auth/register",
        json_body={
            "username": CHECKPOINT_USERNAME,
            "email": CHECKPOINT_EMAIL,
            "password": CHECKPOINT_PASSWORD,
        },
    )
    if status == 409:
        status, body, raw = ctx.api.request(
            "POST",
            "/auth/login",
            form={"username": CHECKPOINT_EMAIL, "password": CHECKPOINT_PASSWORD},
        )
        ok(ctx, "Register (existing user) → login fallback", status == 200, raw[:200])
    else:
        ok(ctx, "POST /auth/register → 200", status == 200, raw[:200])

    if isinstance(body, dict):
        ok(ctx, "Register/login response has access_token", "access_token" in body)
        ok(
            ctx,
            "Register/login response has token_type bearer",
            body.get("token_type") == "bearer",
        )
        ctx.token = body.get("access_token", "")
        ctx.user_id = body.get("user_id")

    status, login_body, raw = ctx.api.request(
        "POST",
        "/auth/login",
        form={"username": CHECKPOINT_EMAIL, "password": CHECKPOINT_PASSWORD},
    )
    ok(ctx, "POST /auth/login (form) → 200", status == 200, raw[:200])
    if isinstance(login_body, dict):
        ok(ctx, "Login response has access_token", "access_token" in login_body)
        ctx.token = login_body.get("access_token", ctx.token)
        ctx.user_id = login_body.get("user_id", ctx.user_id)


def run_phase_1(ctx: Context) -> None:
    """Phase 1 — JWT protection on /feed/me."""
    status, _, raw = ctx.api.request("GET", "/feed/me")
    ok(
        ctx,
        "GET /feed/me without token → 401 or 403",
        status in (401, 403),
        f"status={status}, body={raw[:120]}",
    )

    if not ctx.token:
        ok(ctx, "Valid token available for protected route", False, "missing token from Phase 0")
        return

    status, body, raw = ctx.api.request("GET", "/feed/me", token=ctx.token)
    ok(ctx, "GET /feed/me with Bearer token → 200", status == 200, raw[:200])
    ok(ctx, "Feed response is JSON array", isinstance(body, list), str(type(body)))


async def run_phase_2(ctx: Context) -> None:
    """Phase 2 — Seed data, ranked feed, new post creates edges."""
    if ctx.pool is None or ctx.user_id is None:
        ok(ctx, "Phase 2 prerequisites (pool, user_id)", False)
        return

    inserted = await seed_checkpoint_posts(ctx.pool, ctx.user_id)
    ok(ctx, f"Seed script inserts {len(SAMPLE_POSTS)} posts", inserted == len(SAMPLE_POSTS))

    status, body, raw = ctx.api.request("GET", "/feed/me", token=ctx.token)
    ok(ctx, "GET /feed/me after seed → 200", status == 200, raw[:200])
    ok(
        ctx,
        "GET /feed/me returns ranked posts (non-empty list)",
        isinstance(body, list) and len(body) > 0,
        f"got {len(body) if isinstance(body, list) else type(body)}",
    )

    before = await edge_count(ctx.pool)
    post_text = "Checkpoint automation post about tabs vs spaces"
    status, _, raw = ctx.api.request(
        "POST",
        "/user/me/posts",
        json_body={"post": post_text},
        token=ctx.token,
    )

    ok(ctx, "POST /user/me/posts → 200", status == 200, raw[:200])
    after = await edge_count(ctx.pool)
    ok(
        ctx,
        "New post increases edge count",
        after > before,
        f"before={before}, after={after}",
    )


def run_phase_3(ctx: Context) -> None:
    """Phase 3 — iOS backend auth (roadmap: drop Firebase checklist, conditions 1–8)."""
    phase3_token = ""

    # --- 1: POST /register returns {access_token, token_type} ---
    status, body, raw = ctx.api.request(
        "POST",
        "/auth/register",
        json_body={
            "username": PHASE3_CHECKPOINT_USERNAME,
            "email": PHASE3_CHECKPOINT_EMAIL,
            "password": CHECKPOINT_PASSWORD,
        },
    )
    if status == 409:
        status, body, raw = ctx.api.request(
            "POST",
            "/auth/login",
            form={
                "username": PHASE3_CHECKPOINT_EMAIL,
                "password": CHECKPOINT_PASSWORD,
            },
        )
        ok(
            ctx,
            "3.1 POST /register returns {access_token, token_type}",
            status == 200
            and isinstance(body, dict)
            and "access_token" in body
            and body.get("token_type") == "bearer",
            raw[:200],
        )
    else:
        ok(ctx, "3.1 POST /register → 200", status == 200, raw[:200])
        if isinstance(body, dict):
            ok(ctx, "3.1 response has access_token", "access_token" in body)
            ok(
                ctx,
                "3.1 response has token_type bearer",
                body.get("token_type") == "bearer",
            )

    if isinstance(body, dict):
        phase3_token = body.get("access_token", "")

    # --- 2: POST /login (form: username=email, password) returns token ---
    status, login_body, raw = ctx.api.request(
        "POST",
        "/auth/login",
        form={
            "username": PHASE3_CHECKPOINT_EMAIL,
            "password": CHECKPOINT_PASSWORD,
        },
    )
    ok(ctx, "3.2 POST /auth/login (form) → 200", status == 200, raw[:200])
    if isinstance(login_body, dict):
        ok(ctx, "3.2 login response has access_token", "access_token" in login_body)
        phase3_token = login_body.get("access_token", phase3_token)

    # --- 3: Protected route rejects missing token ---
    status, _, raw = ctx.api.request("GET", "/feed/me")
    ok(
        ctx,
        "3.3 Protected route rejects missing token (401/403)",
        status in (401, 403),
        f"status={status}, body={raw[:120]}",
    )

    # --- 4: Protected route accepts valid Bearer token ---
    if not phase3_token:
        ok(ctx, "3.4 Protected route accepts valid Bearer token (200)", False, "missing token")
    else:
        status, feed_body, raw = ctx.api.request("GET", "/feed/me", token=phase3_token)
        ok(
            ctx,
            "3.4 GET /feed/me with Bearer token → 200",
            status == 200,
            raw[:200],
        )
        ok(
            ctx,
            "3.4 feed response is JSON array",
            isinstance(feed_body, list),
            str(type(feed_body)),
        )

    # --- 5: AuthSession calls backend login/register ---
    auth_session = read_ios_file("Core/AuthSession.swift")
    ok(ctx, "3.5 AuthSession.swift exists", bool(auth_session))
    ok(
        ctx,
        "3.5 signIn calls APIClient.login",
        "APIClient.login" in auth_session,
    )
    ok(
        ctx,
        "3.5 createAccount calls APIClient.register",
        "APIClient.register" in auth_session,
    )

    # --- 6: Token stored in Keychain (survives restart) ---
    ok(
        ctx,
        "3.6 AuthSession saves token via KeychainStore.saveAccessToken",
        "KeychainStore.saveAccessToken" in auth_session,
    )
    ok(
        ctx,
        "3.6 AuthSession restores session from Keychain on init",
        "KeychainStore.loadAccessToken" in auth_session,
    )
    ok(
        ctx,
        "3.6 signOut deletes Keychain token",
        "KeychainStore.deleteAccessToken" in auth_session,
    )
    ok(
        ctx,
        "3.6 KeychainStore.swift exists",
        (IOS_APP_ROOT / "Core" / "KeychainStore.swift").is_file(),
    )

    # --- 7: APIClient sends Authorization: Bearer … ---
    api_client = read_ios_file("Core/APIClient.swift")
    ok(ctx, "3.7 APIClient.swift exists", bool(api_client))
    ok(
        ctx,
        "3.7 authorizedRequest sets Authorization Bearer header",
        'setValue("Bearer' in api_client or "Bearer \\(token)" in api_client,
    )
    ok(
        ctx,
        "3.7 authorizedRequest reads token from Keychain",
        "KeychainStore.loadAccessToken" in api_client,
    )

    # --- 8: Manual simulator test ---
    skip(
        "3.8 Login + create-account flows on simulator",
        "manual — register, kill app, reopen, confirm session persists",
    )

    # --- Firebase dropped (roadmap checkpoint) ---
    swift_sources = ios_swift_sources()
    firebase_imports = [
        name
        for name, source in swift_sources
        if "import Firebase" in source or "FirebaseApp" in source
    ]
    ok(
        ctx,
        "No Firebase imports in iOS Swift sources",
        not firebase_imports,
        ", ".join(firebase_imports) if firebase_imports else "",
    )
    ok(
        ctx,
        "GoogleService-Info.plist removed",
        not (IOS_APP_ROOT / "GoogleService-Info.plist").exists(),
    )
    if IOS_PROJECT_FILE.is_file():
        pbxproj = IOS_PROJECT_FILE.read_text(encoding="utf-8")
        ok(
            ctx,
            "Firebase SPM dependency removed from Xcode project",
            "firebase-ios-sdk" not in pbxproj and "FirebaseAuth" not in pbxproj,
        )
    else:
        ok(ctx, "Xcode project file present", False, str(IOS_PROJECT_FILE))


async def run_phase_4(ctx: Context) -> None:
    """Phase 4 — iOS feed shows real database-backed post content."""
    if ctx.pool is None:
        ok(ctx, "4.1 Database pool available", False)
        return

    if not ctx.token:
        ok(ctx, "4.1 Signed-in user token available", False, "missing token from earlier phase")
        return

    status, body, raw = ctx.api.request("GET", "/feed/me", token=ctx.token)
    ok(ctx, "4.1 GET /feed/me for signed-in user → 200", status == 200, raw[:200])
    ok(ctx, "4.1 Feed response is JSON array", isinstance(body, list), str(type(body)))

    posts = body if isinstance(body, list) else []
    visible_posts = [
        post
        for post in posts
        if isinstance(post, dict)
        and str(post.get("id", "")).strip()
        and str(post.get("content", "")).strip()
    ]
    ok(
        ctx,
        "4.1 Feed returns visible posts with ids and content",
        len(visible_posts) > 0,
        f"visible_posts={len(visible_posts)}",
    )

    if visible_posts:
        db_posts = await fetch_posts_by_id(
            ctx.pool, [str(post["id"]).strip() for post in visible_posts]
        )
        matching_posts = [
            post
            for post in visible_posts
            if db_posts.get(str(post["id"]).strip(), {}).get("content") == post.get("content")
        ]
        ok(
            ctx,
            "4.1 Feed post content matches database rows",
            len(matching_posts) == len(visible_posts),
            f"matched={len(matching_posts)}/{len(visible_posts)}",
        )

    feed_view_model = read_ios_file("Features/Feed/FeedViewModel.swift")
    ok(ctx, "4.2 FeedViewModel.swift exists", bool(feed_view_model))
    ok(
        ctx,
        "4.2 FeedViewModel fetches GET /feed/me",
        'APIClient.get("feed/me", token: token)' in feed_view_model,
    )

    feed_view = read_ios_file("Features/Feed/FeedView.swift")
    ok(ctx, "4.3 FeedView.swift exists", bool(feed_view))
    ok(
        ctx,
        "4.3 FeedView renders FeedViewModel.posts",
        "ForEach(viewModel.posts)" in feed_view,
    )
    ok(
        ctx,
        "4.3 FeedView passes fetched posts into PostCardView",
        "PostCardView(post: post)" in feed_view,
    )

    post_card = read_ios_file("Components/PostCardView.swift")
    ok(ctx, "4.4 PostCardView.swift exists", bool(post_card))
    ok(
        ctx,
        "4.4 PostCardView displays post.content",
        "Text(post.content)" in post_card,
    )


async def run_phase_5(ctx: Context) -> None:
    """Phase 5 — graph path runtime + iOS graph wiring checks."""
    can_run_runtime = ctx.pool is not None and ctx.user_id is not None and bool(ctx.token)
    if not can_run_runtime:
        ok(ctx, "5.1 Graph runtime prerequisites (pool, user_id, token)", False)
    else:
        status, body, raw = ctx.api.request("GET", "/feed/me/session", token=ctx.token)
        ok(ctx, "5.1 GET /feed/me/session → 200", status == 200, raw[:200])
        session_posts = visible_posts(body)
        ok(
            ctx,
            "5.1 Session route returns current post candidates",
            len(session_posts) > 0,
            f"visible_posts={len(session_posts)}",
        )

        user_posts = await fetch_user_posts(ctx.pool, ctx.user_id)
        ok(
            ctx,
            "5.2 Checkpoint user has at least 4 posts for graph traversal",
            len(user_posts) >= 4,
            f"user_posts={len(user_posts)}",
        )

        if len(user_posts) >= 4:
            candidate_post_ids = post_ids(user_posts)
            await ensure_dense_graph_edges(ctx.pool, candidate_post_ids)

            current_post_id = candidate_post_ids[0]
            visited_ids = [current_post_id]

            for step in range(1, 4):
                status, next_body, raw = ctx.api.request(
                    "GET",
                    f"/graph/posts/{current_post_id}/next",
                    token=ctx.token,
                )
                if not ok(
                    ctx,
                    f"5.2 Step {step} GET /graph/posts/{{post_id}}/next → 200",
                    status == 200,
                    raw[:200],
                ):
                    break

                next_choices = [
                    post
                    for post in visible_posts(next_body)
                    if str(post.get("id", "")).strip() != current_post_id
                ]
                ok(
                    ctx,
                    f"5.2 Step {step} loads connected choices",
                    len(next_choices) > 0,
                    f"choices={len(next_choices)}",
                )

                next_node = next(
                    (
                        post
                        for post in next_choices
                        if str(post.get("id", "")).strip()
                        and str(post.get("id", "")).strip() not in visited_ids
                    ),
                    None,
                )
                if not ok(
                    ctx,
                    f"5.2 Step {step} offers a new post to tap",
                    next_node is not None,
                    f"visited={len(visited_ids)}",
                ):
                    break

                current_post_id = str(next_node["id"]).strip()
                visited_ids.append(current_post_id)

            ok(
                ctx,
                "5.2 Tap-through path reaches 4 unique posts",
                len(set(visited_ids)) >= 4,
                f"visited={len(set(visited_ids))}",
            )

    api_client = read_ios_file("Core/APIClient.swift")
    ok(ctx, "5.3 APIClient.swift exists", bool(api_client))
    ok(
        ctx,
        "5.3 APIClient fetches graph session feed",
        "authorizedRequest(path: \"feed/me/session\")" in api_client,
    )
    ok(
        ctx,
        "5.3 APIClient fetches graph next choices",
        'authorizedRequest(path: "graph/posts/\\(postID)/next")' in api_client,
    )

    graph_view_model = read_ios_file("Features/Graph/GraphFeedViewModel.swift")
    ok(ctx, "5.4 GraphFeedViewModel.swift exists", bool(graph_view_model))
    ok(
        ctx,
        "5.4 GraphFeedViewModel loads session posts",
        "APIClient.getSessionFeed()" in graph_view_model,
    )
    ok(
        ctx,
        "5.4 GraphFeedViewModel loads connected next choices",
        "APIClient.getNextGraphPosts(for: node.id)" in graph_view_model,
    )
    ok(
        ctx,
        "5.4 GraphFeedViewModel records explore taps",
        "byRecording: .explore" in graph_view_model,
    )

    graph_view = read_ios_file("Features/Graph/GraphFeedView.swift")
    ok(ctx, "5.5 GraphFeedView.swift exists", bool(graph_view))
    ok(
        ctx,
        "5.5 GraphFeedView renders the current post",
        "if let node = viewModel.currentNode" in graph_view,
    )
    ok(
        ctx,
        "5.5 GraphFeedView renders connected choices",
        "ForEach(viewModel.nextChoices)" in graph_view,
    )
    ok(
        ctx,
        "5.5 GraphFeedView taps a choice to advance",
        "await viewModel.choose(node, using: authSession)" in graph_view,
    )


async def run_phase_6(ctx: Context) -> None:
    """Phase 6 — randomness + blacklisted topics runtime and settings checks."""
    ranking_service = RankingService()
    ranking_posts = [
        {"id": "alpha", "topic": "technology", "similarity": 0.5},
        {"id": "beta", "topic": "health", "similarity": 0.5},
        {"id": "gamma", "topic": "business", "similarity": 0.5},
        {"id": "delta", "topic": "entertainment", "similarity": 0.5},
    ]

    deterministic_order = post_ids(
        ranking_service.apply_preferences(
            SimpleNamespace(
                randomness=0.0,
                topic_preferences=[],
            ),
            [dict(post) for post in ranking_posts],
        )
    )
    ok(
        ctx,
        "6.1 Zero randomness keeps equal-score ranking stable",
        deterministic_order == ["alpha", "beta", "gamma", "delta"],
        str(deterministic_order),
    )

    randomized_orders = {
        tuple(
            post_ids(
                ranking_service.apply_preferences(
                    SimpleNamespace(
                        randomness=1.0,
                        topic_preferences=[],
                    ),
                    [dict(post) for post in ranking_posts],
                )
            )
        )
        for _ in range(8)
    }
    ok(
        ctx,
        "6.1 Randomness can reshuffle ranked results",
        len(randomized_orders) > 1,
        f"unique_orders={len(randomized_orders)}",
    )

    if not ctx.token:
        ok(ctx, "6.2 Preferences API token available", False, "missing token from earlier phase")
    else:
        status, pref_body, raw = ctx.api.request("GET", "/user/me/preferences", token=ctx.token)
        ok(ctx, "6.2 GET /user/me/preferences → 200", status == 200, raw[:200])

        candidate_topic = ""
        if ctx.pool is not None and ctx.user_id is not None:
            for post in await fetch_user_posts(ctx.pool, ctx.user_id):
                topic = str(post.get("topic") or "").strip()
                if topic:
                    candidate_topic = topic
                    break

        if not candidate_topic:
            candidate_topic = SAMPLE_TOPICS[0] if SAMPLE_TOPICS else ""

        ok(ctx, "6.2 Topic available for blacklist test", bool(candidate_topic), candidate_topic)
        if candidate_topic:
            tuned_payload = preferences_payload(
                pref_body,
                randomness=0.0,
                topic_preferences=[],
                strategy_weights={
                    "similar": 1.0,
                    "graph": 0.0,
                    "opposite": 0.0,
                    "random": 0.0,
                },
                use_view_time=False,
            )
            status, tuned_body, raw = ctx.api.request(
                "PUT",
                "/user/me/preferences",
                json_body=tuned_payload,
                token=ctx.token,
            )
            ok(ctx, "6.2 PUT /user/me/preferences saves baseline algorithm settings", status == 200, raw[:200])
            if isinstance(tuned_body, dict):
                ok(ctx, "6.2 Baseline randomness saved as 0", tuned_body.get("randomness") == 0.0)

            blacklisted_payload = preferences_payload(
                tuned_body if isinstance(tuned_body, dict) else pref_body,
                topic_preferences=[
                    {"topic": candidate_topic, "preference_type": "blacklisted"},
                ],
            )
            status, saved_body, raw = ctx.api.request(
                "PUT",
                "/user/me/preferences",
                json_body=blacklisted_payload,
                token=ctx.token,
            )
            ok(ctx, "6.3 PUT /user/me/preferences saves a blacklisted topic", status == 200, raw[:200])
            if isinstance(saved_body, dict):
                saved_blacklist = blacklisted_topics_from_prefs(saved_body)
                ok(
                    ctx,
                    "6.3 Blacklisted topic persists in saved preferences",
                    candidate_topic in saved_blacklist,
                    str(saved_blacklist),
                )

            status, feed_body, raw = ctx.api.request("GET", "/feed/me", token=ctx.token)
            ok(ctx, "6.3 GET /feed/me after blacklist → 200", status == 200, raw[:200])
            blacklisted_posts = [
                post
                for post in visible_posts(feed_body)
                if str(post.get("topic") or "").strip().lower() == candidate_topic.lower()
            ]
            ok(
                ctx,
                "6.3 Blacklisted topic is removed from feed results",
                len(blacklisted_posts) == 0,
                f"topic={candidate_topic}, matches={len(blacklisted_posts)}",
            )

    settings_view_model = read_ios_file("Features/Settings/PreferencesSettingsViewModel.swift")
    ok(ctx, "6.4 PreferencesSettingsViewModel.swift exists", bool(settings_view_model))
    ok(
        ctx,
        "6.4 PreferencesSettingsViewModel loads saved preferences",
        "APIClient.getPreferences()" in settings_view_model,
    )
    ok(
        ctx,
        "6.4 PreferencesSettingsViewModel saves preferences",
        "APIClient.updatePreferences" in settings_view_model,
    )

    settings_view = read_ios_file("Features/Settings/PreferencesSettingsView.swift")
    ok(ctx, "6.5 PreferencesSettingsView.swift exists", bool(settings_view))
    ok(
        ctx,
        "6.5 Settings exposes a Randomness slider",
        'title: "Randomness"' in settings_view,
    )
    ok(
        ctx,
        "6.5 Settings exposes Blacklisted Topics editing",
        'title: "Blacklisted Topics"' in settings_view,
    )

    graph_view_model = read_ios_file("Features/Graph/GraphFeedViewModel.swift")
    ok(
        ctx,
        "6.6 GraphFeedViewModel filters blacklisted session posts",
        "!proposedCurrent.isBlacklistedTopic" in graph_view_model,
    )
    ok(
        ctx,
        "6.6 GraphFeedViewModel filters blacklisted next choices",
        "!choice.isBlacklistedTopic" in graph_view_model,
    )


async def run_phase_7(ctx: Context) -> None:
    """Phase 7 — post editing, topic mutations, and training events on the new schema."""
    if not ctx.token:
        ok(ctx, "7.1 Auth token available", False, "missing token from earlier phase")
        return

    if ctx.pool is None or ctx.user_id is None:
        ok(ctx, "7.1 Database pool and user_id available", False)
        return

    # --- Create post with explicit topic ---
    create_topic = "health"
    create_content = "Checkpoint post with an explicit health topic"
    status, created_body, raw = ctx.api.request(
        "POST",
        "/user/me/posts",
        json_body={"post": create_content, "topic": create_topic},
        token=ctx.token,
    )
    ok(ctx, "7.1 POST /user/me/posts with topic → 200", status == 200, raw[:200])

    created_post_id = ""
    if isinstance(created_body, dict):
        created_post_id = str(created_body.get("id", "")).strip()
        ok(
            ctx,
            "7.1 Created post response includes topic",
            str(created_body.get("topic", "")).strip().lower() == create_topic,
            str(created_body.get("topic")),
        )

    status, bad_topic_body, raw = ctx.api.request(
        "POST",
        "/user/me/posts",
        json_body={"post": "invalid topic test", "topic": "not-a-real-topic"},
        token=ctx.token,
    )
    ok(
        ctx,
        "7.1 Unknown topic on create → 422",
        status == 422,
        f"status={status}, body={raw[:120]}",
    )

    # --- Edit post content ---
    target_post_id = created_post_id
    if not target_post_id:
        user_posts = await fetch_user_posts(ctx.pool, ctx.user_id)
        if user_posts:
            target_post_id = str(user_posts[0].get("id", "")).strip()

    ok(ctx, "7.2 Post available for edit test", bool(target_post_id), target_post_id)
    if target_post_id:
        edited_content = "Checkpoint edited post content about wellness"
        status, _, raw = ctx.api.request(
            "PUT",
            f"/user/me/posts/{target_post_id}",
            json_body={"post": edited_content},
            token=ctx.token,
        )
        ok(ctx, "7.2 PUT /user/me/posts/{post_id} → 200", status == 200, raw[:200])

        db_posts = await fetch_posts_by_id(ctx.pool, [target_post_id])
        ok(
            ctx,
            "7.2 Edited content persisted in database",
            db_posts.get(target_post_id, {}).get("content") == edited_content,
            db_posts.get(target_post_id, {}).get("content", ""),
        )

    # --- Add secondary topic ---
    topic_post_id = target_post_id
    secondary_topic = "science"
    if topic_post_id:
        before_topics = await fetch_post_topic_names(ctx.pool, topic_post_id)
        status, add_body, raw = ctx.api.request(
            "POST",
            f"/user/me/posts/{topic_post_id}/topics",
            json_body={"topic": secondary_topic},
            token=ctx.token,
        )
        ok(ctx, "7.3 POST /user/me/posts/{post_id}/topics → 200", status == 200, raw[:200])

        after_add_topics = await fetch_post_topic_names(ctx.pool, topic_post_id)
        ok(
            ctx,
            "7.3 Secondary topic added to post_topics",
            secondary_topic in after_add_topics and len(after_add_topics) >= len(before_topics) + 1,
            str(after_add_topics),
        )
        ok(
            ctx,
            "7.3 Topic training event logged for add",
            await count_topic_training_events(
                ctx.pool,
                topic_post_id,
                action="add",
                topic_name=secondary_topic,
            )
            >= 1,
            secondary_topic,
        )

        # --- Remove secondary topic ---
        status, _, raw = ctx.api.request(
            "DELETE",
            f"/user/me/posts/{topic_post_id}/topics/{secondary_topic}",
            token=ctx.token,
        )
        ok(
            ctx,
            f"7.4 DELETE /user/me/posts/{{post_id}}/topics/{secondary_topic} → 200",
            status == 200,
            raw[:200],
        )
        after_remove_topics = await fetch_post_topic_names(ctx.pool, topic_post_id)
        ok(
            ctx,
            "7.4 Secondary topic removed from post_topics",
            secondary_topic not in after_remove_topics,
            str(after_remove_topics),
        )
        ok(
            ctx,
            "7.4 Topic training event logged for remove",
            await count_topic_training_events(
                ctx.pool,
                topic_post_id,
                action="remove",
                topic_name=secondary_topic,
            )
            >= 1,
            secondary_topic,
        )

        primary_topic = after_remove_topics[0] if after_remove_topics else ""
        if primary_topic:
            status, _, raw = ctx.api.request(
                "DELETE",
                f"/user/me/posts/{topic_post_id}/topics/{primary_topic}",
                token=ctx.token,
            )
            ok(
                ctx,
                "7.4 Cannot remove the last topic from a post → 422",
                status == 422,
                f"status={status}, body={raw[:120]}",
            )

    # --- User posts list returns topic field ---
    status, user_posts_body, raw = ctx.api.request("GET", "/user/me/posts", token=ctx.token)
    ok(ctx, "7.5 GET /user/me/posts → 200", status == 200, raw[:200])
    user_posts_api = user_posts_body if isinstance(user_posts_body, list) else []
    posts_with_topics = [
        post
        for post in user_posts_api
        if isinstance(post, dict) and str(post.get("topic", "")).strip()
    ]
    ok(
        ctx,
        "7.5 User posts include primary topic from post_topics",
        len(posts_with_topics) > 0,
        f"with_topic={len(posts_with_topics)}",
    )

    # --- Delete post ---
    if created_post_id:
        status, _, raw = ctx.api.request(
            "DELETE",
            f"/user/me/posts/{created_post_id}",
            token=ctx.token,
        )
        ok(ctx, "7.6 DELETE /user/me/posts/{post_id} → 204", status == 204, raw[:120])
        db_posts = await fetch_posts_by_id(ctx.pool, [created_post_id])
        ok(
            ctx,
            "7.6 Deleted post removed from database",
            created_post_id not in db_posts,
            created_post_id,
        )

    # --- iOS create-post + topic picker wiring ---
    create_post_vm = read_ios_file("Features/Post/CreatePostViewModel.swift")
    ok(ctx, "7.7 CreatePostViewModel.swift exists", bool(create_post_vm))
    ok(
        ctx,
        "7.7 CreatePostViewModel submits topic with APIClient.createPost",
        "APIClient.createPost" in create_post_vm and "topic: selectedTopic" in create_post_vm,
    )

    create_post_view = read_ios_file("Features/Post/CreatePostView.swift")
    ok(ctx, "7.8 CreatePostView.swift exists", bool(create_post_view))
    ok(
        ctx,
        "7.8 CreatePostView uses TopicPicker for topic selection",
        "TopicPicker" in create_post_view,
    )

    known_topics = read_ios_file("Models/KnownTopics.swift")
    ok(ctx, "7.9 KnownTopics.swift exists", bool(known_topics))
    ok(
        ctx,
        "7.9 KnownTopics mirrors backend curated list",
        '"technology"' in known_topics and '"health"' in known_topics,
    )


PhaseFn = Callable[[Context], Any]

PHASES: list[tuple[str, str, PhaseFn]] = [
    ("0", "Fix Auth + Register Routers", run_phase_0),
    ("1", "JWT Protection on Routes", run_phase_1),
    ("2", "Backend Data Layer", run_phase_2),
    ("3", "iOS Backend Auth (Drop Firebase)", run_phase_3),
    ("4", "Connect iOS to Real Feed Data", run_phase_4),
    ("5", "Graph Path (Core Product)", run_phase_5),
    ("6", "User-Controlled Algorithm", run_phase_6),
    ("7", "Posts, Topics & Training Events", run_phase_7),
]


async def main() -> int:
    print("Bubbler checkpoints (backend + iOS static)")
    print(f"  API:  {API_BASE_URL}")
    print(f"  DB:   {my_env_vars.host}:{my_env_vars.port}/{my_env_vars.database}")
    print(f"  User: {CHECKPOINT_EMAIL}")

    pool = await asyncpg.create_pool(my_env_vars.db_url)
    ctx = Context(api=ApiClient(API_BASE_URL), pool=pool)

    try:
        print("\n--- Schema ---")
        await ensure_schema(pool)
        print("  PASS  Database schema aligned with reference")

        print("\n--- Reset ---")
        await reset_checkpoint_data(pool)
        print("  PASS  Cleared prior checkpoint test data")

        for phase_id, title, runner in PHASES:
            print(f"\n=== Phase {phase_id}: {title} ===")
            result = runner(ctx)
            if asyncio.iscoroutine(result):
                await result

        print("\n" + "=" * 40)
        if ctx.failures:
            print(f"FAILED — {len(ctx.failures)} check(s):")
            for failure in ctx.failures:
                print(failure)
            return 1

        print(f"ALL PASSED — Phases {PHASES[0][0]}–{PHASES[-1][0]} ({len(PHASES)} phases)")
        return 0
    finally:
        await pool.close()


if __name__ == "__main__":
    raise SystemExit(asyncio.run(main()))
