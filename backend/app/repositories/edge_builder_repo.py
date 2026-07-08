from app.db.vector import to_pgvector

_EDGE_INSERT = """
    INSERT INTO edges (from_post_id, to_post_id, edge_type, weight)
    VALUES ($1, $2, $3, $4)
    ON CONFLICT (from_post_id, to_post_id, edge_type) DO NOTHING
"""

_SIMILAR_LIMIT = 5

_EDGES_QUERY = """
    WITH similar AS (
        SELECT id, 1 - (embedding <=> $1::vector) AS similarity, 'similar' AS edge_type
        FROM posts
        WHERE id != $2 AND embedding IS NOT NULL
        ORDER BY embedding <=> $1::vector
        LIMIT $3
    ),
    opposite AS (
        SELECT id, 1 - (embedding <=> $1::vector) AS similarity, 'opposite' AS edge_type
        FROM posts
        WHERE id != $2 AND embedding IS NOT NULL
        ORDER BY embedding <=> $1::vector DESC
        LIMIT $3
    ),
    topic_neighbors AS (
        SELECT DISTINCT p.id, 1.0 AS similarity, 'topic' AS edge_type
        FROM post_topics pt_self
        JOIN post_topics pt_peer ON pt_peer.topic_name = pt_self.topic_name
        JOIN posts p ON p.id = pt_peer.post_id
        WHERE pt_self.post_id = $2 AND p.id != $2
        LIMIT $3
    )
    SELECT id, similarity, edge_type FROM similar
    UNION ALL
    SELECT id, similarity, edge_type FROM opposite
    UNION ALL
    SELECT id, similarity, edge_type FROM topic_neighbors
"""


class EdgeBuilderRepo:
    def __init__(self, pool):
        self.pool = pool

    async def build_edges_for_post(self, post_id, embedding, *, conn=None):
        vec = to_pgvector(embedding)

        async def _run(connection):
            rows = await connection.fetch(
                _EDGES_QUERY,
                vec, post_id, _SIMILAR_LIMIT,
            )
            records = [
                (post_id, row["id"], row["edge_type"], float(row["similarity"]))
                for row in rows
            ]
            if records:
                await connection.executemany(_EDGE_INSERT, records)

        if conn is not None:
            await _run(conn)
            return

        async with self.pool.acquire() as conn:
            await _run(conn)
