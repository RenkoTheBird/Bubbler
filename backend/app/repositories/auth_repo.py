from app.db.jsonb import to_jsonb
from app.schemas.user import DEFAULT_USER_ROLE, default_user_prefs


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
            async with conn.transaction():
                user_id = await conn.fetchval(
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
                prefs = default_user_prefs(user_id)
                await conn.execute(
                    """
                    INSERT INTO user_profiles (
                        user_id,
                        feed_preset,
                        topic_composition,
                        post_composition,
                        use_view_time,
                        view_time_weight,
                        use_recency,
                        ai_topic_detection
                    )
                    VALUES ($1, $2, $3::jsonb, $4::jsonb, $5, $6, $7, $8)
                    """,
                    user_id,
                    prefs.feed_preset,
                    to_jsonb(prefs.topic_composition.as_dict()),
                    to_jsonb(prefs.post_composition.as_dict()),
                    prefs.use_view_time,
                    prefs.view_time_weight,
                    prefs.use_recency,
                    prefs.ai_topic_detection,
                )
                return user_id
