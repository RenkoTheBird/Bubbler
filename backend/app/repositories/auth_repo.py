from app.schemas.user import DEFAULT_USER_ROLE


class AuthRepository:

    def __init__(self, pool):
        self.pool = pool

    async def post_login_info(self, email_or_username: str):
        async with self.pool.acquire() as conn:
            return await conn.fetchrow(
                """
                SELECT id, password
                FROM users
                WHERE email_lower = lower($1)
                   OR username_lower = lower($1)
                LIMIT 1
                """,
                email_or_username,
            )

    async def post_registration_info(self, username: str, email: str, password: str, date_of_birth):
        async with self.pool.acquire() as conn:
            return await conn.fetchval(
                """
                INSERT INTO users (username, email, password, date_of_birth, role)
                VALUES ($1, lower($2), $3, $4, $5)
                RETURNING id
                """,
                username,
                email,
                password,
                date_of_birth,
                DEFAULT_USER_ROLE,
            )
