from app.schemas.post import Interaction


class InteractionRepository:
    def __init__(self, pool):
        self.pool = pool

    async def record(self, user_id: int, post_id: str, type: str, view_time: float = 0):
        async with self.pool.acquire() as conn:
            await conn.execute(
                """
                INSERT INTO interactions (user_id, post_id, type, view_time)
                VALUES ($1, $2, $3, $4)
                """,
                user_id, post_id, type, view_time,
            )

    async def get_recent_interactions(self, user_id: int, limit: int = 50) -> list[Interaction]:
        async with self.pool.acquire() as conn:
            rows = await conn.fetch(
                """
                SELECT sub.*, pt.topic_name AS topic
                FROM (
                    SELECT *
                    FROM interactions
                    WHERE user_id = $1
                    ORDER BY created_at DESC
                    LIMIT $2
                ) sub
                LEFT JOIN LATERAL (
                    SELECT topic_name
                    FROM post_topics
                    WHERE post_id = sub.post_id
                    ORDER BY weight DESC
                    LIMIT 1
                ) pt ON true
                ORDER BY sub.created_at DESC
                """,
                user_id, limit,
            )
        return [self._row_to_interaction(row) for row in rows]

    @staticmethod
    def _row_to_interaction(row) -> Interaction:
        return Interaction(
            id=str(row["id"]),
            user_id=str(row["user_id"]),
            post_id=str(row["post_id"]),
            type=row["type"],
            created_at=row["created_at"],
            topic=row["topic"] or "",
            view_time=row["view_time"] or 0.0,
            liked=row["type"] == "like",
        )
