from app.repositories.auth_repo import AuthRepository
import bcrypt
import jwt
from asyncpg.exceptions import UniqueViolationError
from fastapi import HTTPException
from datetime import datetime, timedelta, timezone

def hash_password(password: str):
        return bcrypt.hashpw(password.encode(), bcrypt.gensalt())

def check_password(entry_password: str, stored_password: str):
        return bcrypt.checkpw(entry_password, stored_password)


class AuthService:
    def __init__(self, db_pool , secret_key, algorithm, expiration_offset ):
        self.auth_repo = AuthRepository(db_pool)
        self.secret_key = secret_key
        self.algorithm = algorithm 
        self.expiration_offset = expiration_offset ## Used as hours 
        
    def create_access_token(self, data: dict):
        to_encode = data.copy()
        
        expire = datetime.now(timezone.utc) + timedelta(hours=self.expiration_offset)
        
        to_encode.update({"exp": expire})
        
        encoded_jwt = jwt.encode(to_encode, self.secret_key, algorithm = self.algorithm)
        return encoded_jwt

    # quick tip here username could be email or username in future OATH2 ask for username to be the field though 
    async def postLoginInfo(self, username, password):
        row = await self.auth_repo.postLoginInfo(username)
        if not row:
            raise HTTPException(status_code=401, detail="Incorrect email or password")
        if not check_password(password.encode(), row["password"].encode()):
            raise HTTPException(status_code=401, detail="Incorrect email or password")
        return self.create_access_token({"sub": str(row["id"])})  ## comes as int from db 
    

    async def postRegistrationInfo(self, username, email, passowrd):
        password_hash = hash_password(passowrd).decode()
        try:    
            result = await self.auth_repo.postRegistrationInfo(username, email, password_hash)
            return self.create_access_token({"sub": str(result)})
        except UniqueViolationError as exc:
            raise HTTPException(status_code=409, detail="username or email already taken")