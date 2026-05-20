from sentence_transformers import SentenceTransformer

# all-MiniLM-L6-v2 is a lightweight model for embeddings
model = SentenceTransformer("sentence-transformers/all-MiniLM-L6-v2")

def embed(post):

    # these need to be passed from backend
    # assume embedding one post at a time
    return model.encode(post).tolist()
    






