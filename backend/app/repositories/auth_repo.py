from app.models.user import User
from ..db.base import pool
import datetime

class AuthRepository:

    async def postLoginInfo(self, id: int, email: str, password_hash: str):
        # Grab the email and password stored with user id and send it back to service
        async with pool.acquire() as conn:
            result = await conn.fetch("""SELECT email, password_hash FROM users WHERE id=$1""", id)
        
        return [self._map_row(result) for res in result]

    async def postRegistrationInfo(self, id: int, username: str, email: str, password_hash: str, time: datetime.datetime):
        
        async with pool.acquire() as conn:
            result = await conn.fetch(
                """INSERT INTO users (id, username, email, password_hash, created_at) 
                   VALUES ($1, $2, $3, $4, $5)""",
                   id, username, email, password_hash, time
            )
        
        return result
    
    def _map_user(self, row) -> User:
        return User (
            email=row["email"],
            password_hash=row["password_hash"]
        )