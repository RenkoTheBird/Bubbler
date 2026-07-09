/* Reference schema for Bubbler. */

-- Required extensions
CREATE EXTENSION IF NOT EXISTS vector;
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- USERS
CREATE TABLE users (
    id SERIAL PRIMARY KEY,
    username VARCHAR(20) NOT NULL,
    email VARCHAR(80) NOT NULL,
    password VARCHAR(60) NOT NULL,
    email_lower TEXT GENERATED ALWAYS AS (lower(email)) STORED,
    username_lower TEXT GENERATED ALWAYS AS (lower(username)) STORED,
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE UNIQUE INDEX users_email_lower_idx ON users (email_lower);
CREATE UNIQUE INDEX users_username_lower_idx ON users (username_lower);

-- TOPICS (name stored canonical lowercase)
CREATE TABLE topics (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL UNIQUE,
    parent_topic_id UUID REFERENCES topics(id) ON DELETE SET NULL
);

-- POSTS
CREATE TABLE posts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id INTEGER REFERENCES users(id) ON DELETE CASCADE,
    content TEXT NOT NULL,
    created_at TIMESTAMP DEFAULT NOW(),
    embedding vector(384)
);

CREATE INDEX posts_user_id_idx ON posts (user_id);

CREATE INDEX posts_embedding_idx
ON posts
USING hnsw (embedding vector_cosine_ops);

-- POST-TOPICS (every post has >= 1 row; names resolve without joining topics)
CREATE TABLE post_topics (
    post_id UUID NOT NULL REFERENCES posts(id) ON DELETE CASCADE,
    topic_name TEXT NOT NULL REFERENCES topics(name) ON UPDATE CASCADE ON DELETE RESTRICT,
    source TEXT NOT NULL CHECK (source IN ('user', 'ai')),
    confidence FLOAT NOT NULL CHECK (confidence BETWEEN 0 AND 1), --only necessary for ai sources
    weight FLOAT NOT NULL DEFAULT 1.0,
    PRIMARY KEY (post_id, topic_name)
);

CREATE INDEX post_topics_topic_name_idx ON post_topics (topic_name);

-- Denormalized post row with highest-weight topic (see feed_sql.py)
CREATE VIEW posts_with_topic AS
SELECT
    p.id,
    p.content,
    p.created_at,
    p.user_id,
    p.embedding,
    pt.topic
FROM posts p
LEFT JOIN LATERAL (
    SELECT topic_name AS topic
    FROM post_topics
    WHERE post_id = p.id
    ORDER BY weight DESC
    LIMIT 1
) pt ON true;

-- INTERACTIONS
CREATE TABLE interactions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    post_id UUID NOT NULL REFERENCES posts(id) ON DELETE CASCADE,
    type TEXT NOT NULL CHECK (type IN ('like', 'skip', 'explore')),
    created_at TIMESTAMP DEFAULT NOW(),
    view_time FLOAT,
    UNIQUE (user_id, post_id)
);

CREATE INDEX interactions_user_id_created_at_idx ON interactions (user_id, created_at DESC);

-- EDGES (post graph)
CREATE TABLE edges (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    from_post_id UUID NOT NULL REFERENCES posts(id) ON DELETE CASCADE,
    to_post_id UUID NOT NULL REFERENCES posts(id) ON DELETE CASCADE,
    edge_type TEXT NOT NULL CHECK (edge_type IN ('similar', 'opposite', 'topic')),
    weight FLOAT,
    UNIQUE (from_post_id, to_post_id, edge_type)
);

CREATE INDEX edges_from_post_id_idx ON edges (from_post_id);

-- USER PROFILES (vector preferences)
CREATE TABLE user_profiles (
    user_id INTEGER PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
    diversity_tolerance FLOAT CHECK (diversity_tolerance BETWEEN 0 AND 1),
    randomness FLOAT,
    use_view_time BOOLEAN NOT NULL DEFAULT FALSE,
    view_time_weight FLOAT DEFAULT 0.1,
    ai_topic_detection BOOLEAN NOT NULL DEFAULT FALSE,
    strategy_weights JSONB NOT NULL DEFAULT
        '{"similar":0.7,"graph":0.2,"opposite":0.0,"random":0.1}'
);

-- USER TOPIC PREFERENCES (normalized; replaces preferred_topics/blacklisted_topics arrays)
CREATE TABLE user_topic_prefs (
    user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    topic_id UUID NOT NULL REFERENCES topics(id) ON DELETE CASCADE,
    preference_type TEXT NOT NULL CHECK (preference_type IN ('preferred', 'blacklisted')),
    PRIMARY KEY (user_id, topic_id)
);
