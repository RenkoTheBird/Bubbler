import datetime
import bcrypt
from app.repositories.auth_repo import AuthRepository
from app.schemas.user import CreateUser, UserLogin


def hash_password(password: str):
        return bcrypt.hashpw(password.encode(), bcrypt.gensalt())

def check_password(pw: str, password: str):
        return bcrypt.checkpw(pw, password)


class AuthService:
    def __init__(self, db_pool):
        self.auth_repo = AuthRepository(db_pool)

    async def postLoginInfo(self, userloggin: UserLogin):
        password_hash = hash_password(userloggin.password)
        em, pw = await self.auth_repo.postLoginInfo(id, userloggin.email, password_hash)
        return check_password(pw, password_hash)

    async def postRegistrationInfo(self, user: CreateUser):
        time = datetime.datetime.now()
        password_hash = hash_password(user.password).decode()
        return await self.auth_repo.postRegistrationInfo(id, user.username, user.email, password_hash)