from fastapi import HTTPException

class UserService:
    def __init__(self, user_repo):
        self.user_repo = user_repo
        
    async def get_profile_info(self, user_id: int):
        profile = await self.user_repo.get_profile_info(user_id)
        if profile is None:
            raise HTTPException(status_code=404, detail="User not found")
        return profile

    async def put_email(self, email, user_id):
        updated = await self.user_repo.put_email(email, user_id)
        if updated is None:
            raise HTTPException(status_code=404, detail="User not found")
        return updated
    
    async def get_prefs(self, user_id):
        return await self.user_repo.get_prefs(user_id)
    
    async def put_prefs(self, user_id, body):
        return await self.user_repo.put_prefs(user_id, body)

    async def delete_user(self, user_id):
        result = await self.user_repo.delete_user(user_id)
        if not result:
            raise HTTPException(status_code=404, detail="User not found")
        return result