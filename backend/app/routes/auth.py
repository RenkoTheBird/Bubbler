from fastapi import APIRouter
from app.services.auth import AuthService
from app.schemas.user import CreateUser, UserLogin

def create_auth_router(auth_service: AuthService):
    router = APIRouter()

    @router.post("/login")
    async def post_login_info(body: UserLogin):
        return await auth_service.postLoginInfo(body.email, body.password)

    @router.post("/register")
    async def post_registration_info(body: CreateUser):
        return await auth_service.postRegistrationInfo(body)

    return router