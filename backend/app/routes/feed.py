from fastapi import APIRouter
from app.services.feed_service import FeedService


def create_feed_router(feed_service: FeedService):
    router = APIRouter()

    @router.get("/{id}/similar")
    async def get_feed(id: int):
        return await feed_service.get_feed(id)

    @router.get("/{id}/session")
    async def get_new_session_posts(id: int):
        return await feed_service.get_new_session_posts(id)

    return router