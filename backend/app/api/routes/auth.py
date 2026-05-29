from fastapi import APIRouter, Depends

'''
NOTE: This section should handle login and registration routing
'''

# Post login info to check it against registered info
@router.post("login")
def postLoginInfo(service: AuthService = Depends()):
    return service.postLoginInfo()

# Post new registration info
def postRegistrationInfo(service: AuthService = Depends()):
    return service.postRegistrationInfo()