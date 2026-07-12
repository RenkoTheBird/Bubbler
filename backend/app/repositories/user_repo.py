from app.db.jsonb import normalize_strategy_weights, to_jsonb
from app.db.datetime_utils import ensure_utc
from app.schemas.user import (
    DEFAULT_STRATEGY_WEIGHTS,
    TopicPreference,
    UserInfo,
    UserProfile,
    default_user_prefs,
)


class UserRepository:
    def __init__(self, pool):
        self.pool = pool

    def _build_user_profile(self, row, topic_preferences: list[TopicPreference]) -> UserProfile:
        return UserProfile(
            user_id=row["user_id"],
            diversity_tolerance=row["diversity_tolerance"],
            randomness=row["randomness"],
            topic_preferences=topic_preferences,
            use_view_time=row["use_view_time"],
            view_time_weight=row["view_time_weight"],
            use_recency=row["use_recency"],
            ai_topic_detection=row["ai_topic_detection"],
            strategy_weights=normalize_strategy_weights(
                row["strategy_weights"],
                defaults=DEFAULT_STRATEGY_WEIGHTS,
            ),
        )

    def _row_to_user_info(self, row) -> UserInfo:
        return UserInfo(
            id=row["id"],
            username=row["username"],
            email=row["email"],
            created_at=ensure_utc(row["created_at"]),
        )

    async def _fetch_topic_prefs(self, conn, user_id: int) -> list[TopicPreference]:
        rows = await conn.fetch(
            """
            SELECT t.name AS topic, utp.preference_type
            FROM user_topic_prefs utp
            JOIN topics t ON t.id = utp.topic_id
            WHERE utp.user_id = $1
            ORDER BY t.name
            """,
            user_id,
        )
        return [
            TopicPreference(topic=row["topic"], preference_type=row["preference_type"])
            for row in rows
        ]

    async def _sync_topic_prefs(
        self,
        conn,
        user_id: int,
        topic_preferences: list[TopicPreference],
    ) -> None:
        await conn.execute("DELETE FROM user_topic_prefs WHERE user_id = $1", user_id)

        seen: set[tuple[str, str]] = set()
        for pref in topic_preferences:
            if not isinstance(pref.topic, str):
                continue
            normalized = pref.topic.strip().casefold()
            if not normalized:
                continue
            key = (normalized, pref.preference_type)
            if key in seen:
                continue
            seen.add(key)

            topic_id = await conn.fetchval(
                """
                INSERT INTO topics (name)
                VALUES ($1)
                ON CONFLICT (name) DO UPDATE SET name = EXCLUDED.name
                RETURNING id
                """,
                normalized,
            )
            await conn.execute(
                """
                INSERT INTO user_topic_prefs (user_id, topic_id, preference_type)
                VALUES ($1, $2, $3)
                ON CONFLICT (user_id, topic_id) DO UPDATE
                SET preference_type = EXCLUDED.preference_type
                """,
                user_id,
                topic_id,
                pref.preference_type,
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
            row = await conn.fetchrow(
                "SELECT * FROM user_profiles WHERE user_id = $1",
                user_id,
            )
            if not row:
                return default_user_prefs(user_id)

            topic_preferences = await self._fetch_topic_prefs(conn, user_id)

        return self._build_user_profile(row, topic_preferences)

    async def _upsert_prefs(self, user_id: int, body) -> UserProfile:
        async with self.pool.acquire() as conn:
            async with conn.transaction():
                row = await conn.fetchrow(
                    """
                    INSERT INTO user_profiles (
                        user_id,
                        diversity_tolerance,
                        randomness,
                        use_view_time,
                        view_time_weight,
                        use_recency,
                        ai_topic_detection,
                        strategy_weights
                    )
                    VALUES ($1, $2, $3, $4, $5, $6, $7, $8::jsonb)
                    ON CONFLICT (user_id) DO UPDATE
                    SET diversity_tolerance = EXCLUDED.diversity_tolerance,
                        randomness = EXCLUDED.randomness,
                        use_view_time = EXCLUDED.use_view_time,
                        view_time_weight = EXCLUDED.view_time_weight,
                        use_recency = EXCLUDED.use_recency,
                        ai_topic_detection = EXCLUDED.ai_topic_detection,
                        strategy_weights = EXCLUDED.strategy_weights
                    RETURNING *;
                    """,
                    user_id,
                    body.diversity_tolerance,
                    body.randomness,
                    body.use_view_time,
                    body.view_time_weight,
                    body.use_recency,
                    body.ai_topic_detection,
                    to_jsonb(body.strategy_weights),
                )
                await self._sync_topic_prefs(conn, user_id, body.topic_preferences)
                topic_preferences = await self._fetch_topic_prefs(conn, user_id)

        return self._build_user_profile(row, topic_preferences)

    async def put_prefs(self, user_id: int, body) -> UserProfile:
        """Persist preferences from an explicit user settings update (PUT /me/preferences)."""
        return await self._upsert_prefs(user_id, body)

    async def save_prefs(self, user_id: int, body) -> UserProfile:
        """Persist preferences after system-driven updates (e.g. interaction-derived topics)."""
        return await self._upsert_prefs(user_id, body)

    async def delete_user(self, user_id: int) -> bool:
        async with self.pool.acquire() as conn:
            result = await conn.execute("DELETE FROM users WHERE id = $1", user_id)
        return result == "DELETE 1"
