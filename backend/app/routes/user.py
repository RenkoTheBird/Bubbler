from fastapi import APIRouter, Depends
from app.services.user import UserService
from app.services.interaction import InteractionService
from app.services.post import PostService


def create_user_router(user_service: UserService, interaction_service: InteractionService, post_service: PostService, getCurrentUserId):
    router = APIRouter()

    @router.get("/me/profile")
    async def get_profile_info(user_id: int = Depends(getCurrentUserId)):
        return await user_service.getProfileInfo(user_id)

    @router.put("/me/profile/email")
    async def put_email(email: str, user_id: int = Depends(getCurrentUserId)):
        return await user_service.putEmail(user_id)

    @router.get("/me")
    async def get_user_interactions(user_id: int = Depends(getCurrentUserId)):
        return await interaction_service.getUserInteractions(id)

    @router.get("/me/posts")
    async def get_user_posts(user_id: int = Depends(getCurrentUserId)):
        return await post_service.getUserPosts(id)

    @router.post("/me/posts")
    async def post_user_posts(post: str, user_id: int = Depends(getCurrentUserId)):
        return await post_service.postUserPosts(id)

    return router