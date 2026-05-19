from sentence_transformers import SentenceTransformer

def embed(post):
    # all-MiniLM-L6-v2 is a lightweight model for embeddings
    model = SentenceTransformer("sentence-transformers/all-MiniLM-L6-v2")

    # these need to be passed from backend
    # assume embedding one post at a time
    embedding = model.encode(post)
    return embedding






