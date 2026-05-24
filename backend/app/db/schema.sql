---- NOTE: pgvector must be defined as an extension:
-- CREATE EXTENSION IF NOT EXISTS vector;

---- Critical for performance
-- CREATE INDEX ON posts
-- USING hnsw (embedding vector_cosine_ops);
-- hnsw is required for fast vector lookups

CREATE EXTENSION IF NOT EXISTS vector;
CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE TABLE users (
    id UUID NOT NULL,
    email TEXT NOT NULL,
    created_at DATETIME GETDATE()
);

CREATE TABLE topics (
    id UUID NOT NULL gen_random_uuid(),
    name TEXT,
    parent_topic_id INTEGER
);

CREATE TABLE posts (
    id UUID NOT NULL gen_random_uuid(),
    user_id INTEGER SERIAL,
    content TEXT NOT NULL,
    created_at DATETIME GETDATE(),
    embedding(vector), -- ml.embeddings.generate
    topic TEXT REFERENCES topics(name)
)

CREATE INDEX ON posts
USING hnsw (embedding vector_cosine_ops);

CREATE TABLE post_topics (
    post_id UUID REFERENCES posts(id),
    topic_id INTEGER,
    weight 
);

CREATE TABLE interactions (
    id UUID NOT NULL gen_random_uuid(),
    user_id UUID REFERENCES users(id),
    post_id UUID REFERENCES posts(id),
    type, -- like, skip, explore
    created_at DATETIME GETDATE()
);

CREATE TABLE edges (
    id UUID NOT NULL gen_random_uuid(),
    from_post_id REFERENCES posts(id),
    to_post_id REFERENCES posts(id),
    edge_type -- similar, opposite, topic
    weight
);

-- vectorized preferences
CREATE TABLE user_profiles (
    user_id REFERENCES users(id),
    embedding,
    diversity_tolerance INTEGER -- set by users! between 0-65
);


