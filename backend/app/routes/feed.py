from fastapi import APIRouter, Depends
from app.services.feed import FeedService


def create_feed_router(feed_service: FeedService, get_current_user_id):
    router = APIRouter()

    @router.get("/me")
    async def get_my_feed(user_id: int = Depends(get_current_user_id)):
        return await feed_service.get_feed(user_id, q="")

    @router.get("/me/session")
    async def get_session_posts(user_id: int = Depends(get_current_user_id)):
        return await feed_service.get_new_session_posts(user_id)

    return router