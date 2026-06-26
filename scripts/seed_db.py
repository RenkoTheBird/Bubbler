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
from backend.app.repositories.edge_builder_repo import EdgeBuilderRepo
from backend.app.services.post import EmbeddingService
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
    embedding_service = EmbeddingService()

    async with pool.acquire() as conn:
        user_id = await conn.fetchval(
            """
            INSERT INTO users (username, email, password_hash)
            VALUES ('demo', 'demo@bubbler.test', 'not-a-real-hash')
            ON CONFLICT (email) DO UPDATE SET username = EXCLUDED.username
            RETURNING id
            """
        )

        topic_ids = {}
        for name in SAMPLE_TOPICS:
            topic_id = await conn.fetchval(
                """
                INSERT INTO topics (name)
                VALUES ($1)
                ON CONFLICT (name) DO UPDATE SET name = EXCLUDED.name
                RETURNING id
                """,
                name,
            )
            topic_ids[name] = topic_id

        for content, topic_name in SAMPLE_POSTS:
            vector = embed(content)
            topic_id = topic_ids[topic_name]
            post_id = await conn.fetchval(
                """
                INSERT INTO posts (user_id, content, topic_id, embedding)
                VALUES ($1, $2, $3, $4)
                RETURNING id
                """,
                user_id, content, topic_id, to_pgvector(vector),
            )
            await edge_builder_repo.build_edges_for_post(
                embedding_service, post_id, to_pgvector(vector)
            )
            print("Inserted post", post_id)

    await pool.close()


if __name__ == "__main__":
    asyncio.run(main())
