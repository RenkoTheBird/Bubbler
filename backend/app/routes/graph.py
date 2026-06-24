from fastapi import APIRouter, Depends
from app.services.feed import FeedService

def create_graph_router(feed_service: FeedService, getCurrentUserId):
    router = APIRouter()

    @router.get("posts/{post_id}/next")
    async def get_next_posts(post_id: str, user_id: int = Depends(getCurrentUserId)):
        return await feed_service.get_next_posts(post_id) 