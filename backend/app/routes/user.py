from fastapi import APIRouter, Depends
from app.services.user import UserService
from app.services.interaction import InteractionService
from app.services.post import PostService
from app.schemas.post import InteractionCreate


def create_user_router(user_service: UserService, interaction_service: InteractionService, post_service: PostService, get_current_user_id):
    router = APIRouter()

    @router.get("/me/profile")
    async def get_profile_info(user_id: int = Depends(get_current_user_id)):
        return await user_service.get_profile_info(user_id)

    @router.put("/me/profile/email")
    async def put_email(email: str, user_id: int = Depends(get_current_user_id)):
        return await user_service.put_email(user_id)

    @router.get("/me")
    async def get_user_interactions(user_id: int = Depends(get_current_user_id)):
        return await interaction_service.get_user_interactions(user_id)

    @router.get("/me/posts")
    async def get_user_posts(user_id: int = Depends(get_current_user_id)):
        return await post_service.get_user_posts(user_id)

    @router.post("/me/posts")
    async def post_user_posts(post: str, user_id: int = Depends(get_current_user_id)):
        return await post_service.post_user_posts(user_id, post)
    
    @router.post("/me/interactions")
    async def record_interaction(body: InteractionCreate, user_id: int = Depends(get_current_user_id)):
        return await interaction_service.record(user_id, body)

    return router