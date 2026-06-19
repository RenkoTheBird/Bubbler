from ..schemas.post import Interaction

class InteractionRepository:
    def __init__(self, pool):
        self.pool = pool

    async def record(self, user_id: int, post_id: str, type: str, view_time: float = 0):
        pass

    async def get_recent_interactions(self, user_id: int, limit: int = 50):
        pass