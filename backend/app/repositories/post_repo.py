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
    
    def _map_row(self, row) -> Post:
        return Post(
            id=str(row["id"]),
            user_id=row["user_id"],
            content=row["content"],
            embedding=None, # stored in memory anyway
            created_at=row["created_at"],
            topic=""
        )

