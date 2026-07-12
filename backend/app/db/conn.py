"""Shared connection helpers for repositories."""

from collections.abc import AsyncIterator
from contextlib import asynccontextmanager
from typing import Any


@asynccontextmanager
async def acquire_conn(pool, conn=None) -> AsyncIterator[Any]:
    """Yield ``conn`` when provided; otherwise acquire from ``pool``."""
    if conn is not None:
        yield conn
        return
    async with pool.acquire() as acquired:
        yield acquired
