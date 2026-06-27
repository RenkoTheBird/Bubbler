from typing import List
from app.db.vector import to_pgvector

class FeedRepository:
    def __init__(self, pool):
        self.pool = pool

    # --- Graph ---
    async def get_neighbors(self, id: int, limit: int = 4):
        async with self.pool.acquire() as conn:
            rows = await conn.fetch(
                """
                SELECT to_post_id, weight
                FROM edges
                WHERE from_post_id = $1
                ORDER BY weight DESC
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

    async def get_new_session_posts(self, diversity_tolerance: float, yesterday_post: List[float], liked_topic: str):
        val = 1
        similarity_targets = []
        for i in range(4):
            similarity_targets.append(val)
            val = max(0, val - diversity_tolerance)

        results = []

        async with self.pool.acquire() as conn:
            for target in similarity_targets:
                post = await conn.fetchrow(
                    """
                    SELECT *,
                        1 - (embedding <=> $1::vector) AS similarity
                    FROM posts
                    WHERE topic_id = $2
                    ORDER BY ABS((1 - (embedding <=> $1::vector)) - $3)
                    LIMIT 1
                    """,
                    to_pgvector(yesterday_post),
                    liked_topic,
                    target,
                )
                if post:
                    results.append(dict(post))

        return results

    async def get_posts_by_ids(self, ids: list):
        if not ids:
            return []

        async with self.pool.acquire() as conn:
            rows = await conn.fetch(
                """
                SELECT p.id, p.content, t.name as topic, p.created_at, p.user_id
                FROM posts p
                LEFT JOIN topics t ON t.id = p.topic_id
                WHERE p.id = ANY($1)
                """,
                ids,
            )
        return [
            {
                "id": r["id"],
                "content": r["content"],
                "topic": r["topic"], # may be None if no topic_id
                "created_at": r["created_at"],
                "user_id": r["user_id"],
            }
            for r in rows
        ]

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
        return [
            {
                "id": r["id"],
                "content": r["content"],
                "topic": r["topic"], # may be None if no topic_id
                "created_at": r["created_at"],
                "user_id": r["user_id"],
            }
            for r in rows
        ]