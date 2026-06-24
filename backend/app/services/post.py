from ....ml.embeddings.generate import embed


class EmbeddingService:
    def embed_text(self, post: str):
        return embed(post)


class PostService:
    def __init__(self, repo, EmbeddingService: EmbeddingService):
        self.repo = repo # post repo
        self.EmbeddingService = EmbeddingService

    async def get_user_posts(self):
        return await self.repo.get_user_posts()

    async def post_user_posts(self, user_id, post):
        embedded = self.EmbeddingService.embed_text(post)
        row = await self.repo.post_user_posts(user_id, post, embedded)
        await self.EdgeBuilderRepo.build_edges_for_post(row["id"], embedded)
        return row