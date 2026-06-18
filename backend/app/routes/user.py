from fastapi import APIRouter
from app.services.user_service import UserService
from app.services.interaction_service import InteractionService
from app.services.post_service import PostService


def create_user_router(user_service: UserService, interaction_service: InteractionService, post_service: PostService):
    router = APIRouter()

    @router.get("/{id}/profile")
    async def get_profile_info(id: int):
        return await user_service.get_profile_info(id)

    @router.put("/{id}/profile/email")
    async def put_email(id: int, email: str):
        return await user_service.put_email(id)

    @router.get("/{id}")
    async def get_user_interactions(id: int):
        return await interaction_service.get_user_interactions(id)

    @router.get("/{id}/posts")
    async def get_user_posts(id: int):
        return await post_service.get_user_posts(id)

    @router.post("/{id}/posts")
    async def post_user_posts(id: int, post: str):
        return await post_service.post_user_posts(id)

    return router