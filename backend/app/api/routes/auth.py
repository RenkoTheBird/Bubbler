from fastapi import APIRouter, Depends
from ...services.auth_service import AuthService

router = APIRouter()

# Post login info to check it against registered info
@router.post("login/{id}")
def postLoginInfo(id: int, email: str, password: str, service: AuthService = Depends()):
    return service.postLoginInfo(id, email, password)

# Post new registration info
@router.post("register/{id}")
def postRegistrationInfo(id: int, username: str, email: str, password: str, service: AuthService = Depends()):
    return service.postRegistrationInfo(id, username, email, password)