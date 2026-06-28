/* This schema is mostly for reference.
   Database will be hosted on supabase for now
   But this represents the general idea.
*/

-- Required extensions
CREATE EXTENSION IF NOT EXISTS vector;
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- USERS
CREATE TABLE users (
    id SERIAL PRIMARY KEY,
    username VARCHAR(20) NOT NULL,
    email VARCHAR(80) UNIQUE NOT NULL,
    password VARCHAR(60) NOT NULL,
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
    created_at TIMESTAMP DEFAULT NOW(),
    view_time FLOAT
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
    -- preferences (also in ALTER TABLE below)
    diversity_tolerance FLOAT CHECK (diversity_tolerance BETWEEN 0 AND 1),
    randomness FLOAT
);

ALTER TABLE user_profiles ADD COLUMN IF NOT EXISTS preferred_topics TEXT[] NOT NULL DEFAULT '{}';
ALTER TABLE user_profiles ADD COLUMN IF NOT EXISTS blacklisted_topics TEXT[] NOT NULL DEFAULT '{}';
ALTER TABLE user_profiles ADD COLUMN IF NOT EXISTS use_view_time BOOLEAN NOT NULL DEFAULT FALSE;
ALTER TABLE user_profiles ADD COLUMN IF NOT EXISTS view_time_weight FLOAT DEFAULT 0.1;
-- 
ALTER TABLE user_profiles ADD COLUMN IF NOT EXISTS strategy_weights JSONB NOT NULL DEFAULT 
'{"similar":0.7,"graph":0.2,"opposite":0.0,"random":0.1}';
--