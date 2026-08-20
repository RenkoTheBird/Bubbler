import jwt
from fastapi import Depends, HTTPException
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from config import my_env_vars

security = HTTPBearer()

async def get_current_user_id(
    credentials: HTTPAuthorizationCredentials = Depends(security),
) -> int:
    try:
        payload = jwt.decode(
            credentials.credentials,
            my_env_vars.secret_key,
            algorithms=[my_env_vars.algorithm],
        )
        return int(payload["sub"])
    except jwt.PyJWTError:
        raise HTTPException(status_code=401, detail="Invalid or expired token")


def create_require_staff(user_repo):
    """Gate that requires a valid token and a live users.role of staff."""

    async def require_staff(user_id: int = Depends(get_current_user_id)) -> int:
        if not await user_repo.is_staff(user_id):
            raise HTTPException(status_code=403, detail="Staff access required")
        return user_id

    return require_staff
