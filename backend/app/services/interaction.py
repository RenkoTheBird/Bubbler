from app.schemas.user import InteractionCreate

class InteractionService:
    def __init__(self, repo):
        self.repo = repo # interaction repo

    async def record(self, user_id: int, body: InteractionCreate):
        # extract necessary variables: user_id, post_id, type, view_time
        post_id = body.post_id
        type = body.type
        view_time = body.view_time
        return await self.repo.record(user_id, post_id, type, view_time)

    async def get_user_interactions(self, user_id: int):
        return await self.repo.get_recent_interactions(user_id)
    
