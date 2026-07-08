from app.ml.embeddings.generate import embed
from fastapi import HTTPException

class EmbeddingService:
    def embed_text(self, post: str):
        return embed(post)

class PostService:
    def __init__(self, repo, edge_builder_repo, EmbeddingService: EmbeddingService):
        self.repo = repo # post repo
        self.edge_builder_repo = edge_builder_repo
        self.EmbeddingService = EmbeddingService

    async def get_user_posts(self, user_id):
        return await self.repo.get_user_posts(user_id)

    async def post_user_posts(self, user_id, post):
        embedded = self.EmbeddingService.embed_text(post)
        return await self.repo.post_user_posts(
            user_id, post, embedded, edge_builder=self.edge_builder_repo,
        )

    async def edit_post(self, user_id, post_id, post):
        embedded = self.EmbeddingService.embed_text(post)
        result = await self.repo.edit_post(user_id, post_id, post, embedded)
        if not result:
            raise HTTPException(status_code=404, detail="Post not found")
        return result

    async def delete_post(self, user_id, post_id):
        result = await self.repo.delete_post(user_id, post_id)
        if not result:
            raise HTTPException(status_code=404, detail="Post not found")
        return result
