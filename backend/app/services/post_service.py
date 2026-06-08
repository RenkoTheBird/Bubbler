from ..repositories.post_repo import PostRepository
from .embedding_service import EmbeddingService

class PostService:
    def __init__(self, repo: PostRepository, EmbeddingService: EmbeddingService):
        self.repo = repo
        self.EmbeddingService = EmbeddingService

    async def getUserPosts(self):
        return await self.repo.getUserPosts()
        # ranking/filtering skipped because the database calls do that - 
    
    async def postUserPosts(self, id, post):
        embedded = EmbeddingService.embed_text(post)
        return await self.repo.postUserPosts(id, post, embedded)