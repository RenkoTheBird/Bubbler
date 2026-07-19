from contextlib import asynccontextmanager
from typing import Any, List, Sequence

from app.db.conn import acquire_conn
from app.db.datetime_utils import ensure_utc
from app.db.feed_sql import (
    POSTS_BASE_FROM,
    POSTS_TABLESAMPLE_FROM,
    POSTS_WITH_TOPIC_COLUMNS,
)
from app.db.vector import to_pgvector
from app.schemas.edge import Edge

# TABLESAMPLE percentage — tunable; avoids full-table ORDER BY RANDOM()
_RANDOM_SAMPLE_PERCENT = 25
_SESSION_CANDIDATE_LIMIT = 40
_EDGES_PER_TYPE_LIMIT = 8


class FeedRepository:
    def __init__(self, pool):
        self.pool = pool

    @asynccontextmanager
    async def acquire(self):
        async with self.pool.acquire() as conn:
            yield conn

    def _map_post_row(self, row: Any) -> dict[str, Any]:
        mapped = {
            "id": str(row["id"]),
            "content": row["content"],
            "topic": row["topic"],
            "created_at": ensure_utc(row["created_at"]),
            "user_id": row["user_id"],
        }
        if "username" in row.keys():
            mapped["username"] = row["username"]
        return mapped

    def _map_similarity_row(self, row: Any) -> dict[str, Any]:
        mapped = {
            "id": str(row["id"]),
            "content": row["content"],
            "topic": row["topic"],
            "similarity": float(row["similarity"]),
        }
        if "created_at" in row.keys():
            mapped["created_at"] = ensure_utc(row["created_at"])
        if "user_id" in row.keys():
            mapped["user_id"] = row["user_id"]
        if "username" in row.keys():
            mapped["username"] = row["username"]
        return mapped

    @staticmethod
    def _map_edge(row: Any) -> Edge:
        return Edge(
            id=str(row["id"]),
            from_post_id=str(row["from_post_id"]),
            to_post_id=str(row["to_post_id"]),
            type=row["edge_type"],
            weight=float(row["weight"]) if row["weight"] is not None else None,
        )

    async def _fetch_posts_by_embedding(
        self,
        conn,
        embedded_post: List[float],
        limit: int,
        *,
        ascending: bool = True,
        exclude_topics: Sequence[str] | None = None,
        near_target: float | None = None,
    ) -> list[dict[str, Any]]:
        params: list[Any] = [to_pgvector(embedded_post)]
        where = ["pwt.embedding IS NOT NULL"]

        if exclude_topics:
            params.append([t.casefold() for t in exclude_topics])
            where.append(
                f"(pwt.topic IS NULL OR LOWER(pwt.topic) != ALL(${len(params)}::text[]))"
            )

        if near_target is not None:
            params.append(float(near_target))
            order_expr = (
                f"ABS((1 - (pwt.embedding <=> $1::vector)) - ${len(params)})"
            )
        else:
            order = "ASC" if ascending else "DESC"
            order_expr = f"pwt.embedding <=> $1::vector {order}"

        params.append(limit)
        rows = await conn.fetch(
            f"""
            SELECT {POSTS_WITH_TOPIC_COLUMNS},
                   1 - (pwt.embedding <=> $1::vector) AS similarity
            {POSTS_BASE_FROM}
            WHERE {" AND ".join(where)}
            ORDER BY {order_expr}, pwt.created_at DESC
            LIMIT ${len(params)}
            """,
            *params,
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
    ) -> dict[str, list[Edge]]:
        if not ids:
            return {}

        query = """
            SELECT id, from_post_id, to_post_id, edge_type, weight
            FROM (
                SELECT
                    id,
                    from_post_id,
                    to_post_id,
                    edge_type,
                    weight,
                    ROW_NUMBER() OVER (
                        PARTITION BY from_post_id
                        ORDER BY weight DESC NULLS LAST
                    ) AS rn
                FROM (
                    SELECT DISTINCT ON (from_post_id, to_post_id)
                        id,
                        from_post_id,
                        to_post_id,
                        edge_type,
                        weight
                    FROM edges
                    WHERE from_post_id = ANY($1::uuid[])
                    ORDER BY from_post_id, to_post_id, weight DESC NULLS LAST
                ) best_per_pair
            ) ranked
            WHERE rn <= $2
        """

        async with acquire_conn(self.pool, conn) as connection:
            rows = await connection.fetch(query, ids, limit)
            result: dict[str, list[Edge]] = {}
            for row in rows:
                edge = self._map_edge(row)
                result.setdefault(edge.from_post_id, []).append(edge)
            return result

    async def get_neighbors(self, id: str, limit: int = 4, *, conn=None) -> list[Edge]:
        batch = await self.get_neighbors_batch([id], limit=limit, conn=conn)
        return batch.get(str(id), [])

    async def get_outbound_edges_by_type(
        self,
        post_id: str,
        *,
        per_type_limit: int = _EDGES_PER_TYPE_LIMIT,
        conn=None,
    ) -> list[Edge]:
        """Return outbound edges, keeping up to ``per_type_limit`` per edge_type."""
        query = """
            SELECT id, from_post_id, to_post_id, edge_type, weight
            FROM (
                SELECT
                    id,
                    from_post_id,
                    to_post_id,
                    edge_type,
                    weight,
                    ROW_NUMBER() OVER (
                        PARTITION BY edge_type
                        ORDER BY weight DESC NULLS LAST
                    ) AS rn
                FROM edges
                WHERE from_post_id = $1
            ) ranked
            WHERE rn <= $2
        """
        async with acquire_conn(self.pool, conn) as connection:
            rows = await connection.fetch(query, post_id, per_type_limit)
            return [self._map_edge(row) for row in rows]

    # --- Feed ---
    async def get_similar_posts(
        self, embedded_post: List[float], limit: int = 4, *, conn=None
    ) -> list[dict[str, Any]]:
        async with acquire_conn(self.pool, conn) as connection:
            return await self._fetch_posts_by_embedding(
                connection, embedded_post, limit, ascending=True
            )

    async def get_opposite_posts(
        self, embedding: List[float], limit: int = 10, *, conn=None
    ) -> list[dict[str, Any]]:
        async with acquire_conn(self.pool, conn) as connection:
            return await self._fetch_posts_by_embedding(
                connection, embedding, limit, ascending=False
            )

    async def get_new_session_posts(
        self,
        diversity_tolerance: float,
        yesterday_post: List[float] | None,
        liked_topic: str | None,
        *,
        blacklisted_topics: set[str] | None = None,
        diversify: bool = False,
        max_per_topic: int | None = None,
    ) -> tuple[list[dict[str, Any]], str, int]:
        """Return session candidate posts plus seed metadata.

        Yesterday's like is a soft prior (similarity band), not a topic cage.
        Blacklisted topics are excluded. ``diversify`` escapes the prior region.
        Diversity selection happens in FeedService after preference scoring.
        """
        blacklisted = {t.casefold() for t in (blacklisted_topics or set())}
        if max_per_topic is None:
            effective_diversity = 1.0 if diversify else min(
                max(float(diversity_tolerance), 0.0), 1.0
            )
            # Six-post sessions range from a focused three-per-topic mix to
            # one post per topic at maximum diversity.
            if effective_diversity <= 1 / 3:
                max_per_topic = 3
            elif effective_diversity >= 2 / 3:
                max_per_topic = 1
            else:
                max_per_topic = 2

        target_similarity = max(0.0, 1.0 - diversity_tolerance)

        async with self.pool.acquire() as conn:
            candidates: list[dict[str, Any]] = []
            seed_strategy = "random"

            if diversify:
                seed_strategy = "diversify"
                exclude = blacklisted | (
                    {liked_topic.casefold()} if liked_topic else set()
                )
                if yesterday_post:
                    opposite = await self._fetch_posts_by_embedding(
                        conn,
                        yesterday_post,
                        _SESSION_CANDIDATE_LIMIT // 2,
                        ascending=False,
                        exclude_topics=list(exclude) or None,
                    )
                    for post in opposite:
                        post["_strategy"] = "opposite"
                    candidates.extend(opposite)

                    similar = await self._fetch_posts_by_embedding(
                        conn,
                        yesterday_post,
                        _SESSION_CANDIDATE_LIMIT // 2,
                        near_target=target_similarity,
                        exclude_topics=list(exclude) or None,
                    )
                    for post in similar:
                        post["_strategy"] = "similar"
                    candidates.extend(similar)
                random_posts = await self._fetch_random_posts(
                    conn, _SESSION_CANDIDATE_LIMIT
                )
                for post in random_posts:
                    post["_strategy"] = "random"
                candidates.extend(random_posts)
            elif yesterday_post:
                seed_strategy = "soft_prior"
                similar = await self._fetch_posts_by_embedding(
                    conn,
                    yesterday_post,
                    _SESSION_CANDIDATE_LIMIT,
                    near_target=target_similarity,
                    exclude_topics=list(blacklisted) or None,
                )
                for post in similar:
                    post["_strategy"] = "similar"
                candidates.extend(similar)
                random_posts = await self._fetch_random_posts(
                    conn, _SESSION_CANDIDATE_LIMIT // 2
                )
                for post in random_posts:
                    post["_strategy"] = "random"
                candidates.extend(random_posts)
            else:
                random_posts = await self._fetch_random_posts(
                    conn, _SESSION_CANDIDATE_LIMIT
                )
                for post in random_posts:
                    post["_strategy"] = "random"
                candidates.extend(random_posts)

            filtered: list[dict[str, Any]] = []
            seen: set[str] = set()
            for post in candidates:
                topic = post.get("topic")
                normalized = (
                    topic.strip().casefold()
                    if isinstance(topic, str) and topic.strip()
                    else None
                )
                if normalized and normalized in blacklisted:
                    continue
                post_id = str(post["id"])
                if post_id in seen:
                    continue
                seen.add(post_id)
                filtered.append(post)

            if not filtered:
                # Last resort: random again without soft prior but still blacklist.
                for post in await self._fetch_random_posts(conn, _SESSION_CANDIDATE_LIMIT):
                    post["_strategy"] = "random"
                    topic = post.get("topic")
                    normalized = (
                        topic.strip().casefold()
                        if isinstance(topic, str) and topic.strip()
                        else None
                    )
                    if normalized and normalized in blacklisted:
                        continue
                    post_id = str(post["id"])
                    if post_id in seen:
                        continue
                    seen.add(post_id)
                    filtered.append(post)
                if diversify:
                    seed_strategy = "diversify_fallback"
                elif yesterday_post:
                    seed_strategy = "soft_prior_fallback"

            # Soft prior hint for the service layer (not a hard filter).
            for post in filtered:
                post.setdefault("similarity", 0.3)
                if liked_topic and not diversify:
                    topic = post.get("topic")
                    normalized = (
                        topic.strip().casefold()
                        if isinstance(topic, str) and topic.strip()
                        else None
                    )
                    if normalized == liked_topic.casefold():
                        post["similarity"] = float(post.get("similarity", 0.3)) + 0.05

            return filtered, seed_strategy, max_per_topic

    async def get_posts_by_ids(self, ids: list, *, conn=None) -> list[dict[str, Any]]:
        if not ids:
            return []

        query = f"""
            SELECT {POSTS_WITH_TOPIC_COLUMNS}
            {POSTS_BASE_FROM}
            WHERE pwt.id = ANY($1::uuid[])
        """

        async with acquire_conn(self.pool, conn) as connection:
            rows = await connection.fetch(query, ids)
            rows_by_id = {str(row["id"]): self._map_post_row(row) for row in rows}
            normalized = [str(post_id) for post_id in ids]
            return [rows_by_id[post_id] for post_id in normalized if post_id in rows_by_id]

    async def get_random_posts(self, limit: int = 10, *, conn=None) -> list[dict[str, Any]]:
        async with acquire_conn(self.pool, conn) as connection:
            return await self._fetch_random_posts(connection, limit)
