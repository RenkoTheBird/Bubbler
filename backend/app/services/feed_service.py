from ..repositories.feed_repo import FeedRepository

class FeedService:
    def __init__(self, repo: FeedRepository):
        self.repo = repo

    async def getSimilarPosts(self):
        return await self.repo.getSimilarPosts()
        # theoretically similarity choices/logic could go here
    
    async def getNewSessionPosts(self):
        return await self.repo.getNewSessionPosts()
    
    ### FUTURE: opposite posts, potential interesting topics, etc.
