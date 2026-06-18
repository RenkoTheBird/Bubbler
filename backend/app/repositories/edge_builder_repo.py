class EdgeBuilderRepo:

    @classmethod
    async def build_edges_for_post(cls, pool, embedding_service, post_id, embedding):
        async with pool.acquire() as conn:
            similar = await conn.fetch(
                """SELECT id, 1 - (embedding <=> $1) AS similarity
                   FROM posts
                   WHERE id != $2
                   ORDER BY embedding <=> $1
                   LIMIT 5""",
                embedding, post_id
            )

            for row in similar:
                await conn.execute(
                    """INSERT INTO edges (from_post_id, to_post_id, edge_type, weight)
                       VALUES ($1, $2, 'similar', $3)
                       ON CONFLICT DO NOTHING""",
                    post_id, row["id"], float(row["similarity"])
                )