-- Required extensions
CREATE EXTENSION IF NOT EXISTS vector;
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- USERS
CREATE TABLE users (
    id SERIAL PRIMARY KEY,
    username TEXT NOT NULL,
    email TEXT NOT NULL,
    password_hash TEXT NOT NULL,
    created_at TIMESTAMP DEFAULT NOW()
);

-- TOPICS
CREATE TABLE topics (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT UNIQUE,
    parent_topic_id UUID REFERENCES topics(id)
);

-- POSTS
CREATE TABLE posts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id INTEGER REFERENCES users(id),
    content TEXT NOT NULL,
    created_at TIMESTAMP DEFAULT NOW(),
    embedding vector(384),  
    topic_id UUID REFERENCES topics(id)
);

-- Vector index for similarity search
CREATE INDEX posts_embedding_idx
ON posts
USING hnsw (embedding vector_cosine_ops);

-- POST-TOPICS (many-to-many with weight)
CREATE TABLE post_topics (
    post_id UUID REFERENCES posts(id) ON DELETE CASCADE,
    topic_id UUID REFERENCES topics(id) ON DELETE CASCADE,
    weight FLOAT,
    PRIMARY KEY (post_id, topic_id)
);

-- INTERACTIONS
CREATE TABLE interactions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id INTEGER REFERENCES users(id),
    post_id UUID REFERENCES posts(id),
    type TEXT CHECK (type IN ('like', 'skip', 'explore')),
    created_at TIMESTAMP DEFAULT NOW()
);

-- EDGES (post graph)
CREATE TABLE edges (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    from_post_id UUID REFERENCES posts(id),
    to_post_id UUID REFERENCES posts(id),
    edge_type TEXT CHECK (edge_type IN ('similar', 'opposite', 'topic')),
    weight FLOAT
);

-- USER PROFILES (vector preferences)
CREATE TABLE user_profiles (
    user_id INTEGER PRIMARY KEY REFERENCES users(id),
    embedding vector,
    diversity_tolerance FLOAT CHECK (diversity_tolerance BETWEEN 0 AND 1),
    randomness FLOAT
);