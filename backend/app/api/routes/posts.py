from fastapi import APIRouter, Depends
from ...services.post_service import PostService

router = APIRouter()

@router.get("/{id}/posts")
async def getUserPosts(id: str, service: PostService = Depends()):
    return service.getUserPosts(id)

@router.post("/{id}/posts")
def postUserPosts(id: str, service: PostService = Depends()):
    return service.postUserPosts(id)