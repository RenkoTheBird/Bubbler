from typing import List
from schemas.post import Post

class PostRepository:

    # Posts for the graph are retrieved in feed_service.py
    # id here is user id
    @classmethod
    async def getUserPosts(cls, pool, id: int):

        async with pool.acquire() as conn:
            posts = await conn.fetch(
                "SELECT * FROM posts WHERE user_id = $1", id
            )
        
        return [cls._map_row(post) for post in posts]

    @classmethod
    async def postUserPosts(cls, pool, id: int, post: str, embeddedPost: List[float]):
        
        async with cls.pool.acquire() as conn:
            result = await conn.fetch(
                "INSERT INTO posts (user_id, content, embedding) VALUES ($1, $2, $3)", id, post, embeddedPost
            )

        return cls._map_row(result)
    
    @classmethod
    def _map_row(cls, row) -> Post:
        return Post(
            id=row["id"],
            user_id=row["user_id"],
            content=row["content"],
            embedding=row["embedding"]
        )
