from typing import Any, Sequence

from app.db.conn import acquire_conn
from app.db.datetime_utils import ensure_utc
from app.db.feed_sql import POSTS_BASE_FROM, POSTS_WITH_TOPIC_COLUMNS
from app.db.vector import to_pgvector


class SearchRepository:
    def __init__(self, pool):
        self.pool = pool

    def _map_post_row(self, row: Any) -> dict[str, Any]:
        mapped = {
            "id": str(row["id"]),
            "content": row["content"],
            "topic": row["topic"],
            "created_at": ensure_utc(row["created_at"]),
            "user_id": row["user_id"],
            "username": row["username"] if "username" in row.keys() else None,
        }
        if "rank" in row.keys() and row["rank"] is not None:
            mapped["rank"] = float(row["rank"])
        if "similarity" in row.keys() and row["similarity"] is not None:
            mapped["similarity"] = float(row["similarity"])
        return mapped

    async def keyword_search(
        self,
        query: str,
        *,
        limit: int = 20,
        conn=None,
    ) -> list[dict[str, Any]]:
        """Rank posts by tsvector content match, exact topic, and username hit."""
        trimmed = query.strip()
        if not trimmed:
            return []

        async with acquire_conn(self.pool, conn) as connection:
            try:
                rows = await connection.fetch(
                    f"""
                    WITH q AS (
                        SELECT
                            NULLIF(
                                websearch_to_tsquery('english', $1),
                                ''::tsquery
                            ) AS tsq,
                            lower($1) AS q_lower
                    )
                    SELECT
                        {POSTS_WITH_TOPIC_COLUMNS},
                        (
                            CASE
                                WHEN q.tsq IS NOT NULL
                                THEN COALESCE(ts_rank_cd(p.search_vector, q.tsq), 0)
                                ELSE 0
                            END
                            + CASE
                                WHEN pwt.topic IS NOT NULL
                                     AND lower(pwt.topic) = q.q_lower
                                THEN 1.0
                                ELSE 0
                              END
                            + CASE
                                WHEN EXISTS (
                                    SELECT 1
                                    FROM post_topics pt
                                    WHERE pt.post_id = p.id
                                      AND lower(pt.topic_name) = q.q_lower
                                ) THEN 0.85
                                ELSE 0
                              END
                            + CASE
                                WHEN u.username_lower = q.q_lower THEN 0.8
                                WHEN u.username_lower LIKE q.q_lower || '%' THEN 0.4
                                ELSE 0
                              END
                            + CASE
                                WHEN q.tsq IS NOT NULL AND p.search_vector @@ q.tsq
                                THEN 0.15
                                ELSE 0
                              END
                        ) AS rank
                    FROM posts p
                    JOIN posts_with_topic pwt ON pwt.id = p.id
                    JOIN users u ON u.id = pwt.user_id
                    CROSS JOIN q
                    WHERE
                        (q.tsq IS NOT NULL AND p.search_vector @@ q.tsq)
                        OR (
                            pwt.topic IS NOT NULL
                            AND lower(pwt.topic) = q.q_lower
                        )
                        OR EXISTS (
                            SELECT 1
                            FROM post_topics pt
                            WHERE pt.post_id = p.id
                              AND lower(pt.topic_name) = q.q_lower
                        )
                        OR u.username_lower = q.q_lower
                        OR u.username_lower LIKE q.q_lower || '%'
                    ORDER BY rank DESC, pwt.created_at DESC
                    LIMIT $2
                    """,
                    trimmed,
                    limit,
                )
            except Exception:
                # Fallback when websearch_to_tsquery rejects the input.
                rows = await connection.fetch(
                    f"""
                    SELECT
                        {POSTS_WITH_TOPIC_COLUMNS},
                        (
                            CASE
                                WHEN pwt.topic IS NOT NULL
                                     AND lower(pwt.topic) = lower($1)
                                THEN 1.0
                                ELSE 0
                              END
                            + CASE
                                WHEN EXISTS (
                                    SELECT 1
                                    FROM post_topics pt
                                    WHERE pt.post_id = p.id
                                      AND lower(pt.topic_name) = lower($1)
                                ) THEN 0.85
                                ELSE 0
                              END
                            + CASE
                                WHEN u.username_lower = lower($1) THEN 0.8
                                WHEN u.username_lower LIKE lower($1) || '%' THEN 0.4
                                ELSE 0
                              END
                        ) AS rank
                    FROM posts p
                    JOIN posts_with_topic pwt ON pwt.id = p.id
                    JOIN users u ON u.id = pwt.user_id
                    WHERE
                        (
                            pwt.topic IS NOT NULL
                            AND lower(pwt.topic) = lower($1)
                        )
                        OR EXISTS (
                            SELECT 1
                            FROM post_topics pt
                            WHERE pt.post_id = p.id
                              AND lower(pt.topic_name) = lower($1)
                        )
                        OR u.username_lower = lower($1)
                        OR u.username_lower LIKE lower($1) || '%'
                        OR p.content ILIKE '%' || $1 || '%'
                    ORDER BY rank DESC, pwt.created_at DESC
                    LIMIT $2
                    """,
                    trimmed,
                    limit,
                )
        return [self._map_post_row(row) for row in rows]

    async def semantic_search(
        self,
        embedding: list[float],
        *,
        exclude_ids: Sequence[str] | None = None,
        exclude_topics: Sequence[str] | None = None,
        min_similarity: float = 0.35,
        limit: int = 15,
        conn=None,
    ) -> list[dict[str, Any]]:
        """Nearest neighbors by embedding cosine similarity, above a floor."""
        params: list[Any] = [to_pgvector(embedding), float(min_similarity)]
        where = [
            "pwt.embedding IS NOT NULL",
            "(1 - (pwt.embedding <=> $1::vector)) >= $2",
        ]

        if exclude_ids:
            params.append(list(exclude_ids))
            where.append(f"pwt.id <> ALL(${len(params)}::uuid[])")

        if exclude_topics:
            params.append([t.casefold() for t in exclude_topics])
            where.append(
                f"(pwt.topic IS NULL OR LOWER(pwt.topic) != ALL(${len(params)}::text[]))"
            )

        params.append(limit)
        async with acquire_conn(self.pool, conn) as connection:
            rows = await connection.fetch(
                f"""
                SELECT {POSTS_WITH_TOPIC_COLUMNS},
                       1 - (pwt.embedding <=> $1::vector) AS similarity
                {POSTS_BASE_FROM}
                WHERE {" AND ".join(where)}
                ORDER BY pwt.embedding <=> $1::vector ASC, pwt.created_at DESC
                LIMIT ${len(params)}
                """,
                *params,
            )
        return [self._map_post_row(row) for row in rows]

    async def get_posts_by_ids(
        self, ids: Sequence[str], *, conn=None
    ) -> list[dict[str, Any]]:
        if not ids:
            return []
        async with acquire_conn(self.pool, conn) as connection:
            rows = await connection.fetch(
                f"""
                SELECT {POSTS_WITH_TOPIC_COLUMNS}
                {POSTS_BASE_FROM}
                WHERE pwt.id = ANY($1::uuid[])
                """,
                list(ids),
            )
        return [self._map_post_row(row) for row in rows]
