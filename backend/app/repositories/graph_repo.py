'''build edges of the graph'''
from ..db.base import pool

class GraphRepository:
    
    # since our current limit of posts per screen is 4,
    # (not counting the current post), we hardcode the
    # limit as 4 for now
    async def getNeighbors(self, id: int, limit: int = 4):
        async with pool.acquire() as conn:
            rows = await conn.fetch(
                """
                SELECT to_post_id, weight
                FROM edges
                WHERE from_post_id = $1
                ORDER BY weight DESC
                LIMIT $2
                """,
                id,
                limit
            )
        return [dict(r) for r in rows]