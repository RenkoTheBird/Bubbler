from app.schemas.post import FeedPreferenceUpdate, InteractionCreate

class InteractionService:
    def __init__(self, repo):
        self.repo = repo # interaction repo

    async def record(self, user_id: int, body: InteractionCreate):
        post_id = body.post_id
        type = body.type
        view_time = body.view_time
        return await self.repo.record(user_id, post_id, type, view_time)

    async def set_feed_preference(
        self, user_id: int, post_id: str, body: FeedPreferenceUpdate, *, view_time: float = 0.0
    ) -> None:
        await self.repo.set_feed_preference(
            user_id,
            post_id,
            body.feed_preference,
            view_time=view_time,
        )

    async def get_user_interactions(self, user_id: int, limit: int = 20):
        # Cap profile trail loads so a heavy interaction history can't flood the client.
        return await self.repo.get_recent_interactions(user_id, limit=limit)

    async def get_feed_preferences(self, user_id: int):
        return await self.repo.get_feed_preferences(user_id)
