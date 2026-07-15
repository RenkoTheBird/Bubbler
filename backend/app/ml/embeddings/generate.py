import threading

_MODEL_NAME = "sentence-transformers/all-MiniLM-L6-v2"
_model = None
_lock = threading.Lock()


def _get_model():
    """Load SentenceTransformer once per process (thread-safe)."""
    global _model
    if _model is None:
        with _lock:
            if _model is None:
                from sentence_transformers import SentenceTransformer

                # all-MiniLM-L6-v2 is a lightweight model for embeddings
                _model = SentenceTransformer(_MODEL_NAME)
    return _model


def preload_model() -> None:
    """Eagerly load weights so the first request is not a cold start."""
    _get_model()


def embed_many(texts: list[str]) -> list[list[float]]:
    """Batch-encode texts into embedding vectors."""
    if not texts:
        return []
    vectors = _get_model().encode(texts, show_progress_bar=False)
    return [vector.tolist() for vector in vectors]


def embed(post: str) -> list[float]:
    return embed_many([post])[0]
