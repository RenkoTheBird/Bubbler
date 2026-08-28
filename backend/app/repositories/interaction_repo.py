import datetime

from app.db.datetime_utils import ensure_utc
from app.db.feed_sql import POSTS_WITH_TOPIC_VIEW
from app.db.vector import from_pgvector
from app.schemas.post import FeedPreferenceEntry, Interaction
from app.services.feed_preference_scoring import FeedPreferenceSignal


class InteractionRepository:
    def __init__(self, pool):
        self.pool = pool

    async def record(self, user_id: int, post_id: str, type: str, view_time: float = 0):
        async with self.pool.acquire() as conn:
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

    async def set_feed_preference(
        self,
        user_id: int,
        post_id: str,
        feed_preference: int,
        *,
        view_time: float = 0.0,
    ) -> None:
        if feed_preference == 0:
            async with self.pool.acquire() as conn:
                await conn.execute(
                    """
                    DELETE FROM interactions
                    WHERE user_id = $1
                      AND post_id = $2
                      AND type = 'preference'
                    """,
                    user_id,
                    post_id,
                )
            return

        async with self.pool.acquire() as conn:
            await conn.execute(
                """
                INSERT INTO interactions (
                    user_id, post_id, type, feed_preference, view_time
                )
                VALUES ($1, $2, 'preference', $3, $4)
                ON CONFLICT (user_id, post_id) WHERE (type = 'preference')
                DO UPDATE SET
                    feed_preference = EXCLUDED.feed_preference,
                    view_time = EXCLUDED.view_time,
                    created_at = NOW()
                """,
                user_id,
                post_id,
                feed_preference,
                view_time,
            )

    async def get_feed_preferences(self, user_id: int) -> list[FeedPreferenceEntry]:
        async with self.pool.acquire() as conn:
            rows = await conn.fetch(
                """
                SELECT post_id, feed_preference
                FROM interactions
                WHERE user_id = $1
                  AND type = 'preference'
                ORDER BY created_at DESC
                """,
                user_id,
            )
        return [
            FeedPreferenceEntry(
                post_id=str(row["post_id"]),
                feed_preference=int(row["feed_preference"]),
            )
            for row in rows
        ]

    async def get_feed_preference_signals(
        self, user_id: int, *, limit: int = 200
    ) -> list[FeedPreferenceSignal]:
        async with self.pool.acquire() as conn:
            rows = await conn.fetch(
                f"""
                SELECT i.post_id, i.feed_preference, pwt.embedding, pwt.topic
                FROM interactions i
                JOIN {POSTS_WITH_TOPIC_VIEW} pwt ON pwt.id = i.post_id
                WHERE i.user_id = $1
                  AND i.type = 'preference'
                  AND i.feed_preference IS NOT NULL
                  AND i.feed_preference <> 0
                  AND pwt.embedding IS NOT NULL
                ORDER BY i.created_at DESC
                LIMIT $2
                """,
                user_id,
                limit,
            )

        signals: list[FeedPreferenceSignal] = []
        for row in rows:
            embedding = from_pgvector(row["embedding"])
            if not embedding:
                continue
            topic = row["topic"]
            signals.append(
                FeedPreferenceSignal(
                    post_id=str(row["post_id"]),
                    feed_preference=int(row["feed_preference"]),
                    embedding=embedding,
                    topic=topic.strip() if isinstance(topic, str) else None,
                )
            )
        return signals

    async def get_preference_session_seed(
        self, user_id: int
    ) -> tuple[list[float] | None, str | None]:
        """Weighted centroid from positive feed preferences; yesterday's rows count double."""
        now = datetime.datetime.now(datetime.timezone.utc)
        today_start = now.replace(hour=0, minute=0, second=0, microsecond=0, tzinfo=None)
        yesterday_start = today_start - datetime.timedelta(days=1)

        async with self.pool.acquire() as conn:
            rows = await conn.fetch(
                f"""
                SELECT
                    i.feed_preference,
                    i.created_at,
                    pwt.embedding,
                    pwt.topic
                FROM interactions i
                JOIN {POSTS_WITH_TOPIC_VIEW} pwt ON pwt.id = i.post_id
                WHERE i.user_id = $1
                  AND i.type = 'preference'
                  AND i.feed_preference > 0
                  AND pwt.embedding IS NOT NULL
                ORDER BY i.created_at DESC
                LIMIT 100
                """,
                user_id,
            )

        if not rows:
            return None, None

        weighted_vectors: list[tuple[list[float], float]] = []
        topic_weights: dict[str, float] = {}

        for row in rows:
            embedding = from_pgvector(row["embedding"])
            if not embedding:
                continue
            preference = int(row["feed_preference"])
            created_at = row["created_at"]
            if getattr(created_at, "tzinfo", None) is not None:
                created_at = created_at.replace(tzinfo=None)
            recency_multiplier = (
                2.0
                if yesterday_start <= created_at < today_start
                else 1.0
            )
            weight = float(preference) * recency_multiplier
            weighted_vectors.append((embedding, weight))

            topic = row["topic"]
            if isinstance(topic, str) and topic.strip():
                key = topic.strip().casefold()
                topic_weights[key] = topic_weights.get(key, 0.0) + weight

        if not weighted_vectors:
            return None, None

        dimension = len(weighted_vectors[0][0])
        total_weight = sum(weight for _, weight in weighted_vectors)
        centroid = [0.0] * dimension
        for vector, weight in weighted_vectors:
            if len(vector) != dimension:
                continue
            for index, value in enumerate(vector):
                centroid[index] += value * weight
        centroid = [value / total_weight for value in centroid]

        dominant = max(topic_weights, key=topic_weights.get) if topic_weights else None
        return centroid, dominant

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

    @staticmethod
    def _row_to_interaction(row) -> Interaction:
        feed_preference = row.get("feed_preference")
        return Interaction(
            id=str(row["id"]),
            user_id=str(row["user_id"]),
            post_id=str(row["post_id"]),
            type=row["type"],
            created_at=ensure_utc(row["created_at"]),
            topic=row["topic"] or "",
            view_time=row["view_time"] or 0.0,
            feed_preference=int(feed_preference) if feed_preference is not None else None,
        )
