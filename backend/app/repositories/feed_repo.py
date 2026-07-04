from typing import Any, List
from app.db.vector import to_pgvector

class FeedRepository:
    def __init__(self, pool):
        self.pool = pool

    def _map_post_row(self, row: Any) -> dict[str, Any]:
        return {
            "id": str(row["id"]),
            "content": row["content"],
            "topic": row["topic"],  # may be None if no topic_id
            "created_at": row["created_at"],
            "user_id": row["user_id"],
        }

    # --- Graph ---
    async def get_neighbors(self, id: int, limit: int = 4):
        async with self.pool.acquire() as conn:
            rows = await conn.fetch(
                """
                SELECT to_post_id::text AS to_post_id, MAX(weight) AS weight
                FROM edges
                WHERE from_post_id = $1::uuid
                GROUP BY to_post_id
                ORDER BY MAX(weight) DESC
                LIMIT $2
                """,
                id,
                limit,
            )
        return [dict(r) for r in rows]

    # --- Feed ---
    async def get_similar_posts(self, embedded_post: List[float], limit: int = 4):
        async with self.pool.acquire() as conn:
            rows = await conn.fetch(
                """
                SELECT
                    p.id,
                    p.content,
                    t.name as topic,
                    1 - (p.embedding <=> $1::vector) AS similarity
                FROM posts p
                LEFT JOIN topics t ON t.id = p.topic_id
                WHERE p.embedding IS NOT NULL
                ORDER BY p.embedding <=> $1::vector
                LIMIT $2
                """,
                to_pgvector(embedded_post),
                limit,
            )
        return [
            {
                "id": r["id"],
                "content": r["content"],
                "topic": r["topic"], # may be None if no topic_id
                "similarity": float(r["similarity"]),
            }
            for r in rows
        ]
    
    async def get_opposite_posts(self, embedding, limit: int = 10):
        async with self.pool.acquire() as conn:
            rows = await conn.fetch(
                """
                SELECT p.id, p.content, t.name as topic, 1 - (p.embedding <=> $1::vector) AS similarity
                FROM posts p
                LEFT JOIN topics t ON t.id = p.topic_id
                WHERE p.embedding IS NOT NULL
                ORDER BY p.embedding <=> $1::vector DESC
                LIMIT $2
                """,
                to_pgvector(embedding), limit,
            )
        return [
            {
                "id": r["id"],
                "content": r["content"],
                "topic": r["topic"], # may be None if no topic_id
                "similarity": float(r["similarity"]),
            }
            for r in rows
        ]

    async def get_new_session_posts(
        self,
        diversity_tolerance: float,
        yesterday_post: List[float] | None,
        liked_topic: str | None,
    ):
        async with self.pool.acquire() as conn:
            if not yesterday_post or not liked_topic:
                rows = await conn.fetch(
                    """
                    SELECT p.id, p.content, t.name AS topic, p.created_at, p.user_id
                    FROM posts p
                    LEFT JOIN topics t ON t.id = p.topic_id
                    WHERE p.embedding IS NOT NULL
                    ORDER BY RANDOM()
                    LIMIT 6
                    """
                )
                return [self._map_post_row(r) for r in rows]

            target_similarity = max(0.0, 1.0 - diversity_tolerance)
            rows = await conn.fetch(
                """
                SELECT
                    p.id,
                    p.content,
                    t.name AS topic,
                    p.created_at,
                    p.user_id
                FROM posts p
                LEFT JOIN topics t ON t.id = p.topic_id
                WHERE p.embedding IS NOT NULL
                  AND t.name IS NOT NULL
                  AND LOWER(t.name) = LOWER($2)
                ORDER BY ABS((1 - (p.embedding <=> $1::vector)) - $3), p.created_at DESC
                LIMIT 6
                """,
                to_pgvector(yesterday_post),
                liked_topic,
                target_similarity,
            )
            if rows:
                return [self._map_post_row(r) for r in rows]

            fallback_rows = await conn.fetch(
                """
                SELECT p.id, p.content, t.name AS topic, p.created_at, p.user_id
                FROM posts p
                LEFT JOIN topics t ON t.id = p.topic_id
                WHERE p.embedding IS NOT NULL
                ORDER BY RANDOM()
                LIMIT 6
                """
            )

        return [self._map_post_row(r) for r in fallback_rows]

    async def get_posts_by_ids(self, ids: list):
        if not ids:
            return []

        normalized_ids = [str(post_id) for post_id in ids]
        async with self.pool.acquire() as conn:
            rows = await conn.fetch(
                """
                SELECT p.id, p.content, t.name as topic, p.created_at, p.user_id
                FROM posts p
                LEFT JOIN topics t ON t.id = p.topic_id
                WHERE p.id::text = ANY($1::text[])
                """,
                normalized_ids,
            )
        rows_by_id = {str(row["id"]): self._map_post_row(row) for row in rows}
        return [rows_by_id[post_id] for post_id in normalized_ids if post_id in rows_by_id]

    async def get_random_posts(self, limit: int = 10):
        async with self.pool.acquire() as conn:
            rows = await conn.fetch(
                """
                SELECT p.id, p.content, t.name as topic, p.created_at, p.user_id
                FROM posts p
                LEFT JOIN topics t ON t.id = p.topic_id
                WHERE p.embedding IS NOT NULL
                ORDER BY RANDOM()
                LIMIT $1
                """,
                limit,
            )
        return [self._map_post_row(r) for r in rows]