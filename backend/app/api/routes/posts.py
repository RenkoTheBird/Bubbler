from fastapi import APIRouter, Depends
from ...services.post_service import PostService
from ..deps import getPostService

router = APIRouter()

@router.get("/{id}/posts")
async def getUserPosts(id: int, service: PostService = Depends(getPostService)):
    return service.getUserPosts(id)

@router.post("/{id}/posts")
def postUserPosts(id: int, post: str, service: PostService = Depends(getPostService)):
    return service.postUserPosts(id)