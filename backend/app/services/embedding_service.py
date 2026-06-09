from ....ml.embeddings.generate import embed

class EmbeddingService:

    def embedText(self, post: str):
        return embed(post)