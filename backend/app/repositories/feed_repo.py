from typing import List
from ..db.base import pool

class FeedRepository:

    async def getSimilarPosts(self, embeddedPost: List[float], limit: int = 4):

        async with pool.acquire() as conn:
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
    
    async def getNewSessionPosts(self, diversityTolerance: float, yesterdayPost: List[float], likedTopic: str):
        val = 1
        similarityTargets = []
        for i in range(4): # Retrieve 4 posts
            similarityTargets.append(val)
            val = max(0, val - diversityTolerance)

        results = []

        async with pool.acquire() as conn:
            for target in similarityTargets:
                post = await conn.fetchrow("""
                                            SELECT *
                                                1 - (embedding <=> $1::vector) AS similarity
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

'''
Notes:
- The post embedding should be passed in, not the post itself (embedding again would be redundant)
- The "limit" parameter defines the max posts that will appear in the graph
- In pgvector, the <=> operator defines cosine similarity, NOT null-safe equality
'''