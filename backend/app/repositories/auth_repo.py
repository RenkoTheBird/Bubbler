from app.repositories.user_repo import UserProfile

class AuthRepository:

    def __init__(self, pool):
        self.pool = pool

    async def postLoginInfo(self, id: int, email: str, password_hash: str):
        async with self.pool.acquire() as conn:
            result = await conn.fetch("""SELECT email, password_hash FROM users WHERE id=$1""", id)
        
        return [self._map_user(res) for res in result]

    async def postRegistrationInfo(self, id: int, username: str, email: str, password_hash: str):
        
        async with self.pool.acquire() as conn:
            result = await conn.execute(
                """INSERT INTO users (username, email, password) 
                   VALUES ($1, $2, $3 )""",
                   username, email, password_hash
            )
        
        return result
    
    def _map_user(self, row) -> UserProfile:
        return UserProfile (
            email=row["email"],
            password_hash=row["password_hash"]
        )