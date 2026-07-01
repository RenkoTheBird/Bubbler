class AuthRepository:

    def __init__(self, pool):
        self.pool = pool

    async def get_user_by_email(self, email: str):
        async with self.pool.acquire() as conn:
            password_column = await self._password_column(conn)
            return await conn.fetchrow(
                f"""
                SELECT id, username, email, {password_column} AS password_hash
                FROM users
                WHERE lower(email) = lower($1)
                LIMIT 1
                """,
                email,
            )

    async def create_user(self, username: str, email: str, password_hash: str):
        async with self.pool.acquire() as conn:
            password_column = await self._password_column(conn)
            return await conn.fetchrow(
                f"""
                INSERT INTO users (username, email, {password_column})
                VALUES ($1, lower($2), $3)
                RETURNING id, username, email
                """,
                username,
                email,
                password_hash,
            )

    async def get_user_by_id(self, user_id: int):
        async with self.pool.acquire() as conn:
            return await conn.fetchrow(
                """
                SELECT id, username, email
                FROM users
                WHERE id = $1
                LIMIT 1
                """,
                user_id,
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
