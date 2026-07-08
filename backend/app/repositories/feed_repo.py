from contextlib import asynccontextmanager
from typing import Any, List

from app.db.feed_sql import (
    POSTS_BASE_FROM,
    POSTS_TABLESAMPLE_FROM,
    POSTS_WITH_TOPIC_COLUMNS,
)
from app.db.vector import to_pgvector

# TABLESAMPLE percentage — tunable; avoids full-table ORDER BY RANDOM()
_RANDOM_SAMPLE_PERCENT = 25


class FeedRepository:
    def __init__(self, pool):
        self.pool = pool

    @asynccontextmanager
    async def acquire(self):
        async with self.pool.acquire() as conn:
            yield conn

    def _map_post_row(self, row: Any) -> dict[str, Any]:
        return {
            "id": str(row["id"]),
            "content": row["content"],
            "topic": row["topic"],
            "created_at": row["created_at"],
            "user_id": row["user_id"],
        }

    def _map_similarity_row(self, row: Any) -> dict[str, Any]:
        return {
            "id": str(row["id"]),
            "content": row["content"],
            "topic": row["topic"],
            "similarity": float(row["similarity"]),
        }

    async def _fetch_posts_by_embedding(
        self,
        conn,
        embedded_post: List[float],
        limit: int,
        *,
        ascending: bool = True,
    ) -> list[dict[str, Any]]:
        order = "ASC" if ascending else "DESC"
        rows = await conn.fetch(
            f"""
            SELECT pwt.id, pwt.content, pwt.topic,
                   1 - (pwt.embedding <=> $1::vector) AS similarity
            {POSTS_BASE_FROM}
            WHERE pwt.embedding IS NOT NULL
            ORDER BY pwt.embedding <=> $1::vector {order}
            LIMIT $2
            """,
            to_pgvector(embedded_post),
            limit,
        )
        return [self._map_similarity_row(r) for r in rows]

    async def _fetch_random_posts(self, conn, limit: int) -> list[dict[str, Any]]:
        rows = await conn.fetch(
            f"""
            SELECT {POSTS_WITH_TOPIC_COLUMNS}
            {POSTS_TABLESAMPLE_FROM.format(sample_percent=_RANDOM_SAMPLE_PERCENT)}
            WHERE p.embedding IS NOT NULL
            LIMIT $1
            """,
            limit,
        )
        if len(rows) < limit:
            rows = await conn.fetch(
                f"""
                SELECT {POSTS_WITH_TOPIC_COLUMNS}
                {POSTS_TABLESAMPLE_FROM.format(sample_percent=100)}
                WHERE p.embedding IS NOT NULL
                LIMIT $1
                """,
                limit,
            )
        return [self._map_post_row(r) for r in rows]

    # --- Graph ---
    async def get_neighbors_batch(
        self,
        ids: list[str],
        limit: int = 4,
        *,
        conn=None,
    ) -> dict[str, list[dict[str, Any]]]:
        if not ids:
            return {}

        query = """
            SELECT from_post_id::text, to_post_id::text AS to_post_id, weight
            FROM (
                SELECT
                    from_post_id,
                    to_post_id,
                    MAX(weight) AS weight,
                    ROW_NUMBER() OVER (
                        PARTITION BY from_post_id
                        ORDER BY MAX(weight) DESC
                    ) AS rn
                FROM edges
                WHERE from_post_id = ANY($1::uuid[])
                GROUP BY from_post_id, to_post_id
            ) ranked
            WHERE rn <= $2
        """

        async def _run(connection):
            rows = await connection.fetch(query, ids, limit)
            result: dict[str, list[dict[str, Any]]] = {}
            for row in rows:
                key = row["from_post_id"]
                result.setdefault(key, []).append(
                    {"to_post_id": row["to_post_id"], "weight": row["weight"]}
                )
            return result

        if conn is not None:
            return await _run(conn)
        async with self.pool.acquire() as conn:
            return await _run(conn)

    async def get_neighbors(self, id: str, limit: int = 4, *, conn=None) -> list[dict[str, Any]]:
        batch = await self.get_neighbors_batch([id], limit=limit, conn=conn)
        return batch.get(str(id), [])

    # --- Feed ---
    async def get_similar_posts(
        self, embedded_post: List[float], limit: int = 4, *, conn=None
    ) -> list[dict[str, Any]]:
        async def _run(connection):
            return await self._fetch_posts_by_embedding(
                connection, embedded_post, limit, ascending=True
            )

        if conn is not None:
            return await _run(conn)
        async with self.pool.acquire() as conn:
            return await _run(conn)

    async def get_opposite_posts(
        self, embedding: List[float], limit: int = 10, *, conn=None
    ) -> list[dict[str, Any]]:
        async def _run(connection):
            return await self._fetch_posts_by_embedding(
                connection, embedding, limit, ascending=False
            )

        if conn is not None:
            return await _run(conn)
        async with self.pool.acquire() as conn:
            return await _run(conn)

    async def get_new_session_posts(
        self,
        diversity_tolerance: float,
        yesterday_post: List[float] | None,
        liked_topic: str | None,
    ):
        async with self.pool.acquire() as conn:
            if not yesterday_post or not liked_topic:
                return await self._fetch_random_posts(conn, 6)

            target_similarity = max(0.0, 1.0 - diversity_tolerance)
            rows = await conn.fetch(
                f"""
                SELECT {POSTS_WITH_TOPIC_COLUMNS}
                {POSTS_BASE_FROM}
                WHERE pwt.embedding IS NOT NULL
                  AND pwt.topic IS NOT NULL
                  AND LOWER(pwt.topic) = LOWER($2)
                ORDER BY ABS((1 - (pwt.embedding <=> $1::vector)) - $3), pwt.created_at DESC
                LIMIT 6
                """,
                to_pgvector(yesterday_post),
                liked_topic,
                target_similarity,
            )
            if rows:
                return [self._map_post_row(r) for r in rows]

            return await self._fetch_random_posts(conn, 6)

    async def get_posts_by_ids(self, ids: list, *, conn=None) -> list[dict[str, Any]]:
        if not ids:
            return []

        query = f"""
            SELECT {POSTS_WITH_TOPIC_COLUMNS}
            {POSTS_BASE_FROM}
            WHERE pwt.id = ANY($1::uuid[])
        """

        async def _run(connection):
            rows = await connection.fetch(query, ids)
            rows_by_id = {str(row["id"]): self._map_post_row(row) for row in rows}
            normalized = [str(post_id) for post_id in ids]
            return [rows_by_id[post_id] for post_id in normalized if post_id in rows_by_id]

        if conn is not None:
            return await _run(conn)
        async with self.pool.acquire() as conn:
            return await _run(conn)

    async def get_random_posts(self, limit: int = 10, *, conn=None) -> list[dict[str, Any]]:
        if conn is not None:
            return await self._fetch_random_posts(conn, limit)
        async with self.pool.acquire() as conn:
            return await self._fetch_random_posts(conn, limit)
