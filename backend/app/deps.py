import jwt
from fastapi import Depends, HTTPException
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from config import my_env_vars

from app.repositories.moderation_repo import ModerationRepository
from app.repositories.user_repo import UserRepository

security = HTTPBearer()


def create_get_current_user_id(moderation_repo: ModerationRepository):
    async def get_current_user_id(
        credentials: HTTPAuthorizationCredentials = Depends(security),
    ) -> int:
        try:
            payload = jwt.decode(
                credentials.credentials,
                my_env_vars.secret_key,
                algorithms=[my_env_vars.algorithm],
            )
            user_id = int(payload["sub"])
        except jwt.PyJWTError:
            raise HTTPException(status_code=401, detail="Invalid or expired token")

        access = await moderation_repo.resolve_account_access(user_id)
        if access is None:
            raise HTTPException(status_code=401, detail="Invalid or expired token")
        if access.account_status == "banned":
            detail = access.public_message or "Your account has been restricted."
            raise HTTPException(status_code=403, detail=detail)
        return user_id

    return get_current_user_id


def create_require_write_access(
    moderation_repo: ModerationRepository,
    get_current_user_id,
):
    async def require_write_access(user_id: int = Depends(get_current_user_id)) -> int:
        access = await moderation_repo.resolve_account_access(user_id)
        if access is None:
            raise HTTPException(status_code=401, detail="Invalid or expired token")
        if access.account_status == "suspended":
            raise HTTPException(status_code=403, detail="Your account is suspended.")
        return user_id

    return require_write_access


def create_require_staff(user_repo: UserRepository, get_current_user_id):
    """Gate that requires a valid token and a live users.role of staff."""

    async def require_staff(user_id: int = Depends(get_current_user_id)) -> int:
        if not await user_repo.is_staff(user_id):
            raise HTTPException(status_code=403, detail="Staff access required")
        return user_id

    return require_staff
