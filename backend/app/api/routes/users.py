from fastapi import APIRouter
from fastapi import Depends

router = APIRouter()

@router.get("users/{id}/profile")
def getProfileInfo(service: UserService = Depends()):
    return service.getProfileInfo()

@router.get("users/{id}/session")
def getNewSessionPosts(service: UserService = Depends()):
    return service.getNewSessionPosts()

@router.put("users/{id}/profile/email")
def putEmail(service: UserService = Depends()):
    return service.putEmail()