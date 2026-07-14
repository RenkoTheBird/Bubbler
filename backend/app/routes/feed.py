from fastapi import APIRouter, Depends, Query
from app.services.feed import FeedService


def create_feed_router(feed_service: FeedService, get_current_user_id):
    router = APIRouter()

    @router.get("/me")
    async def get_my_feed(
        user_id: int = Depends(get_current_user_id),
        q: str | None = Query(
            default=None,
            max_length=200,
            description="Optional search text; embeds to seed similar/opposite candidates",
        ),
    ):
        return await feed_service.get_feed(user_id, q or "")

    @router.get("/me/session")
    async def get_session_posts(
        user_id: int = Depends(get_current_user_id),
        diversify: bool = Query(
            default=False,
            description="Escape the current topic region and force a cross-topic session",
        ),
    ):
        return await feed_service.get_new_session_posts(user_id, diversify=diversify)

    return router
