from typing import List

from app.db.feed_sql import POST_PRIMARY_TOPIC_LATERAL, POSTS_WITH_TOPIC_COLUMNS
from app.schemas.post import Post
from app.db.vector import to_pgvector


class PostRepository:
    def __init__(self, pool):
        self.pool = pool

    # Posts for the graph are retrieved in feed_service.py
    # id here is user id
    async def get_user_posts(self, id: int):
        async with self.pool.acquire() as conn:
            posts = await conn.fetch(
                f"""
                SELECT {POSTS_WITH_TOPIC_COLUMNS}
                FROM posts p
                {POST_PRIMARY_TOPIC_LATERAL}
                WHERE p.user_id = $1
                ORDER BY p.created_at DESC
                """,
                id,
            )

        return [self._map_row(post) for post in posts]

    async def post_user_posts(self, id: int, post: str, embeddedPost: List[float]):
        vec = to_pgvector(embeddedPost)

        async with self.pool.acquire() as conn:
            async with conn.transaction():
                result = await conn.fetchrow(
                    """
                    INSERT INTO posts (user_id, content, embedding)
                    VALUES ($1, $2, $3::vector)
                    RETURNING id, user_id, content, created_at
                    """,
                    id, post, vec,
                )
                post_id = result["id"]

                topic_name = await conn.fetchval(
                    """
                    SELECT pt.topic_name
                    FROM posts p
                    JOIN post_topics pt ON pt.post_id = p.id
                    WHERE p.id != $1 AND p.embedding IS NOT NULL
                    ORDER BY p.embedding <=> $2::vector
                    LIMIT 1
                    """,
                    post_id, vec,
                )

                if topic_name:
                    await conn.execute(
                        """
                        INSERT INTO post_topics (post_id, topic_name)
                        VALUES ($1, $2)
                        ON CONFLICT DO NOTHING
                        """,
                        post_id, topic_name,
                    )

                row = await conn.fetchrow(
                    f"""
                    SELECT {POSTS_WITH_TOPIC_COLUMNS}
                    FROM posts p
                    {POST_PRIMARY_TOPIC_LATERAL}
                    WHERE p.id = $1
                    """,
                    post_id,
                )

        return self._map_row(row)

    async def delete_post(self, user_id: int, post_id: str) -> bool:
        async with self.pool.acquire() as conn:
            result = await conn.execute(
                "DELETE FROM posts WHERE id = $1 AND user_id = $2", post_id, user_id
            )
        return result == "DELETE 1"

    def _map_row(self, row) -> Post:
        return Post(
            id=str(row["id"]),
            user_id=row["user_id"],
            content=row["content"],
            embedding=None,
            created_at=row["created_at"],
            topic=row.get("topic") or "",
        )
