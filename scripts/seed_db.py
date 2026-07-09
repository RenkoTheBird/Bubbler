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


async def main():
    pool = await asyncpg.create_pool(my_env_vars.db_url)
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
