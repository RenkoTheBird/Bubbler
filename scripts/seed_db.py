'''
Developer testing script
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

from backend.config import my_env_vars
from backend.app.db.topics import DEFAULT_TOPIC
from backend.app.repositories.edge_builder_repo import EdgeBuilderRepo
from backend.app.ml.embeddings.generate import embed
from backend.app.db.vector import to_pgvector

SAMPLE_TOPICS = ["tech", "health", "startups"]

SAMPLE_POSTS = [
    ("I love building side projects.", "tech"),
    ("Morning runs clear my head.", "health"),
    ("This startup idea needs validation.", "startups"),
    ("Hot take: tabs over spaces.", "tech"),
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

        for name in [*SAMPLE_TOPICS, DEFAULT_TOPIC]:
            await conn.execute(
                """
                INSERT INTO topics (name)
                VALUES ($1)
                ON CONFLICT (name) DO NOTHING
                """,
                name,
            )

        for content, topic_name in SAMPLE_POSTS:
            vector = embed(content)
            post_id = await conn.fetchval(
                """
                INSERT INTO posts (user_id, content, embedding)
                VALUES ($1, $2, $3::vector)
                RETURNING id
                """,
                user_id, content, to_pgvector(vector),
            )
            await conn.execute(
                """
                INSERT INTO post_topics (post_id, topic_name, source, confidence)
                VALUES ($1, $2, 'user', 1.0)
                ON CONFLICT DO NOTHING
                """,
                post_id, topic_name,
            )
            await edge_builder_repo.build_edges_for_post(post_id, vector)
            print("Inserted post", post_id)

    await pool.close()


if __name__ == "__main__":
    asyncio.run(main())
