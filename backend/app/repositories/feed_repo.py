from typing import List

class FeedRepository:
    def __init__(self, pool):
        self.pool = pool

    async def getSimilarPosts(self, embeddedPost: List[float], limit: int = 4):

        async with self.pool.acquire() as conn:
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
    
    async def getOppositePosts(self, embedding, limit: int = 10):
        async with self.pool.acquire() as conn:
            rows = await conn.fetch(
                """
                SELECT id, content, topic,
                    1 - (embedding <=> $1) AS similarity
                FROM posts
                ORDER BY embedding <=> $1 DESC
                LIMIT $2
                """,
                embedding, limit,
            )
        return [dict(r) for r in rows]
    
    async def getNewSessionPosts(self, diversityTolerance: float, yesterdayPost: List[float], likedTopic: str):
        val = 1
        similarityTargets = []
        for i in range(4): # Retrieve 4 posts
            similarityTargets.append(val)
            val = max(0, val - diversityTolerance)

        results = []

        async with self.pool.acquire() as conn:
            for target in similarityTargets:
                post = await conn.fetchrow("""
                                            SELECT *, 1 - (embedding <=> $1::vector) AS similarity
                                            FROM posts
                                            WHERE topic = $2
                                            ORDER BY ABS((1 - (embedding <=> $1::vector)) - $3)
                                            LIMIT 1
                                        """,
                                        yesterdayPost,
                                        likedTopic,
                                        target)
                
                if post:
                    results.append(dict(post))
                
            return results
        
    async def getPostsByIds(self, ids: list):
        if not ids:
            return []
        
        async with self.pool.acquire() as conn:
            rows = await conn.fetch(
                """SELECT id, content, topic_id, created_at, user_id
                    FROM posts
                    WHERE id = ANY($1::uuid[])""",
                   ids,
            )
        
        return [dict(r) for r in rows]
    
    async def getRandomPosts(self, limit: int=10):
        async with self.pool.acquire() as conn:
            rows = await conn.fetch(
                """SELECT id, content, topic, created_at, user_id
                   FROM posts
                   ORDER BY RANDOM()
                   LIMIT $1""",
                   limit,
            )

        return [dict(r) for r in rows]

'''
Notes:
- The post embedding should be passed in, not the post itself (embedding again would be redundant)
- The "limit" parameter defines the max posts that will appear in the graph
- In pgvector, the <=> operator defines cosine similarity, NOT null-safe equality
'''