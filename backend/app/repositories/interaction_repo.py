from ..schemas.post import Interaction

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

    async def get_recent_interactions(self, user_id: int, limit: int = 50):
        async with self.pool.acquire() as conn:
            rows = await conn.fetch(
                """
                SELECT i.*, t.name AS topic
                FROM interactions i
                JOIN posts p ON p.id = i.post_id
                LEFT JOIN post_topics pt ON pt.post_id = p.id
                LEFT JOIN topics t ON t.id = pt.topic_id
                WHERE i.user_id = $1
                ORDER BY i.created_at DESC
                LIMIT $2
                """,
                user_id, limit,
            )
        return rows