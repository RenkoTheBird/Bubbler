_MODEL_NAME = "sentence-transformers/all-MiniLM-L6-v2"
_model = None


def _get_model():
    """Lazy-load SentenceTransformer so import/startup stays cheap."""
    global _model
    if _model is None:
        from sentence_transformers import SentenceTransformer

        # all-MiniLM-L6-v2 is a lightweight model for embeddings
        _model = SentenceTransformer(_MODEL_NAME)
    return _model


def embed(post):
    # these need to be passed from backend
    # assume embedding one post at a time
    return _get_model().encode(post).tolist()
