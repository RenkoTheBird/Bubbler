from fastapi import APIRouter, Depends
from ...services.auth_service import AuthService

'''
NOTE: This section should handle login and registration routing
'''

router = APIRouter()

# Post login info to check it against registered info
@router.post("login/{id}")
def postLoginInfo(id: int, service: AuthService = Depends()):
    return service.postLoginInfo()

# Post new registration info
@router.post("register/{id}")
def postRegistrationInfo(id: int, service: AuthService = Depends()):
    return service.postRegistrationInfo()