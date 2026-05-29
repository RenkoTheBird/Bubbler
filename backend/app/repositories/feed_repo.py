from backend.app.main import app

'''
Notes:
- The post embedding should be passed in, not the post itself (embedding again would be redundant)
- The "limit" parameter defines the max posts that will appear in the graph
- In pgvector, the <=> operator defines cosine similarity, NOT null-safe equality
'''

@app.get("posts/similar")
async def getSimilarPosts(embeddedPost: list[float], limit: int=4):

    async with app.state.pool.acquire() as conn:
        rows = await conn.fetch(
            """
            SELECT
                id,
                content,
                1 - (embedding <=> $1) AS similarity
            FROM posts
            ORDER BY embedding <=> $1
            LIMIT $2
            """,
            embeddedPost,
            limit
        )

    return [
        {
            "id": r["id"],
            "content": r["content"],
            "similarity": float(r["similarity"]),
        }
        for r in rows
    ]

