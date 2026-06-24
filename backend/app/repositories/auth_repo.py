from app.repositories.user_repo import UserProfile

class AuthRepository:

    def __init__(self, pool):
        self.pool = pool

    async def post_login_info(self, email: str):
        async with self.pool.acquire() as conn:
            row = await conn.fetchrow("""SELECT password_hash, id FROM users WHERE email=$1 OR username=$1""", email)
        return row
            
    async def post_registration_info(self, username: str, email: str, password_hash: str):
        async with self.pool.acquire() as conn:
            result = await conn.fetchval(
                """INSERT INTO users (username, email, password_hash) 
                VALUES ($1, $2, $3)
                RETURNING id""",
                username, email, password_hash
            )
        return result
    