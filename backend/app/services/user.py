class UserService:
    def __init__(self, user_repo):
        self.user_repo = user_repo
        
    async def get_profile_info(self):
        return await self.user_repo.get_profile_info()

    async def put_email(self, email, user_id):
        return await self.user_repo.put_email(email, user_id)