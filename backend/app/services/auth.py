from app.repositories.auth_repo import AuthRepository
import bcrypt
import jwt
from asyncpg.exceptions import UniqueViolationError
from fastapi import HTTPException
from datetime import datetime, timedelta, timezone


def hash_password(password: str) -> str:
    return bcrypt.hashpw(password.encode("utf-8"), bcrypt.gensalt()).decode("utf-8")


def check_password(entry_password: str, stored_password: str) -> bool:
    return bcrypt.checkpw(entry_password.encode("utf-8"), stored_password.encode("utf-8"))


class AuthService:
    def __init__(self, db_pool, secret_key, algorithm, expiration_offset):
        self.auth_repo = AuthRepository(db_pool)
        self.secret_key = secret_key
        self.algorithm = algorithm
        self.expiration_offset = expiration_offset  # Used as hours

    def create_access_token(self, data: dict):
        to_encode = data.copy()
        expire = datetime.now(timezone.utc) + timedelta(hours=self.expiration_offset)
        to_encode.update({"exp": expire})

        encoded_jwt = jwt.encode(to_encode, self.secret_key, algorithm=self.algorithm)
        return encoded_jwt

    def _token_response(self, user_id: int) -> dict:
        token = self.create_access_token({"sub": str(user_id)})
        return {
            "access_token": token,
            "token_type": "bearer",
            "user_id": user_id
        }

    # OAuth2PasswordRequestForm names the login field username; the app sends email there.
    async def post_login_info(self, username, password):
        row = await self.auth_repo.post_login_info(username)
        if not row:
            raise HTTPException(status_code=401, detail="Incorrect email or password")

        if not check_password(password, row["password"]):
            raise HTTPException(status_code=401, detail="Incorrect email or password")

        return self._token_response(row["id"])

    async def post_registration_info(self, username, email, password):
        password_hash = hash_password(password)
        try:
            user_id = await self.auth_repo.post_registration_info(username, email, password_hash)
            return self._token_response(user_id)
        except UniqueViolationError as exc:
            raise HTTPException(status_code=409, detail="username or email already taken") from exc
