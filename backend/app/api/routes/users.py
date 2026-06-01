from fastapi import APIRouter, Depends
from ...services.user_service import UserService 

router = APIRouter()

@router.get("/{id}/profile")
def getProfileInfo(id: int, service: UserService = Depends()):
    return service.getProfileInfo()

@router.put("/{id}/profile/email")
def putEmail(id: int, service: UserService = Depends()):
    return service.putEmail()