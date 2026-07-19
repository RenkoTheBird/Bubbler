#!/usr/bin/env python3
"""
Bubbler preference-impact harness.

Starts the backend (if needed), seeds an isolated corpus, then statistically
tests whether each recommendation preference actually changes feed results
by comparing A/B distance distributions against an A/A noise floor.

Prerequisites:
  - Postgres running (credentials in backend/.env)
  - pipenv deps installed in backend/

Run from backend/:
  cd backend && pipenv run python ../scripts/preference_impact.py

Optional env overrides:
  API_BASE_URL=http://127.0.0.1:8000
  IMPACT_PORT=8000
  IMPACT_N=30              # trials per preference condition
  IMPACT_K=10              # top-k for Jaccard / topic JSD
  IMPACT_RBO_P=0.9         # RBO persistence
  IMPACT_ALPHA=0.05        # Mann-Whitney significance threshold
  IMPACT_EMAIL=impact@bubbler.com
  IMPACT_USERNAME=impactuser
  IMPACT_PASSWORD=secret123
  IMPACT_SKIP_START=0      # set 1 to never spawn uvicorn (must already be up)
"""

from __future__ import annotations

import asyncio
import datetime
import itertools
import json
import math
import os
import signal
import subprocess
import sys
import time
import urllib.error
import urllib.request
from collections import Counter
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any, Callable, Literal
from urllib.parse import urlencode

import asyncpg
import numpy as np
from dotenv import load_dotenv
from scipy.spatial.distance import jensenshannon
from scipy.stats import kendalltau, mannwhitneyu

BACKEND_ROOT = Path(__file__).resolve().parent.parent / "backend"
ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(BACKEND_ROOT))
sys.path.insert(0, str(ROOT))

load_dotenv(BACKEND_ROOT / ".env")

try:
    from seed_db import SAMPLE_POSTS as SEEDED_SAMPLE_POSTS  # noqa: E402
    from seed_db import SAMPLE_TOPICS as SEEDED_SAMPLE_TOPICS  # noqa: E402
    from seed_db import ensure_schema  # noqa: E402
except Exception:  # pragma: no cover

    async def ensure_schema(pool):  # type: ignore[misc]
        return None

    SEEDED_SAMPLE_TOPICS = [
        "technology",
        "health",
        "business",
        "science",
        "politics",
        "entertainment",
        "sports",
        "education",
        "environment",
        "general",
    ]
    SEEDED_SAMPLE_POSTS = [
        ("I love building side projects.", "technology"),
        ("Morning runs clear my head.", "health"),
        ("This startup idea needs validation.", "business"),
        ("Hot take: tabs over spaces.", "technology"),
        ("CRISPR therapies keep advancing.", "science"),
        ("Local elections shape daily life.", "politics"),
        ("Indie games take creative risks.", "entertainment"),
        ("Pickup basketball is a great workout.", "sports"),
        ("Office hours are underused.", "education"),
        ("Native plant gardens beat lawns.", "environment"),
        ("A short walk resets my afternoon.", "general"),
        ("Rust makes systems programming approachable.", "technology"),
        ("Sleep consistency matters most.", "health"),
        ("Cash flow beats vanity metrics.", "business"),
        ("James Webb images still amaze me.", "science"),
    ]

from config import my_env_vars  # noqa: E402
from app.db.topics import DEFAULT_TOPIC, KNOWN_TOPICS  # noqa: E402
from app.db.vector import to_pgvector  # noqa: E402
from app.ml.embeddings.generate import embed_many  # noqa: E402
from app.repositories.edge_builder_repo import EdgeBuilderRepo  # noqa: E402

# ---------------------------------------------------------------------------
# Config
# ---------------------------------------------------------------------------

API_BASE_URL = os.getenv("API_BASE_URL", "http://127.0.0.1:8000").rstrip("/")
IMPACT_PORT = int(os.getenv("IMPACT_PORT", "8000"))
IMPACT_N = max(4, int(os.getenv("IMPACT_N", "30")))
IMPACT_K = max(3, int(os.getenv("IMPACT_K", "10")))
IMPACT_RBO_P = float(os.getenv("IMPACT_RBO_P", "0.9"))
IMPACT_ALPHA = float(os.getenv("IMPACT_ALPHA", "0.05"))
IMPACT_EMAIL = os.getenv("IMPACT_EMAIL", "impact@bubbler.com")
IMPACT_USERNAME = os.getenv("IMPACT_USERNAME", "impactuser")
IMPACT_PASSWORD = os.getenv("IMPACT_PASSWORD", "secret123")
IMPACT_SKIP_START = os.getenv("IMPACT_SKIP_START", "0") == "1"

SAMPLE_TOPICS = list(SEEDED_SAMPLE_TOPICS)
SAMPLE_POSTS = list(SEEDED_SAMPLE_POSTS)

VIEW_TIME_TOPIC = "health"
PREFERRED_TOPIC = "science"
BLACKLIST_TOPIC = "politics"
YESTERDAY_LIKE_TOPIC = "technology"

DEFAULT_STRATEGY = {
    "similar": 0.4,
    "graph": 0.25,
    "opposite": 0.2,
    "random": 0.15,
}

MetricName = Literal[
    "kendall_tau",
    "rbo",
    "jaccard",
    "topic_jsd",
    "mean_displacement",
]


# ---------------------------------------------------------------------------
# API client
# ---------------------------------------------------------------------------


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
        timeout: int = 90,
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
        except urllib.error.URLError as exc:
            return 0, None, str(exc.reason)

        try:
            parsed: Any = json.loads(raw) if raw else None
        except json.JSONDecodeError:
            parsed = raw
        return status, parsed, raw

    def reachable(self) -> bool:
        status, _, _ = self.request("GET", "/docs", timeout=3)
        return status == 200


# ---------------------------------------------------------------------------
# Backend lifecycle
# ---------------------------------------------------------------------------


@dataclass
class BackendProcess:
    proc: subprocess.Popen | None = None
    started_by_us: bool = False

    def stop(self) -> None:
        if not self.started_by_us or self.proc is None:
            return
        if self.proc.poll() is not None:
            return
        self.proc.send_signal(signal.SIGTERM)
        try:
            self.proc.wait(timeout=15)
        except subprocess.TimeoutExpired:
            self.proc.kill()
            self.proc.wait(timeout=5)
        self.proc = None


def ensure_backend(api: ApiClient) -> BackendProcess:
    handle = BackendProcess()
    if api.reachable():
        print(f"  Backend already up at {api.base_url}")
        return handle

    if IMPACT_SKIP_START:
        raise RuntimeError(
            f"Backend not reachable at {api.base_url} and IMPACT_SKIP_START=1"
        )

    print(f"  Starting uvicorn on port {IMPACT_PORT}…")
    handle.proc = subprocess.Popen(
        [
            sys.executable,
            "-m",
            "uvicorn",
            "main:app",
            "--host",
            "127.0.0.1",
            "--port",
            str(IMPACT_PORT),
            "--workers",
            "1",
        ],
        cwd=str(BACKEND_ROOT),
        stdout=subprocess.DEVNULL,
        stderr=subprocess.PIPE,
        text=True,
    )
    handle.started_by_us = True

    deadline = time.time() + 90
    while time.time() < deadline:
        if handle.proc.poll() is not None:
            err = ""
            if handle.proc.stderr:
                err = handle.proc.stderr.read()[-2000:]
            raise RuntimeError(f"uvicorn exited early (code={handle.proc.returncode}): {err}")
        if api.reachable():
            print(f"  Backend ready at {api.base_url}")
            return handle
        time.sleep(0.5)

    handle.stop()
    raise RuntimeError(f"Timed out waiting for backend at {api.base_url}")


# ---------------------------------------------------------------------------
# Feed helpers / prefs
# ---------------------------------------------------------------------------


def visible_posts(body: Any) -> list[dict[str, Any]]:
    if isinstance(body, dict):
        body = body.get("posts", [])
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
    return [str(p.get("id", "")).strip() for p in posts if str(p.get("id", "")).strip()]


def preferences_payload(**overrides: Any) -> dict[str, Any]:
    payload: dict[str, Any] = {
        "diversity_tolerance": 0.4,
        "randomness": 0.0,
        "topic_preferences": [],
        "use_view_time": False,
        "view_time_weight": 0.1,
        "use_recency": True,
        "ai_topic_detection": False,
        "strategy_weights": dict(DEFAULT_STRATEGY),
    }
    payload.update(overrides)
    return payload


def put_prefs(api: ApiClient, token: str, **overrides: Any) -> dict[str, Any]:
    status, body, raw = api.request(
        "PUT",
        "/user/me/preferences",
        json_body=preferences_payload(**overrides),
        token=token,
    )
    if status != 200:
        raise RuntimeError(f"PUT preferences failed ({status}): {raw[:300]}")
    return body if isinstance(body, dict) else {}


def fetch_feed(api: ApiClient, token: str, endpoint: str = "feed") -> list[dict[str, Any]]:
    if endpoint == "session":
        status, body, raw = api.request("GET", "/feed/me/session", token=token)
    else:
        status, body, raw = api.request("GET", "/feed/me", token=token)
    if status != 200:
        raise RuntimeError(f"GET feed failed ({status}): {raw[:300]}")
    return visible_posts(body)


def collect_feeds(
    api: ApiClient,
    token: str,
    n: int,
    *,
    endpoint: str = "feed",
) -> list[list[dict[str, Any]]]:
    feeds: list[list[dict[str, Any]]] = []
    for _ in range(n):
        feeds.append(fetch_feed(api, token, endpoint=endpoint))
    return feeds


# ---------------------------------------------------------------------------
# Metrics
# ---------------------------------------------------------------------------


def _rank_map(ids: list[str]) -> dict[str, int]:
    return {pid: i for i, pid in enumerate(ids)}


def kendall_tau_feeds(a: list[dict[str, Any]], b: list[dict[str, Any]]) -> float:
    """Kendall tau on shared ids. Returns 1.0 if too few shared for a correlation."""
    ids_a = post_ids(a)
    ids_b = post_ids(b)
    shared = [pid for pid in ids_a if pid in set(ids_b)]
    if len(shared) < 3:
        # Non-conjoint lists: treat as low agreement proportional to overlap.
        if not ids_a and not ids_b:
            return 1.0
        union = set(ids_a) | set(ids_b)
        return len(set(ids_a) & set(ids_b)) / len(union) if union else 1.0

    rank_a = _rank_map(ids_a)
    rank_b = _rank_map(ids_b)
    xa = [rank_a[pid] for pid in shared]
    xb = [rank_b[pid] for pid in shared]
    tau, _ = kendalltau(xa, xb)
    if tau is None or (isinstance(tau, float) and math.isnan(tau)):
        return 0.0
    return float(tau)


def rbo_score(
    a: list[dict[str, Any]],
    b: list[dict[str, Any]],
    *,
    p: float = IMPACT_RBO_P,
) -> float:
    """Rank-biased overlap (Webber et al.). Handles non-conjoint rankings."""
    list_a = post_ids(a)
    list_b = post_ids(b)
    if not list_a and not list_b:
        return 1.0
    if not list_a or not list_b:
        return 0.0

    depth = max(len(list_a), len(list_b))
    seen_a: set[str] = set()
    seen_b: set[str] = set()
    total = 0.0
    for d in range(1, depth + 1):
        if d <= len(list_a):
            seen_a.add(list_a[d - 1])
        if d <= len(list_b):
            seen_b.add(list_b[d - 1])
        overlap = len(seen_a & seen_b) / d
        total += (p ** (d - 1)) * overlap
    return (1.0 - p) * total


def jaccard_at_k(
    a: list[dict[str, Any]],
    b: list[dict[str, Any]],
    *,
    k: int = IMPACT_K,
) -> float:
    set_a = set(post_ids(a)[:k])
    set_b = set(post_ids(b)[:k])
    if not set_a and not set_b:
        return 1.0
    union = set_a | set_b
    return len(set_a & set_b) / len(union) if union else 1.0


def _topic_dist(posts: list[dict[str, Any]], k: int) -> dict[str, float]:
    topics = [
        str(p.get("topic") or "").strip().casefold() or "_none"
        for p in posts[:k]
    ]
    if not topics:
        return {"_empty": 1.0}
    counts = Counter(topics)
    total = sum(counts.values())
    return {t: c / total for t, c in counts.items()}


def topic_jsd(
    a: list[dict[str, Any]],
    b: list[dict[str, Any]],
    *,
    k: int = IMPACT_K,
) -> float:
    da = _topic_dist(a, k)
    db = _topic_dist(b, k)
    keys = sorted(set(da) | set(db))
    va = np.array([da.get(key, 0.0) for key in keys], dtype=float)
    vb = np.array([db.get(key, 0.0) for key in keys], dtype=float)
    # scipy returns base-2 JS distance in [0, 1] when base=2
    dist = jensenshannon(va, vb, base=2.0)
    if dist is None or (isinstance(dist, float) and math.isnan(dist)):
        return 0.0
    return float(dist)


def mean_rank_displacement(
    a: list[dict[str, Any]],
    b: list[dict[str, Any]],
) -> float:
    ids_a = post_ids(a)
    ids_b = post_ids(b)
    rank_a = _rank_map(ids_a)
    rank_b = _rank_map(ids_b)
    shared = [pid for pid in ids_a if pid in rank_b]
    if not shared:
        return float(max(len(ids_a), len(ids_b)))
    return float(np.mean([abs(rank_a[pid] - rank_b[pid]) for pid in shared]))


def topic_share(posts: list[dict[str, Any]], topic: str, *, k: int = IMPACT_K) -> float:
    top = posts[:k]
    if not top:
        return 0.0
    needle = topic.casefold()
    hits = sum(
        1
        for p in top
        if str(p.get("topic") or "").strip().casefold() == needle
    )
    return hits / len(top)


def topic_entropy(posts: list[dict[str, Any]], *, k: int = IMPACT_K) -> float:
    dist = _topic_dist(posts, k)
    return float(-sum(p * math.log2(p) for p in dist.values() if p > 0))


def blacklist_violations(feeds: list[list[dict[str, Any]]], topic: str) -> int:
    needle = topic.casefold()
    return sum(
        1
        for feed in feeds
        for post in feed
        if str(post.get("topic") or "").strip().casefold() == needle
    )


def pairwise_metric(
    feeds: list[list[dict[str, Any]]],
    metric_fn: Callable[[list[dict[str, Any]], list[dict[str, Any]]], float],
    *,
    max_pairs: int = 200,
) -> list[float]:
    if len(feeds) < 2:
        return []
    pairs = list(itertools.combinations(range(len(feeds)), 2))
    if len(pairs) > max_pairs:
        rng = np.random.default_rng(42)
        idx = rng.choice(len(pairs), size=max_pairs, replace=False)
        pairs = [pairs[i] for i in idx]
    return [metric_fn(feeds[i], feeds[j]) for i, j in pairs]


def cross_metric(
    feeds_a: list[list[dict[str, Any]]],
    feeds_b: list[list[dict[str, Any]]],
    metric_fn: Callable[[list[dict[str, Any]], list[dict[str, Any]]], float],
    *,
    max_pairs: int = 200,
) -> list[float]:
    if not feeds_a or not feeds_b:
        return []
    pairs = [(i, j) for i in range(len(feeds_a)) for j in range(len(feeds_b))]
    if len(pairs) > max_pairs:
        rng = np.random.default_rng(42)
        idx = rng.choice(len(pairs), size=max_pairs, replace=False)
        pairs = [pairs[i] for i in idx]
    return [metric_fn(feeds_a[i], feeds_b[j]) for i, j in pairs]


def interpret_tau(value: float) -> str:
    if value >= 0.85:
        return "rankings nearly identical"
    if value >= 0.5:
        return "moderate rank agreement"
    if value >= 0.2:
        return "weak agreement; substantial reordering"
    return "rankings almost fully reordered"


def interpret_rbo(value: float) -> str:
    if value >= 0.85:
        return "top of feed barely changed"
    if value >= 0.5:
        return "noticeable top-k churn"
    if value >= 0.25:
        return "top of feed largely different"
    return "top of feed almost completely different"


def interpret_jaccard(value: float) -> str:
    changed_pct = int(round((1.0 - value) * 100))
    return f"~{changed_pct}% of top-{IMPACT_K} posts changed"


def interpret_jsd(value: float) -> str:
    if value < 0.05:
        return "topic mix unchanged"
    if value < 0.15:
        return "small topic-mix shift"
    if value < 0.35:
        return "topic mix shifted substantially"
    return "topic mix transformed"


def interpret_displacement(value: float) -> str:
    return f"shared posts move ~{value:.1f} ranks on average"


METRIC_FNS: dict[MetricName, Callable[[list[dict[str, Any]], list[dict[str, Any]]], float]] = {
    "kendall_tau": kendall_tau_feeds,
    "rbo": rbo_score,
    "jaccard": jaccard_at_k,
    "topic_jsd": topic_jsd,
    "mean_displacement": mean_rank_displacement,
}

# For agreement metrics, impact means A/B < A/A (values drop).
# For distance metrics, impact means A/B > A/A (values rise).
METRIC_HIGHER_IS_DISTANCE: dict[MetricName, bool] = {
    "kendall_tau": False,
    "rbo": False,
    "jaccard": False,
    "topic_jsd": True,
    "mean_displacement": True,
}

# Practical significance gates — avoid declaring impact when A/A is degenerate
# (near-zero variance) and A/B only jitters by sampling noise.
MIN_EFFECT: dict[MetricName, float] = {
    "kendall_tau": 0.08,
    "rbo": 0.08,
    "jaccard": 0.08,
    "topic_jsd": 0.08,
    "mean_displacement": 1.0,
}

INTERPRETERS: dict[MetricName, Callable[[float], str]] = {
    "kendall_tau": interpret_tau,
    "rbo": interpret_rbo,
    "jaccard": interpret_jaccard,
    "topic_jsd": interpret_jsd,
    "mean_displacement": interpret_displacement,
}


# ---------------------------------------------------------------------------
# Statistical comparison
# ---------------------------------------------------------------------------


@dataclass
class MetricResult:
    name: MetricName
    aa_mean: float
    aa_std: float
    ab_mean: float
    ab_std: float
    p_value: float
    direction_ok: bool
    significant: bool
    effect_size: float
    effect_ok: bool

    @property
    def impacted(self) -> bool:
        return self.significant and self.direction_ok and self.effect_ok


@dataclass
class KnobResult:
    knob: str
    endpoint: str
    n: int
    expect_impact: bool
    metrics: list[MetricResult] = field(default_factory=list)
    notes: str = ""
    hard_pass: bool | None = None  # for blacklist / special asserts
    extra: dict[str, Any] = field(default_factory=dict)

    @property
    def primary(self) -> MetricResult | None:
        if not self.metrics:
            return None
        # Prefer topic_jsd for composition knobs, tau otherwise.
        preferred = ("topic_jsd", "kendall_tau", "jaccard", "rbo", "mean_displacement")
        by_name = {m.name: m for m in self.metrics}
        for name in preferred:
            if name in by_name:
                return by_name[name]
        return self.metrics[0]

    @property
    def has_impact(self) -> bool:
        if self.hard_pass is not None:
            return self.hard_pass
        impacted = [m for m in self.metrics if m.impacted]
        if not impacted:
            return False
        # Negative controls: require a clear majority so one flaky metric
        # (e.g. tiny RBO jitter with zero-variance A/A) cannot fail the run.
        if not self.expect_impact:
            return len(impacted) >= max(2, (len(self.metrics) + 1) // 2)
        # Positive knobs: any practically-significant metric counts.
        return True

    @property
    def verdict(self) -> str:
        impacted = self.has_impact
        if self.expect_impact:
            return "PASS" if impacted else "FAIL"
        return "PASS" if not impacted else "FAIL"

    @property
    def interpretation(self) -> str:
        if self.notes:
            base = self.notes
        else:
            primary = self.primary
            if primary is None:
                base = "no metrics collected"
            else:
                base = (
                    f"{primary.name} A/B={primary.ab_mean:.3f} "
                    f"(floor={primary.aa_mean:.3f}) — "
                    f"{INTERPRETERS[primary.name](primary.ab_mean)}"
                )
        if self.expect_impact:
            return base + (" | impact detected" if self.has_impact else " | no impact beyond noise")
        return base + (" | correctly inert" if not self.has_impact else " | unexpected impact")


def _mean_std(values: list[float]) -> tuple[float, float]:
    if not values:
        return float("nan"), float("nan")
    arr = np.asarray(values, dtype=float)
    return float(arr.mean()), float(arr.std(ddof=1) if len(arr) > 1 else 0.0)


def compare_distributions(
    aa: list[float],
    ab: list[float],
    *,
    name: MetricName,
    alpha: float = IMPACT_ALPHA,
) -> MetricResult:
    aa_mean, aa_std = _mean_std(aa)
    ab_mean, ab_std = _mean_std(ab)
    higher_is_distance = METRIC_HIGHER_IS_DISTANCE[name]
    min_effect = MIN_EFFECT[name]

    if len(aa) < 2 or len(ab) < 2:
        return MetricResult(
            name=name,
            aa_mean=aa_mean,
            aa_std=aa_std,
            ab_mean=ab_mean,
            ab_std=ab_std,
            p_value=1.0,
            direction_ok=False,
            significant=False,
            effect_size=0.0,
            effect_ok=False,
        )

    # H1: AB is shifted away from AA in the expected direction.
    alternative = "greater" if higher_is_distance else "less"
    try:
        stat = mannwhitneyu(ab, aa, alternative=alternative)
        p_value = float(stat.pvalue)
    except ValueError:
        p_value = 1.0

    if higher_is_distance:
        direction_ok = ab_mean > aa_mean
        effect_size = ab_mean - aa_mean
    else:
        direction_ok = ab_mean < aa_mean
        effect_size = aa_mean - ab_mean

    effect_ok = effect_size >= min_effect

    return MetricResult(
        name=name,
        aa_mean=aa_mean,
        aa_std=aa_std,
        ab_mean=ab_mean,
        ab_std=ab_std,
        p_value=p_value,
        direction_ok=direction_ok,
        significant=p_value < alpha,
        effect_size=effect_size,
        effect_ok=effect_ok,
    )


def evaluate_ab(
    feeds_a: list[list[dict[str, Any]]],
    feeds_b: list[list[dict[str, Any]]],
    *,
    metrics: list[MetricName] | None = None,
) -> list[MetricResult]:
    metrics = metrics or ["kendall_tau", "rbo", "jaccard", "topic_jsd", "mean_displacement"]
    results: list[MetricResult] = []
    for name in metrics:
        fn = METRIC_FNS[name]
        aa = pairwise_metric(feeds_a, fn)
        ab = cross_metric(feeds_a, feeds_b, fn)
        results.append(compare_distributions(aa, ab, name=name))
    return results


# ---------------------------------------------------------------------------
# Seeding
# ---------------------------------------------------------------------------


async def seed_topic_embeddings(conn: asyncpg.Connection, topic_names: set[str]) -> None:
    names = sorted(topic_names)
    vectors = embed_many(names)
    for name, topic_vector in zip(names, vectors):
        await conn.execute(
            """
            INSERT INTO topics (name, embedding)
            VALUES ($1, $2::vector)
            ON CONFLICT (name) DO UPDATE
            SET embedding = COALESCE(topics.embedding, EXCLUDED.embedding)
            """,
            name,
            to_pgvector(topic_vector),
        )


async def reset_impact_user(pool: asyncpg.Pool) -> None:
    async with pool.acquire() as conn:
        await conn.execute("DELETE FROM users WHERE email = $1", IMPACT_EMAIL)


async def register_and_login(api: ApiClient, pool: asyncpg.Pool) -> tuple[str, int]:
    await reset_impact_user(pool)

    status, body, raw = api.request(
        "POST",
        "/auth/register",
        json_body={
            "username": IMPACT_USERNAME,
            "email": IMPACT_EMAIL,
            "password": IMPACT_PASSWORD,
        },
    )
    if status == 409:
        status, body, raw = api.request(
            "POST",
            "/auth/login",
            form={"username": IMPACT_EMAIL, "password": IMPACT_PASSWORD},
        )
    if status != 200 or not isinstance(body, dict) or "access_token" not in body:
        raise RuntimeError(f"Auth failed ({status}): {raw[:300]}")

    token = str(body["access_token"])
    user_id = body.get("user_id")
    if user_id is None:
        status, me, raw = api.request("GET", "/user/me", token=token)
        if status != 200 or not isinstance(me, dict):
            raise RuntimeError(f"Could not resolve user_id: {raw[:200]}")
        user_id = me.get("id")
    if user_id is None:
        # Fall back to DB lookup by email.
        async with pool.acquire() as conn:
            user_id = await conn.fetchval(
                "SELECT id FROM users WHERE email = $1", IMPACT_EMAIL
            )
    if user_id is None:
        raise RuntimeError("Auth succeeded but user_id missing")
    return token, int(user_id)


async def seed_impact_corpus(pool: asyncpg.Pool, user_id: int) -> dict[str, Any]:
    """Seed posts with staggered created_at, yesterday like, and view-time signals."""
    edge_builder = EdgeBuilderRepo(pool)
    meta: dict[str, Any] = {
        "post_count": 0,
        "yesterday_like_post_id": None,
        "view_time_topic": VIEW_TIME_TOPIC,
        "view_time_post_ids": [],
    }
    now = datetime.datetime.now(datetime.timezone.utc).replace(tzinfo=None)
    post_contents = [content for content, _ in SAMPLE_POSTS]
    post_vectors = embed_many(post_contents)
    inserted: list[tuple[str, str, list[float]]] = []

    async with pool.acquire() as conn:
        await seed_topic_embeddings(
            conn,
            {*SAMPLE_TOPICS, DEFAULT_TOPIC, *KNOWN_TOPICS},
        )

        for index, ((content, topic_name), vector) in enumerate(
            zip(SAMPLE_POSTS, post_vectors)
        ):
            # Spread created_at so use_recency is observable.
            created_at = now - datetime.timedelta(hours=6 * index)
            post_id = await conn.fetchval(
                """
                INSERT INTO posts (user_id, content, embedding, created_at)
                VALUES ($1, $2, $3::vector, $4)
                RETURNING id
                """,
                user_id,
                content,
                to_pgvector(vector),
                created_at,
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
            inserted.append((str(post_id), topic_name, vector))

        meta["post_count"] = len(inserted)

        yesterday_mid = (now - datetime.timedelta(days=1)).replace(
            hour=12, minute=0, second=0, microsecond=0
        )
        like_candidates = [p for p in inserted if p[1] == YESTERDAY_LIKE_TOPIC]
        if not like_candidates:
            like_candidates = inserted[:1]
        like_post_id = like_candidates[0][0]
        await conn.execute(
            """
            DELETE FROM interactions
            WHERE user_id = $1 AND post_id = $2::uuid AND type = 'like'
            """,
            user_id,
            like_post_id,
        )
        await conn.execute(
            """
            INSERT INTO interactions (user_id, post_id, type, view_time, created_at)
            VALUES ($1, $2::uuid, 'like', 0, $3)
            """,
            user_id,
            like_post_id,
            yesterday_mid,
        )
        meta["yesterday_like_post_id"] = like_post_id

        view_posts = [p for p in inserted if p[1] == VIEW_TIME_TOPIC][:5]
        for post_id, _, _ in view_posts:
            await conn.execute(
                """
                INSERT INTO interactions (user_id, post_id, type, view_time, created_at)
                VALUES ($1, $2::uuid, 'explore', $3, $4)
                """,
                user_id,
                post_id,
                120.0,
                now - datetime.timedelta(hours=1),
            )
            meta["view_time_post_ids"].append(post_id)

    for post_id, _, vector in inserted:
        await edge_builder.build_edges_for_post(post_id, vector)

    return meta


# ---------------------------------------------------------------------------
# Preference test cases
# ---------------------------------------------------------------------------


def _print_knob_header(name: str) -> None:
    print(f"\n--- {name} ---")


def run_ab_knob(
    *,
    api: ApiClient,
    token: str,
    knob: str,
    endpoint: str,
    baseline: dict[str, Any],
    variant: dict[str, Any],
    expect_impact: bool,
    notes: str = "",
    metrics: list[MetricName] | None = None,
    n: int = IMPACT_N,
) -> KnobResult:
    """endpoint is 'feed' or 'session' (collector key); displayed as API path."""
    _print_knob_header(knob)
    put_prefs(api, token, **baseline)
    feeds_a = collect_feeds(api, token, n, endpoint=endpoint)
    put_prefs(api, token, **variant)
    feeds_b = collect_feeds(api, token, n, endpoint=endpoint)
    # Restore deterministic baseline so later knobs aren't polluted.
    put_prefs(api, token, **baseline)

    results = evaluate_ab(feeds_a, feeds_b, metrics=metrics)
    for m in results:
        print(
            f"  {m.name:18} A/A={m.aa_mean:.3f}±{m.aa_std:.3f}  "
            f"A/B={m.ab_mean:.3f}±{m.ab_std:.3f}  "
            f"p={m.p_value:.4g}  "
            f"{'impact' if m.impacted else 'noise'}"
        )

    endpoint_label = "/feed/me/session" if endpoint == "session" else "/feed/me"
    return KnobResult(
        knob=knob,
        endpoint=endpoint_label,
        n=n,
        expect_impact=expect_impact,
        metrics=results,
        notes=notes,
    )


def test_randomness(api: ApiClient, token: str) -> KnobResult:
    """Sweep randomness; expect mean pairwise tau to drop as randomness rises."""
    _print_knob_header("randomness (sweep)")
    levels = [0.0, 0.25, 0.5, 0.75, 1.0]
    tau_by_level: dict[float, float] = {}
    samples_low: list[float] = []
    samples_high: list[float] = []

    for level in levels:
        put_prefs(api, token, randomness=level, use_recency=False)
        feeds = collect_feeds(api, token, IMPACT_N, endpoint="feed")
        taus = pairwise_metric(feeds, kendall_tau_feeds)
        mean_tau, std_tau = _mean_std(taus)
        tau_by_level[level] = mean_tau
        print(f"  randomness={level:.2f}  mean pairwise tau={mean_tau:.3f}±{std_tau:.3f}")
        if level == 0.0:
            samples_low = taus
        if level == 1.0:
            samples_high = taus

    put_prefs(api, token, randomness=0.0, use_recency=True)

    comparison = compare_distributions(
        samples_low,
        samples_high,
        name="kendall_tau",
    )
    # For this special case, AA = low-randomness pairwise, AB = high-randomness pairwise.
    # Impact = high-randomness tau significantly lower than low-randomness tau.
    monotone = tau_by_level[1.0] < tau_by_level[0.0]
    # Soft check that the sweep is generally decreasing
    soft_monotone = all(
        tau_by_level[levels[i]] + 0.05 >= tau_by_level[levels[i + 1]]
        for i in range(len(levels) - 1)
    )
    notes = (
        f"tau@0={tau_by_level[0.0]:.3f} → tau@1={tau_by_level[1.0]:.3f}; "
        f"{'mostly monotone' if soft_monotone else 'non-monotone'}; "
        f"{interpret_tau(tau_by_level[1.0])}"
    )
    result = KnobResult(
        knob="randomness",
        endpoint="/feed/me",
        n=IMPACT_N,
        expect_impact=True,
        metrics=[comparison],
        notes=notes,
        hard_pass=comparison.impacted and monotone,
        extra={"tau_by_level": tau_by_level},
    )
    print(f"  verdict prep: monotone={monotone} soft={soft_monotone} p={comparison.p_value:.4g}")
    return result


def test_blacklist(api: ApiClient, token: str) -> KnobResult:
    _print_knob_header("blacklisted topics")
    baseline = dict(
        randomness=0.0,
        topic_preferences=[],
        strategy_weights={"similar": 0.5, "graph": 0.2, "opposite": 0.2, "random": 0.1},
    )
    put_prefs(api, token, **baseline)
    feeds_a = collect_feeds(api, token, IMPACT_N, endpoint="feed")

    variant = dict(
        randomness=0.0,
        topic_preferences=[
            {"topic": BLACKLIST_TOPIC, "preference_type": "blacklisted"},
        ],
        strategy_weights={"similar": 0.5, "graph": 0.2, "opposite": 0.2, "random": 0.1},
    )
    put_prefs(api, token, **variant)
    feeds_b_feed = collect_feeds(api, token, IMPACT_N, endpoint="feed")
    feeds_b_session = collect_feeds(api, token, IMPACT_N, endpoint="session")

    violations_feed = blacklist_violations(feeds_b_feed, BLACKLIST_TOPIC)
    violations_session = blacklist_violations(feeds_b_session, BLACKLIST_TOPIC)
    present_before = blacklist_violations(feeds_a, BLACKLIST_TOPIC)

    metrics = evaluate_ab(feeds_a, feeds_b_feed, metrics=["topic_jsd", "jaccard", "kendall_tau"])
    hard = violations_feed == 0 and violations_session == 0
    notes = (
        f"blacklist '{BLACKLIST_TOPIC}': before={present_before} hits, "
        f"feed violations={violations_feed}, session violations={violations_session}"
    )
    for m in metrics:
        print(
            f"  {m.name:18} A/A={m.aa_mean:.3f}±{m.aa_std:.3f}  "
            f"A/B={m.ab_mean:.3f}±{m.ab_std:.3f}  p={m.p_value:.4g}"
        )
    print(f"  hard filter: {notes}")

    put_prefs(api, token, **baseline)
    return KnobResult(
        knob="blacklisted_topics",
        endpoint="/feed/me + /feed/me/session",
        n=IMPACT_N,
        expect_impact=True,
        metrics=metrics,
        notes=notes,
        hard_pass=hard,
    )


def test_preferred(api: ApiClient, token: str) -> KnobResult:
    _print_knob_header("preferred topics")
    baseline = dict(randomness=0.0, topic_preferences=[], use_recency=False)
    put_prefs(api, token, **baseline)
    feeds_a = collect_feeds(api, token, IMPACT_N, endpoint="feed")
    share_a = float(np.mean([topic_share(f, PREFERRED_TOPIC) for f in feeds_a]))

    variant = dict(
        randomness=0.0,
        use_recency=False,
        topic_preferences=[
            {"topic": PREFERRED_TOPIC, "preference_type": "preferred"},
        ],
    )
    put_prefs(api, token, **variant)
    feeds_b = collect_feeds(api, token, IMPACT_N, endpoint="feed")
    share_b = float(np.mean([topic_share(f, PREFERRED_TOPIC) for f in feeds_b]))

    metrics = evaluate_ab(feeds_a, feeds_b)
    share_rise = share_b > share_a + 0.02
    # Prefer topic share rise OR ranking metrics showing impact
    hard = share_rise or any(m.impacted for m in metrics)
    notes = (
        f"preferred '{PREFERRED_TOPIC}' share@k: {share_a:.2f} → {share_b:.2f}; "
        f"{interpret_jsd(next((m.ab_mean for m in metrics if m.name == 'topic_jsd'), 0.0))}"
    )
    for m in metrics:
        print(
            f"  {m.name:18} A/A={m.aa_mean:.3f}±{m.aa_std:.3f}  "
            f"A/B={m.ab_mean:.3f}±{m.ab_std:.3f}  p={m.p_value:.4g}"
        )
    print(f"  topic share rise: {share_rise}")

    put_prefs(api, token, **baseline)
    return KnobResult(
        knob="preferred_topics",
        endpoint="/feed/me",
        n=IMPACT_N,
        expect_impact=True,
        metrics=metrics,
        notes=notes,
        hard_pass=hard,
        extra={"share_a": share_a, "share_b": share_b},
    )


def test_diversity(api: ApiClient, token: str) -> KnobResult:
    _print_knob_header("diversity_tolerance (session)")
    baseline = dict(diversity_tolerance=0.0, randomness=0.0, topic_preferences=[])
    put_prefs(api, token, **baseline)
    feeds_a = collect_feeds(api, token, IMPACT_N, endpoint="session")
    ent_a = float(np.mean([topic_entropy(f) for f in feeds_a]))

    variant = dict(diversity_tolerance=1.0, randomness=0.0, topic_preferences=[])
    put_prefs(api, token, **variant)
    feeds_b = collect_feeds(api, token, IMPACT_N, endpoint="session")
    ent_b = float(np.mean([topic_entropy(f) for f in feeds_b]))

    metrics = evaluate_ab(
        feeds_a,
        feeds_b,
        metrics=["topic_jsd", "jaccard", "kendall_tau", "rbo"],
    )
    notes = (
        f"session topic entropy: {ent_a:.3f} → {ent_b:.3f}; "
        f"{interpret_jsd(next((m.ab_mean for m in metrics if m.name == 'topic_jsd'), 0.0))}"
    )
    for m in metrics:
        print(
            f"  {m.name:18} A/A={m.aa_mean:.3f}±{m.aa_std:.3f}  "
            f"A/B={m.ab_mean:.3f}±{m.ab_std:.3f}  p={m.p_value:.4g}"
        )
    print(f"  entropy delta={ent_b - ent_a:+.3f}")

    put_prefs(api, token, **baseline)
    return KnobResult(
        knob="diversity_tolerance",
        endpoint="/feed/me/session",
        n=IMPACT_N,
        expect_impact=True,
        metrics=metrics,
        notes=notes,
        extra={"entropy_a": ent_a, "entropy_b": ent_b},
    )


def test_view_time(api: ApiClient, token: str) -> KnobResult:
    """use_view_time applies a score boost to topics with high view_time."""
    _print_knob_header("use_view_time / view_time_weight")
    baseline = dict(
        randomness=0.0,
        use_view_time=False,
        view_time_weight=0.1,
        topic_preferences=[],
        use_recency=False,
    )
    put_prefs(api, token, **baseline)
    feeds_a = collect_feeds(api, token, IMPACT_N, endpoint="feed")
    share_a = float(np.mean([topic_share(f, VIEW_TIME_TOPIC) for f in feeds_a]))

    variant = dict(
        randomness=0.0,
        use_view_time=True,
        view_time_weight=1.0,
        topic_preferences=[],
        use_recency=False,
    )
    put_prefs(api, token, **variant)
    feeds_b = collect_feeds(api, token, IMPACT_N, endpoint="feed")
    share_b = float(np.mean([topic_share(f, VIEW_TIME_TOPIC) for f in feeds_b]))

    metrics = evaluate_ab(feeds_a, feeds_b)
    share_rise = share_b > share_a + 0.02
    hard = share_rise or any(m.impacted for m in metrics)
    notes = (
        f"view-time topic '{VIEW_TIME_TOPIC}' share@k: {share_a:.2f} → {share_b:.2f}"
    )
    for m in metrics:
        print(
            f"  {m.name:18} A/A={m.aa_mean:.3f}±{m.aa_std:.3f}  "
            f"A/B={m.ab_mean:.3f}±{m.ab_std:.3f}  p={m.p_value:.4g}"
        )
    print(f"  share rise: {share_rise}")

    put_prefs(api, token, **baseline)
    return KnobResult(
        knob="use_view_time",
        endpoint="/feed/me",
        n=IMPACT_N,
        expect_impact=True,
        metrics=metrics,
        notes=notes,
        hard_pass=hard,
        extra={"share_a": share_a, "share_b": share_b},
    )


def run_all_knobs(api: ApiClient, token: str) -> list[KnobResult]:
    results: list[KnobResult] = []

    # Stable baseline between tests
    put_prefs(api, token, randomness=0.0, use_recency=True, topic_preferences=[])

    results.append(test_randomness(api, token))

    results.append(
        run_ab_knob(
            api=api,
            token=token,
            knob="use_recency",
            endpoint="feed",
            baseline=dict(randomness=0.0, use_recency=False, topic_preferences=[]),
            variant=dict(randomness=0.0, use_recency=True, topic_preferences=[]),
            expect_impact=True,
            notes="recency boost on vs off",
        )
    )

    results.append(
        run_ab_knob(
            api=api,
            token=token,
            knob="strategy_weights (similar→opposite)",
            endpoint="feed",
            baseline=dict(
                randomness=0.0,
                use_recency=False,
                topic_preferences=[],
                strategy_weights={
                    "similar": 1.0,
                    "graph": 0.0,
                    "opposite": 0.0,
                    "random": 0.0,
                },
            ),
            variant=dict(
                randomness=0.0,
                use_recency=False,
                topic_preferences=[],
                strategy_weights={
                    "similar": 0.0,
                    "graph": 0.0,
                    "opposite": 1.0,
                    "random": 0.0,
                },
            ),
            expect_impact=True,
            notes="pure similar vs pure opposite candidate mix",
        )
    )

    results.append(
        run_ab_knob(
            api=api,
            token=token,
            knob="strategy_weights (similar→random)",
            endpoint="feed",
            baseline=dict(
                randomness=0.0,
                use_recency=False,
                topic_preferences=[],
                strategy_weights={
                    "similar": 1.0,
                    "graph": 0.0,
                    "opposite": 0.0,
                    "random": 0.0,
                },
            ),
            variant=dict(
                randomness=0.0,
                use_recency=False,
                topic_preferences=[],
                strategy_weights={
                    "similar": 0.0,
                    "graph": 0.0,
                    "opposite": 0.0,
                    "random": 1.0,
                },
            ),
            expect_impact=True,
            notes="pure similar vs pure random candidate mix",
        )
    )

    results.append(test_preferred(api, token))
    results.append(test_blacklist(api, token))
    results.append(test_diversity(api, token))
    results.append(test_view_time(api, token))

    results.append(
        run_ab_knob(
            api=api,
            token=token,
            knob="ai_topic_detection (negative control)",
            endpoint="feed",
            baseline=dict(
                randomness=0.0,
                ai_topic_detection=False,
                topic_preferences=[],
                use_recency=False,
            ),
            variant=dict(
                randomness=0.0,
                ai_topic_detection=True,
                topic_preferences=[],
                use_recency=False,
            ),
            expect_impact=False,
            notes="inert flag — must stay within noise floor",
        )
    )

    return results


# ---------------------------------------------------------------------------
# Reporting
# ---------------------------------------------------------------------------


def print_metrics_glossary() -> None:
    print(
        """
Metric glossary
  kendall_tau       Rank agreement on shared posts (1=same order, 0=unrelated, -1=reversed)
  rbo               Top-weighted overlap (1=same top, 0=disjoint); persistence p={p}
  jaccard@k         |top-{k} ∩ top-{k}| / |union| — fraction of top posts shared
  topic_jsd         Jensen-Shannon divergence of top-{k} topic mix (0=identical, 1=disjoint)
  mean_displacement Average |rank_A - rank_B| for shared posts

Decision rule
  Collect N={n} feeds under baseline (A) and variant (B).
  Noise floor = pairwise metric among A feeds (A/A).
  Effect      = cross metric between A and B feeds (A/B).
  Impact if Mann-Whitney p < {alpha} AND direction matches
  (agreement metrics drop; distance metrics rise) AND effect
  size clears a practical minimum (guards against zero-variance A/A).
  Negative controls must NOT show a majority of metrics impacted.
""".format(
            p=IMPACT_RBO_P, k=IMPACT_K, n=IMPACT_N, alpha=IMPACT_ALPHA
        )
    )


def print_results_table(results: list[KnobResult]) -> None:
    print("\n" + "=" * 100)
    print("PREFERENCE IMPACT RESULTS")
    print("=" * 100)
    header = (
        f"{'KNOB':<40} {'ENDPT':<22} {'N':>3} "
        f"{'PRIMARY A/B':>12} {'FLOOR A/A':>10} {'p':>9} {'VERDICT':>8}"
    )
    print(header)
    print("-" * 100)

    for r in results:
        primary = r.primary
        if primary:
            ab = f"{primary.ab_mean:.3f}"
            aa = f"{primary.aa_mean:.3f}"
            p = f"{primary.p_value:.3g}"
            metric_tag = primary.name
        else:
            ab, aa, p, metric_tag = "n/a", "n/a", "n/a", "-"

        endpt = r.endpoint
        if len(endpt) > 22:
            endpt = endpt[:19] + "..."
        print(
            f"{r.knob:<40} {endpt:<22} {r.n:>3} "
            f"{ab:>12} {aa:>10} {p:>9} {r.verdict:>8}"
        )
        print(f"  [{metric_tag}] {r.interpretation}")

    print("-" * 100)
    passed = sum(1 for r in results if r.verdict == "PASS")
    failed = sum(1 for r in results if r.verdict == "FAIL")
    print(f"SUMMARY: {passed} PASS, {failed} FAIL (of {len(results)} knobs)")
    if failed:
        print("Failed knobs:")
        for r in results:
            if r.verdict == "FAIL":
                expected = "impact" if r.expect_impact else "no impact"
                print(f"  - {r.knob}: expected {expected}; {r.interpretation}")
    print("=" * 100)


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------


async def async_main() -> int:
    print("Bubbler preference-impact harness")
    print(f"  API:  {API_BASE_URL}")
    print(f"  DB:   {my_env_vars.host}:{my_env_vars.port}/{my_env_vars.database}")
    print(f"  User: {IMPACT_EMAIL}")
    print(f"  N={IMPACT_N}  k={IMPACT_K}  alpha={IMPACT_ALPHA}  rbo_p={IMPACT_RBO_P}")
    print_metrics_glossary()

    api = ApiClient(API_BASE_URL)
    backend = BackendProcess()
    pool: asyncpg.Pool | None = None

    try:
        print("\n=== Backend ===")
        backend = ensure_backend(api)

        print("\n=== Schema + seed ===")
        pool = await asyncpg.create_pool(my_env_vars.db_url, min_size=1, max_size=5)
        await ensure_schema(pool)
        print("  Schema aligned")

        token, user_id = await register_and_login(api, pool)
        print(f"  Registered/login user_id={user_id}")

        meta = await seed_impact_corpus(pool, user_id)
        print(
            f"  Seeded {meta['post_count']} posts; "
            f"yesterday_like={meta['yesterday_like_post_id']}; "
            f"view_time_posts={len(meta['view_time_post_ids'])} ({meta['view_time_topic']})"
        )

        # Warm prefs
        put_prefs(api, token, randomness=0.0)
        print("  Baseline preferences saved")

        print("\n=== Preference trials ===")
        results = run_all_knobs(api, token)
        print_results_table(results)

        failed = [r for r in results if r.verdict == "FAIL"]
        return 1 if failed else 0
    finally:
        if pool is not None:
            await pool.close()
        backend.stop()
        if backend.started_by_us:
            print("\n  Stopped backend process we started.")


def main() -> int:
    try:
        return asyncio.run(async_main())
    except KeyboardInterrupt:
        print("\nInterrupted.")
        return 130
    except Exception as exc:
        print(f"\nFATAL: {exc}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
