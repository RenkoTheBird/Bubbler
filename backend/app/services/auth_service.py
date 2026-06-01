from ..repositories.auth_repo import AuthRepo
import datetime
import bcrypt

class AuthService:
    def __init__(self, repo: AuthRepo):
        self.repo = repo

    async def postLoginInfo(self):
        return await self.repo.postLoginInfo()

    async def postRegistrationInfo(self, id: int, username: str, email: str, password: str):
        # get current time to fill in "created_at"
        time = datetime.datetime.now()
        # hash the password
        password_hash = bcrypt.hashpw(password.encode(), bcrypt.gensalt())
        # add login info to database
        return await self.repo.postRegistrationInfo(id, username, email, password_hash, time)
    