from app.services.auth import AuthService
from typing import Annotated 
from app.schemas.user import CreateUser
from fastapi import APIRouter,  Depends
from fastapi.security import  OAuth2PasswordRequestForm

def create_auth_router(auth_service: AuthService):
    router = APIRouter()

    @router.post("/login")
    async def post_login_info(body: Annotated[OAuth2PasswordRequestForm, Depends()]):
        result = await auth_service.post_login_info(body.username, body.password)
        return result 
       
    @router.post("/register")
    async def post_registration_info(body: CreateUser):
        result = await auth_service.post_registration_info(body.username, body.email, body.password)
        return result

    return router