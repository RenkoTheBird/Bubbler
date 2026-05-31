from ..repositories.post_repo import PostRepository
from ml.embeddings.generate import embed

class PostService:
    def __init__(self, repo: PostRepository):
        self.repo = repo

    async def getUserPosts(self):
        return await self.repo.getUserPosts()
        # ranking/filtering skipped because the database calls do that - 
        # but make sure to embed the post!
    
    async def postUserPosts(self):
        return await self.repo.postUserPosts()