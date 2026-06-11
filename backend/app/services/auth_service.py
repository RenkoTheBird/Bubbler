import datetime

class AuthService:
    def __init__(self, repo: AuthRepo, service: PasswordService):
        self.repo = repo
        self.service = service

    async def postLoginInfo(self, id: int, email: str, password: str):
        password_hash = self.service.hash_password(password)
        em, pw = await self.repo.postLoginInfo(id, email, password_hash)
        return self.service.check_password(pw, password_hash)

    async def postRegistrationInfo(self, id: int, username: str, email: str, password: str):
        # get current time to fill in "created_at"
        time = datetime.datetime.now()
        # hash the password
        password_hash = self.service.hash_password(password)
        # add login info to database
        return await self.repo.postRegistrationInfo(id, username, email, password_hash, time)
    