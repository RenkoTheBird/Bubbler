from ..repositories.post_repo import PostRepository
from ml.embeddings.generate import embed

class PostService:
    def __init__(self, repo: PostRepository):
        self.repo = repo

    async def getUserPosts(self):
        return await self.repo.getUserPosts()
        # ranking/filtering skipped because the database calls do that - 
    
    async def postUserPosts(self, id, post):
        embedded = embed(post)
        return await self.repo.postUserPosts(id, post, embedded)