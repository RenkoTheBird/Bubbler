from fastapi import APIRouter, Depends
from ...services.feed_service import FeedService

router = APIRouter()

@router.get("/{id}/similar")
def getFeed(id: int, service: FeedService = Depends()):
    return service.getFeed() 

@router.get("/{id}/session")
def getNewSessionPosts(id: int, service: FeedService = Depends()):
    return service.getNewSessionPosts()

