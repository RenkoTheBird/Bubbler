from fastapi import APIRouter
from fastapi import Depends

router = APIRouter()

@router.get("/users{id}/posts")
def getPosts(service: PostService = Depends()):
    return service.getPosts()

@router.post("/users/{id}/posts")
def postPosts(service: PostService = Depends()):
    return service.postPosts()

