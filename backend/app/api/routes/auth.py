from fastapi import APIRouter, Depends
from ...services.auth_service import AuthService
from ..deps import getAuthService

router = APIRouter()

# Post login info to check it against registered info
@router.post("login/{id}")
def postLoginInfo(id: int, email: str, password: str, service: AuthService = Depends(getAuthService)):
    return service.postLoginInfo(id, email, password)

# Post new registration info
@router.post("register/{id}")
def postRegistrationInfo(id: int, username: str, email: str, password: str, service: AuthService = Depends(getAuthService)):
    return service.postRegistrationInfo(id, username, email, password)