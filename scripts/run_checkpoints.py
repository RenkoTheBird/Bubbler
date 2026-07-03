#!/usr/bin/env python3
"""
Bubbler checkpoint runner — roadmap Phases 0–3.

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
IOS_APP_ROOT = ROOT / "BubblerApp" / "BubblerApp"
IOS_PROJECT_FILE = ROOT / "BubblerApp" / "BubblerApp.xcodeproj" / "project.pbxproj"
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
PHASE3_CHECKPOINT_EMAIL = os.getenv(
    "PHASE3_CHECKPOINT_EMAIL", "phase3-checkpoint@bubbler.com"
)
PHASE3_CHECKPOINT_USERNAME = os.getenv("PHASE3_CHECKPOINT_USERNAME", "phase3ckpt")
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


PhaseFn = Callable[[Context], Any]

PHASES: list[tuple[str, str, PhaseFn]] = [
    ("0", "Fix Auth + Register Routers", run_phase_0),
    ("1", "JWT Protection on Routes", run_phase_1),
    ("2", "Backend Data Layer", run_phase_2),
    ("3", "iOS Backend Auth (Drop Firebase)", run_phase_3),
]


async def main() -> int:
    print("Bubbler checkpoints (backend + iOS static)")
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
