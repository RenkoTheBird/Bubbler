from backend.app.main import app
from typing import List

class PostRepository:

    def __init__(self, pool):
        self.pool = pool

    # Posts for the graph are retrieved in feed_service.py
    async def getPosts(id: str):

        async with app.state.pool.acquire() as conn:
            posts = await conn.fetch(
                "SELECT * FROM posts WHERE user_id = $1", id
            )
        
        return posts

    async def postPosts(id: str, post: str, embeddedPost: List[float]):
        
        async with app.state.pool.acquire() as conn:
            result = await conn.fetch(
                "INSERT INTO posts (user_id, content, embedding) VALUES ($1, $2, $3)", id, post, embeddedPost
            )

        return result