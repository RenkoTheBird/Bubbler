from app.db.conn import acquire_conn
from app.db.vector import to_pgvector
from app.schemas.edge import Edge

_EDGE_INSERT = """
    INSERT INTO edges (from_post_id, to_post_id, edge_type, weight)
    VALUES ($1, $2, $3, $4)
    ON CONFLICT (from_post_id, to_post_id, edge_type) DO NOTHING
"""

_SIMILAR_LIMIT = 5

# NOTE: named as similar_posts instead of similar as similar is a reserved word in PostgreSQL
_EDGES_QUERY = """
    WITH similar_posts AS (
        SELECT id, 1 - (embedding <=> $1::vector) AS similarity, 'similar' AS edge_type
        FROM posts
        WHERE id != $2 AND embedding IS NOT NULL
        ORDER BY embedding <=> $1::vector
        LIMIT $3
    ),
    opposite_posts AS (
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
    SELECT id, similarity, edge_type FROM similar_posts
    UNION ALL
    SELECT id, similarity, edge_type FROM opposite_posts
    UNION ALL
    SELECT id, similarity, edge_type FROM topic_neighbors
"""


class EdgeBuilderRepo:
    def __init__(self, pool):
        self.pool = pool

    @staticmethod
    def _map_edge(row) -> Edge:
        return Edge(
            id=str(row["id"]),
            from_post_id=str(row["from_post_id"]),
            to_post_id=str(row["to_post_id"]),
            type=row["edge_type"],
            weight=float(row["weight"]) if row["weight"] is not None else None,
        )

    async def build_edges_for_post(self, post_id, embedding, *, conn=None) -> list[Edge]:
        vec = to_pgvector(embedding)

        async with acquire_conn(self.pool, conn) as connection:
            # Drop outbound edges first so edits replace stale neighbors
            # instead of accumulating via ON CONFLICT DO NOTHING.
            await connection.execute(
                "DELETE FROM edges WHERE from_post_id = $1",
                post_id,
            )
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

            edge_rows = await connection.fetch(
                """
                SELECT id, from_post_id, to_post_id, edge_type, weight
                FROM edges
                WHERE from_post_id = $1
                """,
                post_id,
            )
            return [self._map_edge(row) for row in edge_rows]
