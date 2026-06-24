class UserService:
    def __init__(self, user_repo):
        self.user_repo = user_repo
        
    async def get_profile_info(self):
        return await self.repo.get_profile_info()

    async def put_email(self):
        return await self.repo.put_email()