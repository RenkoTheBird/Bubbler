from ....ml.embeddings.generate import embed

class EmbeddingService:

    def embed_text(self, post: str):
        return embed(post)