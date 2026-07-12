'''
Developer testing script — seeds topics, posts (with post_topics), and edges.
'''

import asyncio
import sys
from pathlib import Path

import asyncpg
from dotenv import load_dotenv

BACKEND_ROOT = Path(__file__).resolve().parent.parent / "backend"
ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(BACKEND_ROOT))
sys.path.insert(0, str(ROOT))

load_dotenv(BACKEND_ROOT / ".env")

from config import my_env_vars  # noqa: E402
from app.db.topics import DEFAULT_TOPIC, KNOWN_TOPICS  # noqa: E402
from app.repositories.edge_builder_repo import EdgeBuilderRepo  # noqa: E402
from app.ml.embeddings.generate import embed  # noqa: E402
from app.db.vector import to_pgvector  # noqa: E402

# Subset of KNOWN_TOPICS used for sample content (names must match topics.py).
SAMPLE_TOPICS = ["technology", "health", "business"]

SAMPLE_POSTS = [
    ("I love building side projects.", "technology"),
    ("Morning runs clear my head.", "health"),
    ("This startup idea needs validation.", "business"),
    ("Hot take: tabs over spaces.", "technology"),
]


async def _column_exists(conn: asyncpg.Connection, table: str, column: str) -> bool:
    return bool(
        await conn.fetchval(
            """
            SELECT EXISTS (
                SELECT 1
                FROM information_schema.columns
                WHERE table_schema = 'public'
                  AND table_name = $1
                  AND column_name = $2
            )
            """,
            table,
            column,
        )
    )


async def _table_exists(conn: asyncpg.Connection, table: str) -> bool:
    return bool(
        await conn.fetchval(
            """
            SELECT EXISTS (
                SELECT 1
                FROM information_schema.tables
                WHERE table_schema = 'public'
                  AND table_name = $1
            )
            """,
            table,
        )
    )


async def _constraint_exists(conn: asyncpg.Connection, name: str) -> bool:
    return bool(
        await conn.fetchval(
            "SELECT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = $1)",
            name,
        )
    )


async def ensure_schema(pool: asyncpg.Pool) -> None:
    """Align a local dev database with backend/app/db/schema.sql before seeding."""
    async with pool.acquire() as conn:
        await conn.execute("CREATE EXTENSION IF NOT EXISTS vector")
        await conn.execute("CREATE EXTENSION IF NOT EXISTS pgcrypto")

        if not await _column_exists(conn, "topics", "embedding"):
            await conn.execute("ALTER TABLE topics ADD COLUMN embedding vector(384)")

        if not await _column_exists(conn, "post_topics", "source"):
            await conn.execute("ALTER TABLE post_topics ADD COLUMN source TEXT")
            await conn.execute(
                "UPDATE post_topics SET source = 'user' WHERE source IS NULL"
            )
            await conn.execute(
                "ALTER TABLE post_topics ALTER COLUMN source SET NOT NULL"
            )

        if not await _column_exists(conn, "post_topics", "confidence"):
            await conn.execute("ALTER TABLE post_topics ADD COLUMN confidence FLOAT")
            await conn.execute(
                "UPDATE post_topics SET confidence = 1.0 WHERE confidence IS NULL"
            )
            await conn.execute(
                "ALTER TABLE post_topics ALTER COLUMN confidence SET NOT NULL"
            )

        if not await _constraint_exists(conn, "post_topics_source_check"):
            await conn.execute(
                """
                ALTER TABLE post_topics
                ADD CONSTRAINT post_topics_source_check
                CHECK (source IN ('user', 'ai'))
                """
            )

        if not await _constraint_exists(conn, "post_topics_confidence_check"):
            await conn.execute(
                """
                ALTER TABLE post_topics
                ADD CONSTRAINT post_topics_confidence_check
                CHECK (confidence BETWEEN 0 AND 1)
                """
            )

        if not await _table_exists(conn, "topic_training_events"):
            await conn.execute(
                """
                CREATE TABLE topic_training_events (
                    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
                    post_id UUID NOT NULL REFERENCES posts(id) ON DELETE CASCADE,
                    user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
                    topic_name TEXT NOT NULL REFERENCES topics(name)
                        ON UPDATE CASCADE ON DELETE RESTRICT,
                    action TEXT NOT NULL CHECK (action IN ('add', 'remove')),
                    created_at TIMESTAMP DEFAULT NOW()
                )
                """
            )
            await conn.execute(
                """
                CREATE INDEX topic_training_events_post_id_idx
                ON topic_training_events (post_id)
                """
            )
            await conn.execute(
                """
                CREATE INDEX topic_training_events_user_id_idx
                ON topic_training_events (user_id)
                """
            )
            await conn.execute(
                """
                CREATE INDEX topic_training_events_topic_name_idx
                ON topic_training_events (topic_name)
                """
            )

        if not await _column_exists(conn, "user_profiles", "ai_topic_detection"):
            await conn.execute(
                """
                ALTER TABLE user_profiles
                ADD COLUMN ai_topic_detection BOOLEAN NOT NULL DEFAULT FALSE
                """
            )

        if not await _column_exists(conn, "user_profiles", "use_recency"):
            await conn.execute(
                """
                ALTER TABLE user_profiles
                ADD COLUMN use_recency BOOLEAN NOT NULL DEFAULT TRUE
                """
            )


async def main():
    pool = await asyncpg.create_pool(my_env_vars.db_url)
    await ensure_schema(pool)
    edge_builder_repo = EdgeBuilderRepo(pool)

    async with pool.acquire() as conn:
        user_id = await conn.fetchval(
            """
            INSERT INTO users (username, email, password)
            VALUES ('demo', 'demo@bubbler.test', 'not-a-real-hash')
            ON CONFLICT (email_lower) DO UPDATE SET username = EXCLUDED.username
            RETURNING id
            """
        )

        await conn.execute(
            """
            INSERT INTO user_profiles (user_id)
            VALUES ($1)
            ON CONFLICT (user_id) DO NOTHING
            """,
            user_id,
        )

        for name in sorted({*SAMPLE_TOPICS, DEFAULT_TOPIC, *KNOWN_TOPICS}):
            topic_vector = to_pgvector(embed(name))
            await conn.execute(
                """
                INSERT INTO topics (name, embedding)
                VALUES ($1, $2::vector)
                ON CONFLICT (name) DO UPDATE
                SET embedding = COALESCE(topics.embedding, EXCLUDED.embedding)
                """,
                name,
                topic_vector,
            )

        for content, topic_name in SAMPLE_POSTS:
            vector = embed(content)
            post_id = await conn.fetchval(
                """
                INSERT INTO posts (user_id, content, embedding)
                VALUES ($1, $2, $3::vector)
                RETURNING id
                """,
                user_id,
                content,
                to_pgvector(vector),
            )
            await conn.execute(
                """
                INSERT INTO post_topics (post_id, topic_name, source, confidence, weight)
                VALUES ($1, $2, 'user', 1.0, 1.0)
                ON CONFLICT DO NOTHING
                """,
                post_id,
                topic_name,
            )
            await edge_builder_repo.build_edges_for_post(post_id, vector)
            print("Inserted post", post_id, f"topic={topic_name}")

    await pool.close()


if __name__ == "__main__":
    asyncio.run(main())
