import json

from app.db.jsonb import normalize_strategy_weights
from app.schemas.user import (
    DEFAULT_STRATEGY_WEIGHTS,
    UserInfo,
    UserProfile,
    default_user_prefs,
)


class UserRepository:
    def __init__(self, pool):
        self.pool = pool

    def _build_user_profile(self, rows) -> UserProfile:
        return UserProfile(
            user_id=rows["user_id"],
            diversity_tolerance=rows["diversity_tolerance"],
            randomness=rows["randomness"],
            preferred_topics=list(rows["preferred_topics"]),
            blacklisted_topics=list(rows["blacklisted_topics"]),
            use_view_time=rows["use_view_time"],
            view_time_weight=rows["view_time_weight"],
            strategy_weights=normalize_strategy_weights(
                rows["strategy_weights"],
                defaults=DEFAULT_STRATEGY_WEIGHTS,
            ),
        )

    def _row_to_user_info(self, row) -> UserInfo:
        return UserInfo(
            id=row["id"],
            username=row["username"],
            email=row["email"],
            created_at=row["created_at"],
        )

    async def get_profile_info(self, user_id: int) -> UserInfo | None:
        async with self.pool.acquire() as conn:
            row = await conn.fetchrow(
                """
                SELECT id, username, email, created_at
                FROM users
                WHERE id = $1
                """,
                user_id,
            )

        if not row:
            return None

        return self._row_to_user_info(row)

    async def put_email(self, email: str, user_id: int) -> UserInfo | None:
        async with self.pool.acquire() as conn:
            row = await conn.fetchrow(
                """
                UPDATE users
                SET email = lower($1)
                WHERE id = $2
                RETURNING id, username, email, created_at
                """,
                email,
                user_id,
            )

        if not row:
            return None

        return self._row_to_user_info(row)

    async def get_prefs(self, user_id: int) -> UserProfile:
        async with self.pool.acquire() as conn:
            rows = await conn.fetchrow("""SELECT * FROM user_profiles WHERE user_id = $1""", user_id)

        if not rows:
            return default_user_prefs(user_id)

        return self._build_user_profile(rows)

    async def save_prefs(self, user_id: int, body) -> UserProfile:
        async with self.pool.acquire() as conn:
            rows = await conn.fetchrow("""
                INSERT INTO user_profiles (
                    user_id,
                    diversity_tolerance,
                    randomness,
                    preferred_topics,
                    blacklisted_topics,
                    use_view_time,
                    view_time_weight,
                    strategy_weights
                )
                VALUES ($1, $2, $3, $4, $5, $6, $7, $8::jsonb)
                ON CONFLICT (user_id) DO UPDATE
                SET diversity_tolerance = EXCLUDED.diversity_tolerance,
                    randomness = EXCLUDED.randomness,
                    preferred_topics = EXCLUDED.preferred_topics,
                    blacklisted_topics = EXCLUDED.blacklisted_topics,
                    use_view_time = EXCLUDED.use_view_time,
                    view_time_weight = EXCLUDED.view_time_weight,
                    strategy_weights = EXCLUDED.strategy_weights
                RETURNING *;
            """,
            user_id,
            body.diversity_tolerance,
            body.randomness,
            body.preferred_topics,
            body.blacklisted_topics,
            body.use_view_time,
            body.view_time_weight,
            json.dumps(body.strategy_weights),
            )

        return self._build_user_profile(rows)

    async def put_prefs(self, user_id: int, body) -> UserProfile:
        return await self.save_prefs(user_id, body)

    async def delete_user(self, user_id: int) -> bool:
        async with self.pool.acquire() as conn:
            result = await conn.execute("DELETE FROM users WHERE id = $1", user_id)
        return result == "DELETE 1"
