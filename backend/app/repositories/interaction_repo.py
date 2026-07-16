import datetime

from app.db.datetime_utils import ensure_utc
from app.db.feed_sql import POSTS_WITH_TOPIC_VIEW
from app.db.vector import from_pgvector
from app.schemas.post import Interaction


class InteractionRepository:
    def __init__(self, pool):
        self.pool = pool

    async def record(self, user_id: int, post_id: str, type: str, view_time: float = 0):
        async with self.pool.acquire() as conn:
            if type == "like":
                # Likes are unique per user+post; re-like refreshes the row.
                await conn.execute(
                    """
                    INSERT INTO interactions (user_id, post_id, type, view_time)
                    VALUES ($1, $2, 'like', $3)
                    ON CONFLICT (user_id, post_id) WHERE (type = 'like')
                    DO UPDATE SET
                        view_time = EXCLUDED.view_time,
                        created_at = NOW()
                    """,
                    user_id,
                    post_id,
                    view_time,
                )
            else:
                # explore/skip may be recorded many times for the same post.
                await conn.execute(
                    """
                    INSERT INTO interactions (user_id, post_id, type, view_time)
                    VALUES ($1, $2, $3, $4)
                    """,
                    user_id,
                    post_id,
                    type,
                    view_time,
                )

    async def delete_like(self, user_id: int, post_id: str) -> bool:
        async with self.pool.acquire() as conn:
            result = await conn.execute(
                """
                DELETE FROM interactions
                WHERE user_id = $1
                  AND post_id = $2
                  AND type = 'like'
                """,
                user_id,
                post_id,
            )
        # asyncpg returns strings like "DELETE 1"
        return result.endswith("1")

    async def get_recent_interactions(self, user_id: int, limit: int = 50) -> list[Interaction]:
        async with self.pool.acquire() as conn:
            rows = await conn.fetch(
                f"""
                SELECT sub.*, pwt.topic
                FROM (
                    SELECT *
                    FROM interactions
                    WHERE user_id = $1
                    ORDER BY created_at DESC
                    LIMIT $2
                ) sub
                LEFT JOIN {POSTS_WITH_TOPIC_VIEW} pwt ON pwt.id = sub.post_id
                ORDER BY sub.created_at DESC
                """,
                user_id, limit,
            )
        return [self._row_to_interaction(row) for row in rows]

    async def get_liked_post_ids(self, user_id: int) -> list[str]:
        """All post IDs the user currently likes (uncapped; used for heart state)."""
        async with self.pool.acquire() as conn:
            rows = await conn.fetch(
                """
                SELECT post_id
                FROM interactions
                WHERE user_id = $1
                  AND type = 'like'
                ORDER BY created_at DESC
                """,
                user_id,
            )
        return [str(row["post_id"]) for row in rows]

    async def get_yesterday_liked_post(
        self, user_id: int
    ) -> tuple[list[float] | None, str | None]:
        """Most recent like from yesterday's UTC calendar day (embedding + topic)."""
        now = datetime.datetime.now(datetime.timezone.utc)
        today_start = now.replace(hour=0, minute=0, second=0, microsecond=0, tzinfo=None)
        yesterday_start = today_start - datetime.timedelta(days=1)

        async with self.pool.acquire() as conn:
            row = await conn.fetchrow(
                f"""
                SELECT pwt.embedding, pwt.topic
                FROM interactions i
                JOIN {POSTS_WITH_TOPIC_VIEW} pwt ON pwt.id = i.post_id
                WHERE i.user_id = $1
                  AND i.type = 'like'
                  AND i.created_at >= $2
                  AND i.created_at < $3
                  AND pwt.embedding IS NOT NULL
                  AND pwt.topic IS NOT NULL
                ORDER BY i.created_at DESC
                LIMIT 1
                """,
                user_id,
                yesterday_start,
                today_start,
            )

        if row is None:
            return None, None

        embedding = from_pgvector(row["embedding"])
        topic = row["topic"]
        if not embedding or not isinstance(topic, str) or not topic.strip():
            return None, None
        return embedding, topic.strip()

    @staticmethod
    def _row_to_interaction(row) -> Interaction:
        return Interaction(
            id=str(row["id"]),
            user_id=str(row["user_id"]),
            post_id=str(row["post_id"]),
            type=row["type"],
            created_at=ensure_utc(row["created_at"]),
            topic=row["topic"] or "",
            view_time=row["view_time"] or 0.0,
            liked=row["type"] == "like",
        )
