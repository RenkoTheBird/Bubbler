from fastapi import APIRouter, Depends, Query

from app.services.search import SearchService


def create_search_router(search_service: SearchService, get_current_user_id):
    router = APIRouter()

    @router.get("/search")
    async def search_posts(
        user_id: int = Depends(get_current_user_id),
        q: str = Query(
            ...,
            min_length=1,
            max_length=200,
            description=(
                "Hybrid search: tsvector keyword/topic/username hits first, "
                "then embedding-similar related posts"
            ),
        ),
    ):
        return await search_service.search(user_id, q)

    return router
