from ..repositories.user_repo import UserRepository

class UserService:
    def __init__(self, repo: UserRepository):
        self.repo = repo
    
    async def getProfileInfo(self):
        return await self.repo.getProfileInfo()

    async def putEmail(self):
        return await self.repo.putEmail()
    
