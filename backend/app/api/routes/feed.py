from fastapi import APIRouter, Depends
from ...services.feed_service import FeedService
from ..deps import getFeedService

router = APIRouter()

@router.get("/{id}/similar")
def getFeed(id: int, service: FeedService = Depends(getFeedService)):
    return service.getFeed() 

@router.get("/{id}/session")
def getNewSessionPosts(id: int, service: FeedService = Depends(getFeedService)):
    return service.getNewSessionPosts()

