from typing import List

from app.db.feed_sql import POSTS_BASE_FROM, POSTS_WITH_TOPIC_COLUMNS
from app.db.topics import DEFAULT_TOPIC
from app.schemas.post import Post
from app.db.vector import to_pgvector
from app.services.topic_detection import AI_TOPIC_HIDDEN_WEIGHT


class PostRepository:
    def __init__(self, pool):
        self.pool = pool

    async def _log_topic_training_event(
        self,
        conn,
        *,
        post_id,
        user_id: int,
        topic_name: str,
        action: str,
    ) -> None:
        await conn.execute(
            """
            INSERT INTO topic_training_events (post_id, user_id, topic_name, action)
            VALUES ($1, $2, $3, $4)
            """,
            post_id,
            user_id,
            topic_name,
            action,
        )

    async def _get_owned_post_id(self, conn, user_id: int, post_id: str):
        return await conn.fetchval(
            """
            SELECT id
            FROM posts
            WHERE id = $1 AND user_id = $2
            """,
            post_id,
            user_id,
        )

    async def ensure_topics(self, topic_embeddings: dict[str, list[float]], *, conn=None) -> None:
        records = [
            (topic_name, to_pgvector(embedding))
            for topic_name, embedding in topic_embeddings.items()
        ]
        if not records:
            return

        async def _run(connection):
            await connection.executemany(
                """
                INSERT INTO topics (name, embedding)
                VALUES ($1, $2::vector)
                ON CONFLICT (name) DO UPDATE
                SET embedding = COALESCE(topics.embedding, EXCLUDED.embedding)
                """,
                records,
            )

        if conn is not None:
            await _run(conn)
            return

        async with self.pool.acquire() as connection:
            await _run(connection)

    # Posts for the graph are retrieved in feed_service.py
    # id here is user id
    async def get_user_posts(self, id: int):
        async with self.pool.acquire() as conn:
            posts = await conn.fetch(
                f"""
                SELECT {POSTS_WITH_TOPIC_COLUMNS}
                {POSTS_BASE_FROM}
                WHERE pwt.user_id = $1
                ORDER BY pwt.created_at DESC
                """,
                id,
            )

        return [self._map_row(post) for post in posts]

    async def post_user_posts(
        self,
        id: int,
        post: str,
        embeddedPost: List[float],
        edge_builder=None,
        topic: str | None = None,
        ai_topics: list[dict[str, float | str]] | None = None,
    ):
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

                if topic is not None:
                    topic_name = topic
                else:
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
                    ) or DEFAULT_TOPIC

                await conn.execute(
                    """
                    INSERT INTO topics (name)
                    VALUES ($1)
                    ON CONFLICT (name) DO NOTHING
                    """,
                    topic_name,
                )
                await conn.execute(
                    """
                    INSERT INTO post_topics (post_id, topic_name, source, confidence, weight)
                    VALUES ($1, $2, 'user', 1.0, 1.0)
                    ON CONFLICT DO NOTHING
                    """,
                    post_id, topic_name,
                )
                if topic is not None:
                    await self._log_topic_training_event(
                        conn,
                        post_id=post_id,
                        user_id=id,
                        topic_name=topic_name,
                        action="add",
                    )
                if ai_topics:
                    ai_topic_records = [
                        (
                            post_id,
                            topic["topic_name"],
                            float(topic["confidence"]),
                            AI_TOPIC_HIDDEN_WEIGHT,
                        )
                        for topic in ai_topics
                        if topic["topic_name"] != topic_name
                    ]
                    if ai_topic_records:
                        await conn.executemany(
                            """
                            INSERT INTO post_topics (post_id, topic_name, source, confidence, weight)
                            VALUES ($1, $2, 'ai', $3, $4)
                            ON CONFLICT DO NOTHING
                            """,
                            ai_topic_records,
                        )

                if edge_builder is not None:
                    await edge_builder.build_edges_for_post(
                        post_id, embeddedPost, conn=conn,
                    )

                row = await conn.fetchrow(
                    f"""
                    SELECT {POSTS_WITH_TOPIC_COLUMNS}
                    {POSTS_BASE_FROM}
                    WHERE pwt.id = $1
                    """,
                    post_id,
                )

        return self._map_row(row)

    async def add_post_topic(self, user_id: int, post_id: str, topic_name: str) -> Post | None:
        async with self.pool.acquire() as conn:
            async with conn.transaction():
                owned_post_id = await self._get_owned_post_id(conn, user_id, post_id)
                if owned_post_id is None:
                    return None

                existing = await conn.fetchrow(
                    """
                    SELECT source
                    FROM post_topics
                    WHERE post_id = $1 AND topic_name = $2
                    """,
                    post_id,
                    topic_name,
                )

                await conn.execute(
                    """
                    INSERT INTO topics (name)
                    VALUES ($1)
                    ON CONFLICT (name) DO NOTHING
                    """,
                    topic_name,
                )
                await conn.execute(
                    """
                    INSERT INTO post_topics (post_id, topic_name, source, confidence, weight)
                    VALUES ($1, $2, 'user', 1.0, 1.0)
                    ON CONFLICT (post_id, topic_name) DO UPDATE
                    SET source = 'user',
                        confidence = 1.0,
                        weight = 1.0
                    """,
                    post_id,
                    topic_name,
                )

                if existing is None or existing["source"] != "user":
                    await self._log_topic_training_event(
                        conn,
                        post_id=post_id,
                        user_id=user_id,
                        topic_name=topic_name,
                        action="add",
                    )

                row = await conn.fetchrow(
                    f"""
                    SELECT {POSTS_WITH_TOPIC_COLUMNS}
                    {POSTS_BASE_FROM}
                    WHERE pwt.id = $1
                    """,
                    post_id,
                )

        return self._map_row(row)

    async def remove_post_topic(self, user_id: int, post_id: str, topic_name: str) -> Post | None:
        async with self.pool.acquire() as conn:
            async with conn.transaction():
                owned_post_id = await self._get_owned_post_id(conn, user_id, post_id)
                if owned_post_id is None:
                    return None

                existing = await conn.fetchrow(
                    """
                    SELECT source
                    FROM post_topics
                    WHERE post_id = $1 AND topic_name = $2
                    """,
                    post_id,
                    topic_name,
                )
                if existing is None:
                    return None

                topic_count = await conn.fetchval(
                    """
                    SELECT COUNT(*)
                    FROM post_topics
                    WHERE post_id = $1
                    """,
                    post_id,
                )
                if topic_count <= 1:
                    raise ValueError("Cannot remove the last topic from a post")

                await conn.execute(
                    """
                    DELETE FROM post_topics
                    WHERE post_id = $1 AND topic_name = $2
                    """,
                    post_id,
                    topic_name,
                )
                await self._log_topic_training_event(
                    conn,
                    post_id=post_id,
                    user_id=user_id,
                    topic_name=topic_name,
                    action="remove",
                )

                row = await conn.fetchrow(
                    f"""
                    SELECT {POSTS_WITH_TOPIC_COLUMNS}
                    {POSTS_BASE_FROM}
                    WHERE pwt.id = $1
                    """,
                    post_id,
                )

        return self._map_row(row)

    async def edit_post(self, user_id: int, post_id: str, post: str, embedded: List[float]):
        vec = to_pgvector(embedded)
        async with self.pool.acquire() as conn:
            result = await conn.execute(
                "UPDATE posts SET content = $1, embedding = $2 WHERE id = $3 AND user_id = $4",
                post, vec, post_id, user_id,
            )
        return result == "UPDATE 1"

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
