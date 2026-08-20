from datetime import datetime, timezone
from uuid import UUID

from asyncpg.exceptions import UniqueViolationError

from app.db.datetime_utils import ensure_utc
from app.db.feed_sql import POSTS_WITH_TOPIC_VIEW
from app.schemas.report import Report, ReportStatus, StaffReport

_STAFF_REPORT_COLUMNS = """
    id,
    reporter_id,
    post_id,
    reported_user_id,
    reason,
    details,
    status,
    content_snapshot,
    topic_snapshot,
    author_username_snapshot,
    created_at
"""


# UTC calendar-day cap: one report per reporter per reported user.
REPORTS_PER_REPORTED_USER_PER_DAY = 1


class CannotReportOwnPost(Exception):
    """Raised when the caller tries to report a post they authored."""


class DuplicateOpenReport(Exception):
    """Raised when the caller already has an open report on this post."""


class ReportRateLimited(Exception):
    """Raised when the caller has already reported this user today (UTC)."""


class ReportRepository:
    def __init__(self, pool):
        self.pool = pool

    def _row_to_report(self, row) -> Report:
        return Report(
            id=str(row["id"]),
            post_id=str(row["post_id"]),
            reason=row["reason"],
            details=row["details"],
            status=row["status"],
            created_at=ensure_utc(row["created_at"]),
        )

    async def _consume_report_quota(self, conn, reporter_id: int, reported_user_id: int) -> bool:
        """Atomically consume one report slot for this reported user on the UTC day.

        Returns False when the reporter is already at REPORTS_PER_REPORTED_USER_PER_DAY
        for this author.
        """
        utc_day = datetime.now(timezone.utc).date()
        row = await conn.fetchrow(
            """
            INSERT INTO user_report_limits (
                reporter_id, reported_user_id, day, report_count
            )
            VALUES ($1, $2, $3, 1)
            ON CONFLICT (reporter_id, reported_user_id, day)
            DO UPDATE SET report_count = user_report_limits.report_count + 1
            WHERE user_report_limits.report_count < $4
            RETURNING report_count
            """,
            reporter_id,
            reported_user_id,
            utc_day,
            REPORTS_PER_REPORTED_USER_PER_DAY,
        )
        return row is not None

    async def create_report(
        self,
        reporter_id: int,
        post_id,
        reason: str,
        details: str | None,
    ) -> Report | None:
        """Create an open report with a frozen post snapshot.

        Does not touch blocks, feeds, or notify the author.

        Returns None when the post is missing.
        Raises CannotReportOwnPost, DuplicateOpenReport, or ReportRateLimited.
        """
        async with self.pool.acquire() as conn:
            async with conn.transaction():
                post = await conn.fetchrow(
                    f"""
                    SELECT pwt.id, pwt.user_id, pwt.content, pwt.topic, u.username
                    FROM {POSTS_WITH_TOPIC_VIEW} pwt
                    JOIN users u ON u.id = pwt.user_id
                    WHERE pwt.id = $1
                    """,
                    post_id,
                )
                if post is None:
                    return None
                if post["user_id"] == reporter_id:
                    raise CannotReportOwnPost()

                already_open = await conn.fetchval(
                    """
                    SELECT 1
                    FROM content_reports
                    WHERE reporter_id = $1
                      AND post_id = $2
                      AND status = 'open'
                    """,
                    reporter_id,
                    post["id"],
                )
                if already_open:
                    raise DuplicateOpenReport()

                try:
                    row = await conn.fetchrow(
                        """
                        INSERT INTO content_reports (
                            reporter_id,
                            post_id,
                            reported_user_id,
                            reason,
                            details,
                            content_snapshot,
                            topic_snapshot,
                            author_username_snapshot
                        )
                        VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
                        ON CONFLICT (reporter_id, post_id) WHERE (status = 'open')
                        DO NOTHING
                        RETURNING id, post_id, reason, details, status, created_at
                        """,
                        reporter_id,
                        post["id"],
                        post["user_id"],
                        reason,
                        details,
                        post["content"],
                        post["topic"],
                        post["username"],
                    )
                except UniqueViolationError:
                    raise DuplicateOpenReport() from None
                if row is None:
                    raise DuplicateOpenReport()

                if not await self._consume_report_quota(
                    conn, reporter_id, post["user_id"]
                ):
                    raise ReportRateLimited()

                return self._row_to_report(row)

    def _row_to_staff_report(self, row) -> StaffReport:
        return StaffReport(
            id=str(row["id"]),
            reporter_id=row["reporter_id"],
            post_id=str(row["post_id"]) if row["post_id"] is not None else None,
            reported_user_id=row["reported_user_id"],
            reason=row["reason"],
            details=row["details"],
            status=row["status"],
            content_snapshot=row["content_snapshot"],
            topic_snapshot=row["topic_snapshot"],
            author_username_snapshot=row["author_username_snapshot"],
            created_at=ensure_utc(row["created_at"]),
        )

    async def list_staff_reports(
        self,
        status: ReportStatus | None = None,
    ) -> list[StaffReport]:
        async with self.pool.acquire() as conn:
            if status is None:
                rows = await conn.fetch(
                    f"""
                    SELECT {_STAFF_REPORT_COLUMNS}
                    FROM content_reports
                    ORDER BY created_at DESC, id DESC
                    """
                )
            else:
                rows = await conn.fetch(
                    f"""
                    SELECT {_STAFF_REPORT_COLUMNS}
                    FROM content_reports
                    WHERE status = $1
                    ORDER BY created_at DESC, id DESC
                    """,
                    status,
                )
        return [self._row_to_staff_report(row) for row in rows]

    async def get_staff_report(self, report_id: UUID) -> StaffReport | None:
        async with self.pool.acquire() as conn:
            row = await conn.fetchrow(
                f"""
                SELECT {_STAFF_REPORT_COLUMNS}
                FROM content_reports
                WHERE id = $1
                """,
                report_id,
            )
        if row is None:
            return None
        return self._row_to_staff_report(row)

    async def update_staff_report_status(
        self,
        report_id: UUID,
        status: ReportStatus,
    ) -> StaffReport | None:
        async with self.pool.acquire() as conn:
            row = await conn.fetchrow(
                f"""
                UPDATE content_reports
                SET status = $2
                WHERE id = $1
                RETURNING {_STAFF_REPORT_COLUMNS}
                """,
                report_id,
                status,
            )
        if row is None:
            return None
        return self._row_to_staff_report(row)
