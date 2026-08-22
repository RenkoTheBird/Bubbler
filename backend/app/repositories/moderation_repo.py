from dataclasses import dataclass
from datetime import datetime, timedelta, timezone
from uuid import UUID

from app.db.datetime_utils import ensure_utc
from app.schemas.moderation import AccountSanction, AccountStatus
from app.schemas.user import STAFF_ROLE


class UserNotFound(Exception):
    """Raised when the target user row does not exist."""


class CannotRestrictStaff(Exception):
    """Raised when staff attempt to restrict a staff account."""


class InvalidRestrictAction(Exception):
    """Raised when the requested restriction action is invalid for the user state."""


class PostNotFound(Exception):
    """Raised when a staff post removal target does not exist."""


@dataclass(frozen=True)
class AccountAccess:
    user_id: int
    account_status: AccountStatus
    restricted_until: datetime | None
    public_message: str | None


class ModerationRepository:
    def __init__(self, pool):
        self.pool = pool

    def _row_to_sanction(self, row) -> AccountSanction:
        return AccountSanction(
            id=row["id"],
            user_id=row["user_id"],
            action=row["action"],
            reason_code=row["reason_code"],
            staff_note=row["staff_note"],
            public_message=row["public_message"],
            suspension_days=row["suspension_days"],
            restricted_until=row["restricted_until"],
            report_id=row["report_id"],
            post_id=row["post_id"],
            created_by=row["created_by"],
            created_at=ensure_utc(row["created_at"]),
        )

    async def is_identity_blocked(self, email: str, username: str) -> bool:
        async with self.pool.acquire() as conn:
            return await conn.fetchval(
                """
                SELECT EXISTS (
                    SELECT 1
                    FROM blocked_identities
                    WHERE email_lower = lower($1)
                       OR username_lower = lower($2)
                )
                """,
                email,
                username,
            )

    async def resolve_account_access(self, user_id: int) -> AccountAccess | None:
        async with self.pool.acquire() as conn:
            row = await conn.fetchrow(
                """
                SELECT id, account_status, restricted_until
                FROM users
                WHERE id = $1
                """,
                user_id,
            )
            if row is None:
                return None

            status = row["account_status"]
            restricted_until = row["restricted_until"]
            if restricted_until is not None:
                restricted_until = ensure_utc(restricted_until)

            now = datetime.now(timezone.utc)
            if status == "suspended" and restricted_until is not None and restricted_until <= now:
                await conn.execute(
                    """
                    UPDATE users
                    SET account_status = 'active', restricted_until = NULL
                    WHERE id = $1
                    """,
                    user_id,
                )
                status = "active"
                restricted_until = None

            public_message = None
            if status == "banned":
                public_message = await conn.fetchval(
                    """
                    SELECT public_message
                    FROM account_sanctions
                    WHERE user_id = $1
                      AND action = 'ban'
                    ORDER BY created_at DESC
                    LIMIT 1
                    """,
                    user_id,
                )

            return AccountAccess(
                user_id=user_id,
                account_status=status,
                restricted_until=restricted_until,
                public_message=public_message,
            )

    async def restrict_account(
        self,
        *,
        staff_id: int,
        user_id: int,
        action: str,
        reason_code: str | None,
        staff_note: str | None,
        public_message: str | None,
        suspension_days: int | None,
        report_id: UUID | None,
    ) -> AccountSanction:
        async with self.pool.acquire() as conn:
            async with conn.transaction():
                target = await conn.fetchrow(
                    """
                    SELECT id, username, email, role, account_status
                    FROM users
                    WHERE id = $1
                    FOR UPDATE
                    """,
                    user_id,
                )
                if target is None:
                    raise UserNotFound

                if target["role"] == STAFF_ROLE:
                    raise CannotRestrictStaff

                now = datetime.now(timezone.utc)
                new_status: AccountStatus = target["account_status"]
                restricted_until = None
                days_to_store = None

                if action == "suspend":
                    if target["account_status"] == "banned":
                        raise InvalidRestrictAction
                    new_status = "suspended"
                    if suspension_days is not None:
                        restricted_until = now + timedelta(days=suspension_days)
                        days_to_store = suspension_days
                elif action == "ban":
                    new_status = "banned"
                    restricted_until = None
                    await self._upsert_blocked_identities(
                        conn,
                        source_user_id=user_id,
                        email=target["email"],
                        username=target["username"],
                    )
                elif action == "unsuspend":
                    if target["account_status"] != "suspended":
                        raise InvalidRestrictAction
                    new_status = "active"
                    restricted_until = None
                elif action == "unban":
                    if target["account_status"] != "banned":
                        raise InvalidRestrictAction
                    new_status = "active"
                    restricted_until = None
                    await conn.execute(
                        """
                        DELETE FROM blocked_identities
                        WHERE source_user_id = $1
                        """,
                        user_id,
                    )
                else:
                    raise InvalidRestrictAction

                await conn.execute(
                    """
                    UPDATE users
                    SET account_status = $2, restricted_until = $3
                    WHERE id = $1
                    """,
                    user_id,
                    new_status,
                    restricted_until,
                )

                sanction_row = await conn.fetchrow(
                    """
                    INSERT INTO account_sanctions (
                        user_id,
                        action,
                        reason_code,
                        staff_note,
                        public_message,
                        suspension_days,
                        restricted_until,
                        report_id,
                        created_by
                    )
                    VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
                    RETURNING *
                    """,
                    user_id,
                    action,
                    reason_code,
                    staff_note,
                    public_message,
                    days_to_store,
                    restricted_until,
                    report_id,
                    staff_id,
                )

        return self._row_to_sanction(sanction_row)

    async def staff_remove_post(
        self,
        *,
        staff_id: int,
        post_id: UUID,
        reason_code: str | None,
        staff_note: str | None,
        public_message: str | None,
        report_id: UUID | None,
    ) -> AccountSanction:
        async with self.pool.acquire() as conn:
            async with conn.transaction():
                post = await conn.fetchrow(
                    """
                    SELECT id, user_id
                    FROM posts
                    WHERE id = $1
                    FOR UPDATE
                    """,
                    post_id,
                )
                if post is None:
                    raise PostNotFound

                result = await conn.execute(
                    "DELETE FROM posts WHERE id = $1",
                    post_id,
                )
                if result != "DELETE 1":
                    raise PostNotFound

                sanction_row = await conn.fetchrow(
                    """
                    INSERT INTO account_sanctions (
                        user_id,
                        action,
                        reason_code,
                        staff_note,
                        public_message,
                        report_id,
                        post_id,
                        created_by
                    )
                    VALUES ($1, 'remove_post', $2, $3, $4, $5, $6, $7)
                    RETURNING *
                    """,
                    post["user_id"],
                    reason_code,
                    staff_note,
                    public_message,
                    report_id,
                    post_id,
                    staff_id,
                )

        return self._row_to_sanction(sanction_row)

    async def _upsert_blocked_identities(
        self,
        conn,
        *,
        source_user_id: int,
        email: str,
        username: str,
    ) -> None:
        await conn.execute(
            "DELETE FROM blocked_identities WHERE source_user_id = $1",
            source_user_id,
        )
        await conn.execute(
            """
            INSERT INTO blocked_identities (source_user_id, email_lower, username_lower)
            VALUES ($1, lower($2), lower($3))
            """,
            source_user_id,
            email,
            username,
        )
