#!/usr/bin/env python3
"""
Backend checkpoint runner — roadmap Phases 0, 1, and 2.

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
from typing import Any, Callable
from urllib.parse import urlencode

import asyncpg
from dotenv import load_dotenv

BACKEND_ROOT = Path(__file__).resolve().parent.parent / "backend"
ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(BACKEND_ROOT))
sys.path.insert(0, str(ROOT))

load_dotenv(BACKEND_ROOT / ".env")

from config import my_env_vars  # noqa: E402
from app.repositories.edge_builder_repo import EdgeBuilderRepo  # noqa: E402
from app.services.post import EmbeddingService  # noqa: E402
from app.ml.embeddings.generate import embed  # noqa: E402
from app.db.vector import to_pgvector  # noqa: E402

# --- Test identity (isolated from manual/dev accounts) ---

CHECKPOINT_EMAIL = os.getenv("CHECKPOINT_EMAIL", "checkpoint@bubbler.com")
CHECKPOINT_USERNAME = os.getenv("CHECKPOINT_USERNAME", "ckptuser")
CHECKPOINT_PASSWORD = os.getenv("CHECKPOINT_PASSWORD", "secret123")
API_BASE_URL = os.getenv("API_BASE_URL", "http://127.0.0.1:8000").rstrip("/")

SAMPLE_TOPICS = ["tech", "health", "startups"]
SAMPLE_POSTS = [
    ("I love building side projects.", "tech"),
    ("Morning runs clear my head.", "health"),
    ("This startup idea needs validation.", "startups"),
    ("Hot take: tabs over spaces.", "tech"),
]

REQUIRED_OPENAPI_PATHS = [
    "/auth/login",
    "/auth/register",
    "/feed/me",
    "/feed/me/session",
    "/user/me",
    "/user/me/posts",
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


async def reset_checkpoint_data(pool: asyncpg.Pool) -> None:
    """Remove prior checkpoint user and related rows so each run starts clean."""
    async with pool.acquire() as conn:
        user_id = await conn.fetchval(
            "SELECT id FROM users WHERE email = $1", CHECKPOINT_EMAIL
        )
        if user_id is None:
            return

        post_ids = [
            row["id"]
            for row in await conn.fetch(
                "SELECT id FROM posts WHERE user_id = $1", user_id
            )
        ]
        if post_ids:
            await conn.execute(
                """
                DELETE FROM edges
                WHERE from_post_id = ANY($1::uuid[]) OR to_post_id = ANY($1::uuid[])
                """,
                post_ids,
            )
        await conn.execute("DELETE FROM interactions WHERE user_id = $1", user_id)
        await conn.execute("DELETE FROM posts WHERE user_id = $1", user_id)
        await conn.execute("DELETE FROM user_profiles WHERE user_id = $1", user_id)
        await conn.execute("DELETE FROM users WHERE id = $1", user_id)


async def seed_checkpoint_posts(pool: asyncpg.Pool, user_id: int) -> int:
    """Insert sample topics/posts + edges; returns number of posts inserted."""
    edge_builder = EdgeBuilderRepo(pool)
    embedding_service = EmbeddingService()
    inserted = 0

    async with pool.acquire() as conn:
        topic_ids: dict[str, Any] = {}
        for name in SAMPLE_TOPICS:
            topic_id = await conn.fetchval(
                """
                INSERT INTO topics (name)
                VALUES ($1)
                ON CONFLICT (name) DO UPDATE SET name = EXCLUDED.name
                RETURNING id
                """,
                name,
            )
            topic_ids[name] = topic_id

        for content, topic_name in SAMPLE_POSTS:
            vector = embed(content)
            post_id = await conn.fetchval(
                """
                INSERT INTO posts (user_id, content, topic_id, embedding)
                VALUES ($1, $2, $3, $4::vector)
                RETURNING id
                """,
                user_id,
                content,
                topic_ids[topic_name],
                to_pgvector(vector),
            )
            await edge_builder.build_edges_for_post(
                embedding_service, post_id, vector
            )
            inserted += 1

    return inserted


async def edge_count(pool: asyncpg.Pool) -> int:
    async with pool.acquire() as conn:
        return await conn.fetchval("SELECT COUNT(*) FROM edges") or 0


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
        f"/user/me/posts?{urlencode({'post': post_text})}",
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


PhaseFn = Callable[[Context], Any]

PHASES: list[tuple[str, str, PhaseFn]] = [
    ("0", "Fix Auth + Register Routers", run_phase_0),
    ("1", "JWT Protection on Routes", run_phase_1),
    ("2", "Backend Data Layer", run_phase_2),
    # ("3", "iOS Backend Auth", run_phase_3),
]


async def main() -> int:
    print("Bubbler backend checkpoints")
    print(f"  API:  {API_BASE_URL}")
    print(f"  DB:   {my_env_vars.host}:{my_env_vars.port}/{my_env_vars.database}")
    print(f"  User: {CHECKPOINT_EMAIL}")

    pool = await asyncpg.create_pool(my_env_vars.db_url)
    ctx = Context(api=ApiClient(API_BASE_URL), pool=pool)

    try:
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
