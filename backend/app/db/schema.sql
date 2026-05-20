---- NOTE: pgvector must be defined as an extension:
-- CREATE EXTENSION IF NOT EXISTS vector;

---- Critical for performance
-- CREATE INDEX ON posts
-- USING hnsw (embedding vector_cosine_ops);
-- hnsw is required for fast vector lookups