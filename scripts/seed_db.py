'''
Developer testing script
'''

import asyncio
import asyncpg
from ml.embeddings.generate import embed

SAMPLE_POSTS = [
    ("I love building side projects.", "tech"),
    ("Morning runs clear my head.", "health"),
    ("This startup idea needs validation.", "startups"),
    ("Hot take: tabs over spaces.", "tech"),
]

async def main():
    conn = await asyncpg.connect("postgresql://bubbler:bubbler@localhost:5432/bubbler")

    user_id = await conn.fetchval(
        """
        INSERT INTO users (username, email, password_hash)
        VALUES ('demo', 'demo@bubbler.test', 'not-a-real-hash')
        ON CONFLICT (email) DO UPDATE SET username = EXCLUDED.username
        RETURNING id
        """
    )

    for content, topic in SAMPLE_POSTS:
        vector = embed(content)
        post_id = await conn.fetchval(
            """
            INSERT INTO posts (user_id, content, topic, embedding)
            VALUES ($1, $2, $3, $4)
            RETURNING id
            """,
            user_id, content, topic, vector,
        )
        print("Inserted post", post_id)

    await conn.close()

if __name__ == "__main__":
    asyncio.run(main())