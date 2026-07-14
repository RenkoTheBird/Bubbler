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

# Topics used for sample content (names must match topics.py).
# Enough posts per topic so similar / topic / opposite edges form a navigable graph.
SAMPLE_TOPICS = [
    "technology",
    "health",
    "business",
    "science",
    "politics",
    "entertainment",
    "sports",
    "education",
    "environment",
    "general",
]

SAMPLE_POSTS = [
    # technology — cluster around coding, AI, gadgets
    ("I love building side projects on weekends.", "technology"),
    ("Hot take: tabs over spaces in every codebase.", "technology"),
    ("Rust makes systems programming feel approachable again.", "technology"),
    ("Local LLMs are finally fast enough for daily coding help.", "technology"),
    ("Open source maintainers deserve more funding and less burnout.", "technology"),
    ("My mechanical keyboard clicks are a productivity placebo and I love it.", "technology"),
    ("Debugging distributed systems taught me to read logs before guessing.", "technology"),
    ("Smartphone cameras keep improving but battery life still lags.", "technology"),
    ("TypeScript saved our frontend from a mountain of runtime surprises.", "technology"),
    ("Self-hosting a few services taught me more than any cloud tutorial.", "technology"),
    # health — fitness, sleep, mental health, nutrition
    ("Morning runs clear my head before the workday starts.", "health"),
    ("Strength training three times a week changed my energy levels.", "health"),
    ("Sleep consistency matters more than the perfect bedtime routine.", "health"),
    ("Walking meetings are underrated for both focus and step counts.", "health"),
    ("Meal prep on Sundays keeps me from defaulting to takeout.", "health"),
    ("Meditation apps helped me notice stress earlier in the day.", "health"),
    ("Hydration sounds boring until afternoon headaches disappear.", "health"),
    ("Physical therapy after an injury taught me patience with progress.", "health"),
    ("Cold showers are overhyped but a short morning stretch is not.", "health"),
    ("Tracking mood alongside workouts revealed patterns I ignored.", "health"),
    # business — startups, markets, careers
    ("This startup idea needs real customer validation first.", "business"),
    ("Pricing is a product decision disguised as a finance problem.", "business"),
    ("Small teams move faster when meetings have written agendas.", "business"),
    ("Cash flow discipline beats vanity growth metrics every time.", "business"),
    ("Networking works better as helping people than collecting cards.", "business"),
    ("Remote-first companies still need intentional in-person rituals.", "business"),
    ("A clear ICP saves months of scattered marketing spend.", "business"),
    ("Founders who talk to users weekly ship more useful features.", "business"),
    ("Negotiating salary is a skill worth practicing before you need it.", "business"),
    ("Bootstrapping forces sharper prioritization than endless fundraising.", "business"),
    # science — research, space, biology, physics
    ("CRISPR therapies keep inching closer to everyday clinical use.", "science"),
    ("James Webb images still make me feel tiny in the best way.", "science"),
    ("Reproducibility crises mean we should celebrate careful null results.", "science"),
    ("Climate models are imperfect and still essential decision tools.", "science"),
    ("Citizen science projects prove curiosity is not just for labs.", "science"),
    ("mRNA platform research opened doors far beyond the first vaccines.", "science"),
    ("Quantum sensing may matter sooner than flashy quantum computers.", "science"),
    ("Ocean microbiology is wildly understudied relative to its impact.", "science"),
    ("Peer review is slow, but preprint culture needs better norms too.", "science"),
    ("Basic research funding is an investment in problems we cannot name yet.", "science"),
    # politics — civic, policy, institutions (non-partisan tone)
    ("Local elections shape daily life more than most national headlines.", "politics"),
    ("Public comment periods are underused by people who care about policy.", "politics"),
    ("Transparent budgeting builds more trust than polished slogans.", "politics"),
    ("Civic education should include how to read a bill summary.", "politics"),
    ("Ranked choice voting experiments are worth watching carefully.", "politics"),
    ("Infrastructure votes are boring until bridges and transit fail.", "politics"),
    ("Journalism literacy helps separate reporting from opinion packaging.", "politics"),
    ("Neighborhood associations can be more consequential than viral debates.", "politics"),
    ("Campaign finance disclosure should be easier for voters to parse.", "politics"),
    ("Diplomatic quiet work rarely trends but often prevents escalation.", "politics"),
    # entertainment — film, music, games, culture
    ("Mid-budget films with original scripts still hit hardest.", "entertainment"),
    ("Live concerts remind me why headphones never fully replace rooms.", "entertainment"),
    ("Indie games keep taking bigger creative risks than AAA sequels.", "entertainment"),
    ("A great soundtrack can rescue an otherwise average movie night.", "entertainment"),
    ("Long-form podcasts work when hosts actually listen to each other.", "entertainment"),
    ("Theater tickets feel expensive until the applause hits.", "entertainment"),
    ("Rewatching comfort shows is a valid form of rest, not laziness.", "entertainment"),
    ("Book-to-screen adaptations succeed when they respect tone, not every plot beat.", "entertainment"),
    ("Festival lineups are chaotic but discovering one new artist is enough.", "entertainment"),
    ("Co-op multiplayer nights are my favorite low-stakes social plan.", "entertainment"),
    # sports — training, fandom, recreation
    ("Watching soccer teaches patience for long build-ups and sudden chaos.", "sports"),
    ("Pickup basketball is still the best spontaneous social workout.", "sports"),
    ("Marathon training is mostly about not getting injured in month two.", "sports"),
    ("College athletics drama is often more compelling than the games.", "sports"),
    ("Climbing gyms turn fear management into a weekly habit.", "sports"),
    ("Analytics changed sports arguments but gut feel still owns the bar.", "sports"),
    ("Youth sports should prioritize fun before early specialization.", "sports"),
    ("Recovery days are training too, even if they feel like doing nothing.", "sports"),
    ("Olympics coverage makes obscure sports briefly mainstream and I love it.", "sports"),
    ("Cycling group rides taught me drafting etiquette the hard way.", "sports"),
    # education — learning, teaching, schools
    ("Office hours are the most underused resource on any campus.", "education"),
    ("Project-based learning sticks longer than memorizing for a single exam.", "education"),
    ("Teachers need planning time as much as they need new tech tools.", "education"),
    ("Study groups work when everyone arrives with a specific question.", "education"),
    ("Community colleges quietly open career doors without the prestige tax.", "education"),
    ("Feedback that is specific and timely beats vague praise every time.", "education"),
    ("Libraries remain the best free third space in most towns.", "education"),
    ("Learning in public with notes online accelerates mastery for me.", "education"),
    ("Curiosity is a skill schools can either protect or slowly sand down.", "education"),
    ("Apprenticeships deserve the same cultural status as four-year degrees.", "education"),
    # environment — climate, nature, conservation
    ("Native plant gardens beat lawns for birds, bees, and less mowing.", "environment"),
    ("Heat pumps are boring infrastructure that quietly cut emissions.", "environment"),
    ("Urban tree canopy is climate policy you can see from the sidewalk.", "environment"),
    ("Food waste reduction is climate action available in every kitchen.", "environment"),
    ("Wetland restoration pays for itself in flood protection over time.", "environment"),
    ("Reusable systems only win when they are more convenient than disposables.", "environment"),
    ("Trail maintenance volunteers keep public lands usable for everyone.", "environment"),
    ("Air quality alerts should change daily plans the way storms do.", "environment"),
    ("Circular design starts with repairability, not another recycling logo.", "environment"),
    ("Community solar projects make clean energy feel tangible locally.", "environment"),
    # general — everyday life, misc
    ("A short walk after lunch resets my afternoon better than coffee.", "general"),
    ("Keeping a simple notebook beats another productivity app for me.", "general"),
    ("Neighbors waving hello still counts as community infrastructure.", "general"),
    ("Cooking one new recipe a month is enough novelty without overwhelm.", "general"),
    ("Leaving my phone in another room made evenings feel longer again.", "general"),
    ("Saying no earlier is kinder than resentful yes later.", "general"),
    ("Public transit days make me notice a city differently than driving.", "general"),
    ("Handwritten thank-you notes still punch above their effort.", "general"),
    ("A tidy desk is optional but a clear tomorrow list is not.", "general"),
    ("Curiosity about ordinary things keeps life from going gray.", "general"),
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


async def _index_exists(conn: asyncpg.Connection, name: str) -> bool:
    return bool(
        await conn.fetchval(
            "SELECT EXISTS (SELECT 1 FROM pg_indexes WHERE indexname = $1)",
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

        # explore/skip may repeat; only likes stay unique per user+post.
        if await _constraint_exists(conn, "interactions_user_id_post_id_key"):
            await conn.execute(
                "ALTER TABLE interactions DROP CONSTRAINT interactions_user_id_post_id_key"
            )

        if not await _index_exists(conn, "interactions_user_id_post_id_like_uidx"):
            await conn.execute(
                """
                CREATE UNIQUE INDEX interactions_user_id_post_id_like_uidx
                ON interactions (user_id, post_id)
                WHERE type = 'like'
                """
            )

        # Allow bridge edges for cross-topic graph paths.
        edge_checks = await conn.fetch(
            """
            SELECT conname, pg_get_constraintdef(oid) AS def
            FROM pg_constraint
            WHERE conrelid = 'edges'::regclass
              AND contype = 'c'
              AND pg_get_constraintdef(oid) LIKE '%edge_type%'
            """
        )
        needs_bridge_constraint = True
        for row in edge_checks:
            if "bridge" in row["def"]:
                needs_bridge_constraint = False
            else:
                await conn.execute(
                    f'ALTER TABLE edges DROP CONSTRAINT IF EXISTS "{row["conname"]}"'
                )
                needs_bridge_constraint = True
        if needs_bridge_constraint:
            await conn.execute(
                """
                ALTER TABLE edges
                ADD CONSTRAINT edges_edge_type_check
                CHECK (edge_type IN ('similar', 'opposite', 'topic', 'bridge'))
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

        inserted: list[tuple[object, list[float]]] = []
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
            inserted.append((post_id, vector))
            print("Inserted post", post_id, f"topic={topic_name}")

        # Rebuild outbound edges after all inserts so early posts also get
        # similar / opposite / topic / bridge neighbors for graph exploration.
        print(f"Building edges for {len(inserted)} posts…")
        for post_id, vector in inserted:
            edges = await edge_builder_repo.build_edges_for_post(post_id, vector)
            print("Edges for", post_id, f"count={len(edges)}")

    await pool.close()
    print(f"Seeded {len(SAMPLE_POSTS)} posts across {len(SAMPLE_TOPICS)} topics.")


if __name__ == "__main__":
    asyncio.run(main())
