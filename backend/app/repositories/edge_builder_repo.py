class EdgeBuilderRepo:
    def __init__(self, pool, embeddingService):
        self.pool = pool
        self.embeddingService = embeddingService

    async def buildEdgesForPost(self, postId, embedding):
        async with self.pool.acquire() as conn:
            # Similar neighbors
            similar = await conn.fetch(
                """SELECT id, 1 - (embedding <=> $1) AS similarity
                   FROM posts
                   WHERE id != $2
                   ORDER BY embedding <=> $1
                   LIMIT 5""",
                   embedding, postId
            )

            for row in similar:
                await conn.execute(
                    """INSERT INTO edges (from_post_id, to_post_id, edge_type, weight)
                       VALUES ($1, $2, 'similar', $3)
                       ON CONFLICT DO NOTHING""",
                       postId, row["id"], float(row["similarity"])
                )