from fastapi import APIRouter, Depends, HTTPException
from app.services.user import UserService
from app.services.interaction import InteractionService
from app.services.post import PostService
from app.schemas.post import InteractionCreate, PostCreate, PostTopicMutation, PostUpdate
from app.schemas.user import EmailUpdate, PrefsUpdate
from app.db.topics import KNOWN_TOPICS


def create_user_router(user_service: UserService, interaction_service: InteractionService, post_service: PostService, get_current_user_id):
    router = APIRouter()

    @router.get("/me/profile")
    async def get_profile_info(user_id: int = Depends(get_current_user_id)):
        return await user_service.get_profile_info(user_id)

    @router.put("/me/profile/email")
    async def put_email(body: EmailUpdate, user_id: int = Depends(get_current_user_id)):
        return await user_service.put_email(body.email, user_id)

    @router.get("/me")
    async def get_user_interactions(user_id: int = Depends(get_current_user_id)):
        return await interaction_service.get_user_interactions(user_id)

    @router.get("/me/posts")
    async def get_user_posts(user_id: int = Depends(get_current_user_id)):
        return await post_service.get_user_posts(user_id)

    @router.put("/me/posts/{post_id}")
    async def edit_post(post_id: str, body: PostUpdate, user_id: int = Depends(get_current_user_id)):
        return await post_service.edit_post(user_id, post_id, body.post)

    @router.post("/me/posts/{post_id}/topics")
    async def add_post_topic(
        post_id: str,
        body: PostTopicMutation,
        user_id: int = Depends(get_current_user_id),
    ):
        normalized = body.topic.strip().lower()
        if normalized not in KNOWN_TOPICS:
            raise HTTPException(status_code=422, detail=f"Unknown topic: {body.topic}")
        return await post_service.add_post_topic(user_id, post_id, normalized)

    @router.delete("/me/posts/{post_id}/topics/{topic_name}")
    async def remove_post_topic(
        post_id: str,
        topic_name: str,
        user_id: int = Depends(get_current_user_id),
    ):
        normalized = topic_name.strip().lower()
        if normalized not in KNOWN_TOPICS:
            raise HTTPException(status_code=422, detail=f"Unknown topic: {topic_name}")
        return await post_service.remove_post_topic(user_id, post_id, normalized)

    @router.post("/me/posts")
    async def post_user_posts(
        body: PostCreate,
        user_id: int = Depends(get_current_user_id),
    ):
        normalized_topic = None
        if body.topic is not None:
            normalized = body.topic.strip().lower()
            if normalized not in KNOWN_TOPICS:
                raise HTTPException(status_code=422, detail=f"Unknown topic: {body.topic}")
            normalized_topic = normalized
        return await post_service.post_user_posts(user_id, body.post, topic=normalized_topic)
    
    @router.post("/me/interactions")
    async def record_interaction(body: InteractionCreate, user_id: int = Depends(get_current_user_id)):
        return await interaction_service.record(user_id, body)

    @router.get("/me/preferences")
    async def get_preferences(user_id: int = Depends(get_current_user_id)):
        return await user_service.get_prefs(user_id)

    @router.put("/me/preferences")
    async def put_preferences(body: PrefsUpdate, user_id: int = Depends(get_current_user_id)):
        return await user_service.put_prefs(user_id, body)

    @router.delete("/me/posts/{post_id}", status_code=204)
    async def delete_post(post_id: str, user_id: int = Depends(get_current_user_id)):
        return await post_service.delete_post(user_id, post_id)

    @router.delete("/me", status_code=204)
    async def delete_user(user_id: int = Depends(get_current_user_id)):
        return await user_service.delete_user(user_id)

    return router