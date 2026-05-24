from backend.app.main import app
from ml.embeddings.generate import embed

'''
- TODO: Goal: get posts of a user
- Posts for the graph are retrieved in similarity_service.py
'''

@app.get("/users/{id}/posts")
async def getPosts(id: str):

    async with app.state.pool.acquire() as conn:
        posts = await conn.fetch(
            "SELECT * FROM posts WHERE user_id = $1", id
        )
    
    return posts

'''
- TODO: add service to post posts
'''

@app.post("/users/{id}/posts")
async def postPosts(id: str, post: str):
    embedded = embed(post)
    
    async with app.state.pool.acquire() as conn:
        result = await conn.fetch(
            "INSERT INTO posts (user_id, content, embedding) VALUES ($1, $2, $3)", id, post, embedded
        )

    return result