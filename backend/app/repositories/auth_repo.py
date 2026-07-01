class AuthRepository:

    def __init__(self, pool):
        self.pool = pool

    async def post_login_info(self, email_or_username: str):
        async with self.pool.acquire() as conn:
            password_column = await self._password_column(conn)
            return await conn.fetchrow(
                f"""
                SELECT id, {password_column} AS password
                FROM users
                WHERE lower(email) = lower($1)
                   OR lower(username) = lower($1)
                LIMIT 1
                """,
                email_or_username,
            )

    async def post_registration_info(self, username: str, email: str, password: str):
        async with self.pool.acquire() as conn:
            password_column = await self._password_column(conn)
            return await conn.fetchval(
                f"""
                INSERT INTO users (username, email, {password_column})
                VALUES ($1, lower($2), $3)
                RETURNING id
                """,
                username,
                email,
                password,
            )

    async def _password_column(self, conn) -> str:
        columns = await conn.fetch(
            """
            SELECT column_name
            FROM information_schema.columns
            WHERE table_schema = 'public'
              AND table_name = 'users'
              AND column_name IN ('password_hash', 'password')
            """
        )
        column_names = {row["column_name"] for row in columns}

        if "password_hash" in column_names:
            return "password_hash"

        if "password" in column_names:
            return "password"

        raise RuntimeError("users table needs a password_hash or password column.")
