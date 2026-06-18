from fastapi import APIRouter
from app.services.feed import FeedService


def create_feed_router(feed_service: FeedService):
    router = APIRouter()

    @router.get("/{id}/similar")
    async def get_feed(id: int):
        return await feed_service.getFeed(id, q="")

    @router.get("/{id}/session")
    async def get_new_session_posts(id: int):
        return await feed_service.getNewSessionPosts(id)

    return router