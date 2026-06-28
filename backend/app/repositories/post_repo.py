from typing import List
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
                "SELECT * FROM posts WHERE user_id = $1", id
            )
        
        return [self._map_row(post) for post in posts]

    async def post_user_posts(self, id: int, post: str, embeddedPost: List[float]):
        
        async with self.pool.acquire() as conn:
            result = await conn.fetchrow(
                "INSERT INTO posts (user_id, content, embedding) VALUES ($1, $2, $3::vector) RETURNING *", id, post, to_pgvector(embeddedPost)
            )

        return self._map_row(result)

    async def delete_post(self, user_id: int, post_id: str) -> bool:
        async with self.pool.acquire() as conn:
            result = await conn.execute("DELETE FROM posts WHERE id = $1 AND user_id = $2", post_id, user_id)
        return result == "DELETE 1"
    
    def _map_row(self, row) -> Post:
        return Post(
            id=str(row["id"]),
            user_id=row["user_id"],
            content=row["content"],
            embedding=None, # stored in memory anyway
            created_at=row["created_at"],
            topic=""
        )

