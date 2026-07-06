from app.db.vector import to_pgvector

_EDGE_INSERT = """
    INSERT INTO edges (from_post_id, to_post_id, edge_type, weight)
    VALUES ($1, $2, $3, $4)
    ON CONFLICT (from_post_id, to_post_id, edge_type) DO NOTHING
"""

_SIMILAR_LIMIT = 5


class EdgeBuilderRepo:
    def __init__(self, pool):
        self.pool = pool

    async def build_edges_for_post(self, post_id, embedding):
        vec = to_pgvector(embedding)

        async with self.pool.acquire() as conn:
            similar = await conn.fetch(
                """SELECT id, 1 - (embedding <=> $1::vector) AS similarity
                   FROM posts
                   WHERE id != $2 AND embedding IS NOT NULL
                   ORDER BY embedding <=> $1::vector
                   LIMIT $3""",
                vec, post_id, _SIMILAR_LIMIT,
            )

            opposite = await conn.fetch(
                """SELECT id, 1 - (embedding <=> $1::vector) AS similarity
                   FROM posts
                   WHERE id != $2 AND embedding IS NOT NULL
                   ORDER BY embedding <=> $1::vector DESC
                   LIMIT $3""",
                vec, post_id, _SIMILAR_LIMIT,
            )

            topic_neighbors = await conn.fetch(
                """SELECT DISTINCT p.id, 1.0 AS weight
                   FROM post_topics pt_self
                   JOIN post_topics pt_peer ON pt_peer.topic_name = pt_self.topic_name
                   JOIN posts p ON p.id = pt_peer.post_id
                   WHERE pt_self.post_id = $1 AND p.id != $1
                   LIMIT $2""",
                post_id, _SIMILAR_LIMIT,
            )

            records = [
                (post_id, row["id"], "similar", float(row["similarity"]))
                for row in similar
            ]
            records.extend(
                (post_id, row["id"], "opposite", float(row["similarity"]))
                for row in opposite
            )
            records.extend(
                (post_id, row["id"], "topic", float(row["weight"]))
                for row in topic_neighbors
            )

            if records:
                await conn.executemany(_EDGE_INSERT, records)
