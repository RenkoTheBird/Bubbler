from ..repositories.user_repo import UserRepository

class UserService:
    def __init__(self, repo: UserRepository):
        self.repo = repo
    
    async def getProfileInfo(self):
        return await self.repo.getProfileInfo()
    
    async def getUserPosts(self):
        return await self.repo.getPosts()
        # ranking/filtering skipped because the database calls do that
    
    async def postUserPosts(self):
        return await self.repo.postPosts()

    async def putEmail(self):
        return await self.repo.putEmail()
    
