from fastapi import APIRouter
from app.services.user import UserService
from app.services.interaction import InteractionService
from app.services.post import PostService


def create_user_router(user_service: UserService, interaction_service: InteractionService, post_service: PostService):
    router = APIRouter()

    @router.get("/{id}/profile")
    async def get_profile_info(id: int):
        return await user_service.getProfileInfo(id)

    @router.put("/{id}/profile/email")
    async def put_email(id: int, email: str):
        return await user_service.putEmail(id)

    @router.get("/{id}")
    async def get_user_interactions(id: int):
        return await interaction_service.getUserInteractions(id)

    @router.get("/{id}/posts")
    async def get_user_posts(id: int):
        return await post_service.getUserPosts(id)

    @router.post("/{id}/posts")
    async def post_user_posts(id: int, post: str):
        return await post_service.postUserPosts(id)

    return router