from datetime import datetime, timezone

from app.db.jsonb import normalize_composition, to_jsonb
from app.db.datetime_utils import ensure_utc, utc_iso_z
from app.schemas.composition import DEFAULT_COMPOSITION, CompositionWeights
from app.schemas.user import (
    STAFF_ROLE,
    BlockedUserInfo,
    PublicUserInfo,
    TopicPreference,
    UserInfo,
    UserProfile,
    default_user_prefs,
)

# UTC calendar-day cap for GET /user/me/export.
DATA_EXPORTS_PER_DAY = 2


class DataExportRateLimited(Exception):
    """Raised when the caller has used all data-export slots for the UTC day."""


class UserRepository:
    def __init__(self, pool):
        self.pool = pool

    def _build_user_profile(self, row, topic_preferences: list[TopicPreference]) -> UserProfile:
        topic_raw = normalize_composition(
            row["topic_composition"],
            defaults=DEFAULT_COMPOSITION,
        )
        post_raw = normalize_composition(
            row["post_composition"],
            defaults=DEFAULT_COMPOSITION,
        )
        return UserProfile(
            user_id=row["user_id"],
            feed_preset=row["feed_preset"],
            topic_composition=CompositionWeights(**topic_raw),
            post_composition=CompositionWeights(**post_raw),
            topic_preferences=topic_preferences,
            use_view_time=row["use_view_time"],
            view_time_weight=row["view_time_weight"],
            use_recency=row["use_recency"],
            ai_topic_detection=row["ai_topic_detection"],
        )

    def _row_to_user_info(self, row) -> UserInfo:
        return UserInfo(
            id=row["id"],
            username=row["username"],
            email=row["email"],
            role=row["role"],
            created_at=ensure_utc(row["created_at"]),
        )

    def _row_to_public_user_info(self, row, *, is_blocked: bool = False) -> PublicUserInfo:
        return PublicUserInfo(
            id=row["id"],
            username=row["username"],
            created_at=ensure_utc(row["created_at"]),
            is_blocked=is_blocked,
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

    async def is_staff(self, user_id: int) -> bool:
        async with self.pool.acquire() as conn:
            role = await conn.fetchval(
                "SELECT role FROM users WHERE id = $1",
                user_id,
            )
        return role == STAFF_ROLE

    async def get_profile_info(self, user_id: int) -> UserInfo | None:
        async with self.pool.acquire() as conn:
            row = await conn.fetchrow(
                """
                SELECT id, username, email, role, created_at
                FROM users
                WHERE id = $1
                """,
                user_id,
            )

        if not row:
            return None

        return self._row_to_user_info(row)

    async def get_profile_by_username(
        self,
        username: str,
        *,
        viewer_id: int | None = None,
    ) -> PublicUserInfo | None:
        async with self.pool.acquire() as conn:
            row = await conn.fetchrow(
                """
                SELECT id, username, created_at
                FROM users
                WHERE username_lower = lower($1)
                """,
                username,
            )
            if not row:
                return None

            is_blocked = False
            if viewer_id is not None and viewer_id != row["id"]:
                is_blocked = await conn.fetchval(
                    """
                    SELECT EXISTS (
                        SELECT 1
                        FROM user_blocks
                        WHERE blocker_id = $1 AND blocked_id = $2
                    )
                    """,
                    viewer_id,
                    row["id"],
                )

        return self._row_to_public_user_info(row, is_blocked=bool(is_blocked))

    async def get_blocked_user_ids(self, blocker_id: int) -> set[int]:
        async with self.pool.acquire() as conn:
            rows = await conn.fetch(
                """
                SELECT blocked_id
                FROM user_blocks
                WHERE blocker_id = $1
                """,
                blocker_id,
            )
        return {int(row["blocked_id"]) for row in rows}

    async def list_blocked_users(self, blocker_id: int) -> list[BlockedUserInfo]:
        async with self.pool.acquire() as conn:
            rows = await conn.fetch(
                """
                SELECT u.id, u.username, b.created_at AS blocked_at
                FROM user_blocks b
                JOIN users u ON u.id = b.blocked_id
                WHERE b.blocker_id = $1
                ORDER BY b.created_at DESC, u.username_lower
                """,
                blocker_id,
            )
        return [
            BlockedUserInfo(
                id=row["id"],
                username=row["username"],
                blocked_at=ensure_utc(row["blocked_at"]),
            )
            for row in rows
        ]

    async def block_user(self, blocker_id: int, blocked_id: int) -> bool:
        if blocker_id == blocked_id:
            return False
        async with self.pool.acquire() as conn:
            result = await conn.execute(
                """
                INSERT INTO user_blocks (blocker_id, blocked_id)
                VALUES ($1, $2)
                ON CONFLICT (blocker_id, blocked_id) DO NOTHING
                """,
                blocker_id,
                blocked_id,
            )
        return result in ("INSERT 0 1", "INSERT 0 0")

    async def unblock_user(self, blocker_id: int, blocked_id: int) -> bool:
        async with self.pool.acquire() as conn:
            result = await conn.execute(
                """
                DELETE FROM user_blocks
                WHERE blocker_id = $1 AND blocked_id = $2
                """,
                blocker_id,
                blocked_id,
            )
        return result == "DELETE 1"

    async def resolve_user_id_by_username(self, username: str) -> int | None:
        async with self.pool.acquire() as conn:
            return await conn.fetchval(
                """
                SELECT id
                FROM users
                WHERE username_lower = lower($1)
                """,
                username,
            )

    async def put_email(self, email: str, user_id: int) -> UserInfo | None:
        async with self.pool.acquire() as conn:
            row = await conn.fetchrow(
                """
                UPDATE users
                SET email = lower($1)
                WHERE id = $2
                RETURNING id, username, email, role, created_at
                """,
                email,
                user_id,
            )

        if not row:
            return None

        return self._row_to_user_info(row)

    async def get_password_credentials(self, user_id: int):
        async with self.pool.acquire() as conn:
            return await conn.fetchrow(
                """
                SELECT id, username, email, password
                FROM users
                WHERE id = $1
                """,
                user_id,
            )

    async def put_password(self, password_hash: str, user_id: int) -> bool:
        async with self.pool.acquire() as conn:
            result = await conn.execute(
                """
                UPDATE users
                SET password = $1
                WHERE id = $2
                """,
                password_hash,
                user_id,
            )
        return result == "UPDATE 1"

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
                        feed_preset,
                        topic_composition,
                        post_composition,
                        use_view_time,
                        view_time_weight,
                        use_recency,
                        ai_topic_detection
                    )
                    VALUES ($1, $2, $3::jsonb, $4::jsonb, $5, $6, $7, $8)
                    ON CONFLICT (user_id) DO UPDATE
                    SET feed_preset = EXCLUDED.feed_preset,
                        topic_composition = EXCLUDED.topic_composition,
                        post_composition = EXCLUDED.post_composition,
                        use_view_time = EXCLUDED.use_view_time,
                        view_time_weight = EXCLUDED.view_time_weight,
                        use_recency = EXCLUDED.use_recency,
                        ai_topic_detection = EXCLUDED.ai_topic_detection
                    RETURNING *;
                    """,
                    user_id,
                    body.feed_preset,
                    to_jsonb(body.topic_composition.as_dict()),
                    to_jsonb(body.post_composition.as_dict()),
                    body.use_view_time,
                    body.view_time_weight,
                    body.use_recency,
                    body.ai_topic_detection,
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

    async def delete_user(self, user_id: int, *, deletion_source: str = "self") -> bool:
        """Hard-delete the live account after writing an identity tombstone.

        Password is never copied. Email and username stay unique only on `users`,
        so they can be reused immediately after this returns.
        """
        async with self.pool.acquire() as conn:
            async with conn.transaction():
                row = await conn.fetchrow(
                    """
                    SELECT id, username, email, date_of_birth, role, created_at
                    FROM users
                    WHERE id = $1
                    FOR UPDATE
                    """,
                    user_id,
                )
                if row is None:
                    return False

                legal_hold = await conn.fetchval(
                    """
                    SELECT EXISTS (
                        SELECT 1
                        FROM content_reports
                        WHERE (reporter_id = $1 OR reported_user_id = $1)
                          AND (
                              legal_hold = TRUE
                              OR status IN ('open', 'in_review')
                              OR reason = 'illegal_content'
                          )
                    )
                    """,
                    user_id,
                )
                await conn.execute(
                    """
                    INSERT INTO deleted_accounts (
                        user_id,
                        username,
                        email,
                        date_of_birth,
                        role,
                        created_at,
                        deletion_source,
                        legal_hold
                    )
                    VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
                    """,
                    row["id"],
                    row["username"],
                    row["email"],
                    row["date_of_birth"],
                    row["role"],
                    row["created_at"],
                    deletion_source,
                    bool(legal_hold),
                )
                result = await conn.execute(
                    "DELETE FROM users WHERE id = $1",
                    user_id,
                )
        return result == "DELETE 1"

    async def _consume_data_export_quota(self, conn, user_id: int) -> bool:
        """Atomically consume one export slot for the current UTC day.

        Returns False when the user is already at DATA_EXPORTS_PER_DAY.
        """
        utc_day = datetime.now(timezone.utc).date()
        row = await conn.fetchrow(
            """
            INSERT INTO user_data_export_limits (user_id, day, export_count)
            VALUES ($1, $2, 1)
            ON CONFLICT (user_id, day)
            DO UPDATE SET export_count = user_data_export_limits.export_count + 1
            WHERE user_data_export_limits.export_count < $3
            RETURNING export_count
            """,
            user_id,
            utc_day,
            DATA_EXPORTS_PER_DAY,
        )
        return row is not None

    async def export_user_data(self, user_id: int) -> dict | None:
        """Machine-readable account export (no password, no embeddings).

        Includes reports filed by this user; never reports filed against them.
        Enforces DATA_EXPORTS_PER_DAY per UTC calendar day.
        Raises DataExportRateLimited when the quota is exhausted.
        """
        async with self.pool.acquire() as conn:
            profile_row = await conn.fetchrow(
                """
                SELECT username, email, date_of_birth, created_at
                FROM users
                WHERE id = $1
                """,
                user_id,
            )
            if not profile_row:
                return None

            if not await self._consume_data_export_quota(conn, user_id):
                raise DataExportRateLimited()

            post_rows = await conn.fetch(
                """
                SELECT id, content, created_at
                FROM posts
                WHERE user_id = $1
                ORDER BY created_at DESC, id
                """,
                user_id,
            )
            topic_rows = await conn.fetch(
                """
                SELECT pt.post_id, pt.topic_name, pt.source, pt.confidence, pt.weight
                FROM post_topics pt
                JOIN posts p ON p.id = pt.post_id
                WHERE p.user_id = $1
                ORDER BY pt.weight DESC, pt.topic_name
                """,
                user_id,
            )
            interaction_rows = await conn.fetch(
                """
                SELECT id, post_id, type, view_time, created_at
                FROM interactions
                WHERE user_id = $1
                ORDER BY created_at DESC, id
                """,
                user_id,
            )
            prefs_row = await conn.fetchrow(
                "SELECT * FROM user_profiles WHERE user_id = $1",
                user_id,
            )
            topic_preferences = await self._fetch_topic_prefs(conn, user_id)
            training_rows = await conn.fetch(
                """
                SELECT id, post_id, topic_name, action, created_at
                FROM topic_training_events
                WHERE user_id = $1
                ORDER BY created_at DESC, id
                """,
                user_id,
            )
            block_rows = await conn.fetch(
                """
                SELECT u.username, b.created_at AS blocked_at
                FROM user_blocks b
                JOIN users u ON u.id = b.blocked_id
                WHERE b.blocker_id = $1
                ORDER BY b.created_at DESC, u.username_lower
                """,
                user_id,
            )
            media_rows = await conn.fetch(
                """
                SELECT
                    id,
                    post_id,
                    media_type,
                    mime_type,
                    byte_size,
                    width,
                    height,
                    alt_text,
                    position,
                    created_at
                FROM media
                WHERE user_id = $1
                ORDER BY created_at DESC, position, id
                """,
                user_id,
            )
            # Own filed tickets only — never reports where this user is the target.
            report_rows = await conn.fetch(
                """
                SELECT id, post_id, reason, details, status, created_at
                FROM content_reports
                WHERE reporter_id = $1
                ORDER BY created_at DESC, id
                """,
                user_id,
            )

        topics_by_post: dict[str, list[dict]] = {}
        for row in topic_rows:
            post_key = str(row["post_id"])
            topics_by_post.setdefault(post_key, []).append(
                {
                    "topic_name": row["topic_name"],
                    "source": row["source"],
                    "confidence": float(row["confidence"]),
                    "weight": float(row["weight"]),
                }
            )

        if prefs_row:
            preferences = self._build_user_profile(prefs_row, topic_preferences).model_dump()
        else:
            preferences = default_user_prefs(user_id).model_dump()

        return {
            "exported_at": utc_iso_z(datetime.now(timezone.utc)),
            "profile": {
                "username": profile_row["username"],
                "email": profile_row["email"],
                "date_of_birth": profile_row["date_of_birth"].isoformat(),
                "created_at": utc_iso_z(profile_row["created_at"]),
            },
            "posts": [
                {
                    "id": str(row["id"]),
                    "content": row["content"],
                    "created_at": utc_iso_z(row["created_at"]),
                    "topics": topics_by_post.get(str(row["id"]), []),
                }
                for row in post_rows
            ],
            "interactions": [
                {
                    "id": str(row["id"]),
                    "post_id": str(row["post_id"]),
                    "type": row["type"],
                    "view_time": float(row["view_time"] or 0.0),
                    "created_at": utc_iso_z(row["created_at"]),
                }
                for row in interaction_rows
            ],
            "preferences": preferences,
            "topic_training_events": [
                {
                    "id": str(row["id"]),
                    "post_id": str(row["post_id"]),
                    "topic_name": row["topic_name"],
                    "action": row["action"],
                    "created_at": utc_iso_z(row["created_at"]),
                }
                for row in training_rows
            ],
            "blocks": [
                {
                    "username": row["username"],
                    "blocked_at": utc_iso_z(row["blocked_at"]),
                }
                for row in block_rows
            ],
            "media": [
                {
                    "id": str(row["id"]),
                    "post_id": str(row["post_id"]),
                    "media_type": row["media_type"],
                    "mime_type": row["mime_type"],
                    "byte_size": int(row["byte_size"]),
                    "width": row["width"],
                    "height": row["height"],
                    "alt_text": row["alt_text"],
                    "position": int(row["position"]),
                    "created_at": utc_iso_z(row["created_at"]),
                }
                for row in media_rows
            ],
            "reports": [
                {
                    "id": str(row["id"]),
                    "post_id": str(row["post_id"]) if row["post_id"] is not None else None,
                    "reason": row["reason"],
                    "details": row["details"],
                    "status": row["status"],
                    "created_at": utc_iso_z(row["created_at"]),
                }
                for row in report_rows
            ],
        }