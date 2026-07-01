import base64
import bcrypt
import hashlib
import hmac
import json
import secrets
import time
from app.repositories.auth_repo import AuthRepository
from app.schemas.user import CreateUser
from config import my_env_vars
from fastapi import HTTPException

SESSION_DURATION_SECONDS = 60 * 60 * 24 * 30


def hash_password(password: str) -> str:
    return bcrypt.hashpw(password.encode("utf-8"), bcrypt.gensalt()).decode("utf-8")


def check_password(password: str, password_hash: str) -> bool:
    return bcrypt.checkpw(password.encode("utf-8"), password_hash.encode("utf-8"))


def _session_secret() -> str:
    if my_env_vars.session_secret:
        return my_env_vars.session_secret

    return secrets.token_urlsafe(48)


SESSION_SECRET = _session_secret()


def _base64url_encode(data: bytes) -> str:
    return base64.urlsafe_b64encode(data).decode("utf-8").rstrip("=")


def _base64url_decode(value: str) -> bytes:
    padding = "=" * (-len(value) % 4)
    return base64.urlsafe_b64decode(value + padding)


def _safe_user(row) -> dict:
    return {
        "id": row["id"],
        "username": row["username"],
        "email": row["email"],
    }


def create_session_token(user_id: int) -> tuple[str, int]:
    expires_at = int(time.time()) + SESSION_DURATION_SECONDS
    payload = {
        "user_id": user_id,
        "expires_at": expires_at,
    }
    payload_part = _base64url_encode(
        json.dumps(payload, separators=(",", ":")).encode("utf-8")
    )
    signature = hmac.new(
        SESSION_SECRET.encode("utf-8"),
        payload_part.encode("utf-8"),
        hashlib.sha256,
    ).digest()

    return f"{payload_part}.{_base64url_encode(signature)}", expires_at


def verify_session_token(token: str) -> int:
    try:
        payload_part, signature_part = token.split(".", 1)
    except ValueError as exc:
        raise HTTPException(status_code=401, detail="Invalid session.") from exc

    expected_signature = hmac.new(
        SESSION_SECRET.encode("utf-8"),
        payload_part.encode("utf-8"),
        hashlib.sha256,
    ).digest()
    supplied_signature = _base64url_decode(signature_part)

    if not hmac.compare_digest(expected_signature, supplied_signature):
        raise HTTPException(status_code=401, detail="Invalid session.")

    try:
        payload = json.loads(_base64url_decode(payload_part))
    except (json.JSONDecodeError, ValueError) as exc:
        raise HTTPException(status_code=401, detail="Invalid session.") from exc

    if int(payload["expires_at"]) < int(time.time()):
        raise HTTPException(status_code=401, detail="Session expired.")

    return int(payload["user_id"])


class AuthService:
    def __init__(self, db_pool):
        self.auth_repo = AuthRepository(db_pool)

    async def postLoginInfo(self, email: str, password: str):
        user = await self.auth_repo.get_user_by_email(email)
        if user is None or not check_password(password, user["password_hash"]):
            raise HTTPException(status_code=401, detail="Invalid email or password.")

        return self._auth_response(user)

    async def postRegistrationInfo(self, user: CreateUser):
        existing_user = await self.auth_repo.get_user_by_email(user.email)
        if existing_user is not None:
            raise HTTPException(status_code=409, detail="An account with this email already exists.")

        password_hash = hash_password(user.password)
        created_user = await self.auth_repo.create_user(user.username, user.email, password_hash)

        return self._auth_response(created_user)

    async def getSessionInfo(self, session_token: str):
        user_id = verify_session_token(session_token)
        user = await self.auth_repo.get_user_by_id(user_id)
        if user is None:
            raise HTTPException(status_code=401, detail="Invalid session.")

        return self._auth_response(user, session_token=session_token)

    def _auth_response(self, user, session_token: str | None = None):
        if session_token is None:
            session_token, expires_at = create_session_token(user["id"])
        else:
            expires_at = None

        return {
            "user": _safe_user(user),
            "session_token": session_token,
            "expires_at": expires_at,
        }
