class UserService:
    def __init__(self, user_repo):
        self.user_repo = user_repo
        
    async def getProfileInfo(self):
        return await self.repo.getProfileInfo()

    async def putEmail(self):
        return await self.repo.putEmail()