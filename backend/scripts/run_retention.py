#!/usr/bin/env python3
"""Run scheduled data retention purges against Postgres.

Usage (from backend/):
  pipenv run python scripts/run_retention.py
  pipenv run python scripts/run_retention.py --dry-run

Schedule nightly via host cron, Supabase pg_cron, or CI. See docs/retention.md.
"""

from __future__ import annotations

import argparse
import asyncio
import logging
import sys
from pathlib import Path

import asyncpg

BACKEND_ROOT = Path(__file__).resolve().parent.parent
if str(BACKEND_ROOT) not in sys.path:
    sys.path.insert(0, str(BACKEND_ROOT))

from app.repositories.retention_repo import RetentionRepository
from app.services.retention import RetentionService
from config import my_env_vars


def _parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Run Bubbler data retention purges.")
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Count eligible rows without deleting or updating.",
    )
    parser.add_argument(
        "--batch-size",
        type=int,
        default=5000,
        help="Max rows per batched delete/update (default: 5000).",
    )
    return parser.parse_args()


async def _main(*, dry_run: bool, batch_size: int) -> int:
    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s - %(levelname)s - %(message)s",
    )

    pool = await asyncpg.create_pool(my_env_vars.db_url, min_size=1, max_size=2)
    try:
        repo = RetentionRepository(
            pool,
            my_env_vars.retention,
            batch_size=batch_size,
        )
        service = RetentionService(repo)
        stats = await service.run(dry_run=dry_run)
    finally:
        await pool.close()

    for key, count in stats.items():
        print(f"{key}: {count}")
    return 0


def main() -> int:
    args = _parse_args()
    if args.batch_size < 1:
        print("batch-size must be >= 1", file=sys.stderr)
        return 1
    return asyncio.run(_main(dry_run=args.dry_run, batch_size=args.batch_size))


if __name__ == "__main__":
    raise SystemExit(main())
