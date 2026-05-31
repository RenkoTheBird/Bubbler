from fastapi import APIRouter, Depends
from ...services.user_service import UserService 

router = APIRouter()

@router.get("/{id}/profile")
def getProfileInfo(service: UserService = Depends()):
    return service.getProfileInfo()

@router.get("/{id}/session")
def getNewSessionPosts(service: UserService = Depends()):
    return service.getNewSessionPosts()

@router.get("/{id}/posts")
async def getUserPosts(id: int, service: UserService = Depends()):
    return service.getUserPosts(id)

@router.post("/{id}/posts")
def postUserPosts(id: int, service: UserService = Depends()):
    return service.postUserPosts(id)

@router.put("/{id}/profile/email")
def putEmail(service: UserService = Depends()):
    return service.putEmail()