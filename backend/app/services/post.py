from ....ml.embeddings.generate import embed


class EmbeddingService:
    def embedText(self, post: str):
        return embed(post)


class PostService:
    def __init__(self, repo, EmbeddingService: EmbeddingService):
        self.repo = repo # post repo
        self.EmbeddingService = EmbeddingService

    async def getUserPosts(self):
        return await self.repo.getUserPosts()

    async def postUserPosts(self, id, post):
        embedded = EmbeddingService.embedText(post)
        row = await self.repo.postUserPosts(id, post, embedded)
        self.EdgeBuilderRepo.build_edges_for_post(row["id"], embedded)
        return row