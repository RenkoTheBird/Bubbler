from fastapi import APIRouter, Depends

@router.get("posts/similar")
def getSimilarPosts(service: FeedService = Depends()):
    return service.getSimilarPosts()

