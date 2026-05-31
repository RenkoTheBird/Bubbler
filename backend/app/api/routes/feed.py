from fastapi import APIRouter, Depends
from ...services.feed_service import FeedService

router = APIRouter()

@router.get("/{id}/similar")
def getSimilarPosts(service: FeedService = Depends()):
    return service.getSimilarPosts()

@router.get("/{id}/session")
def getNewSessionPosts(service: FeedService = Depends()):
    return service.getNewSessionPosts()

