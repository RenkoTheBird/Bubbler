from datetime import date, datetime, timedelta, timezone

from config import RetentionConfig

# Severe-illegal tickets are excluded from auto-purge until counsel signs off (L11).
_NON_PURGEABLE_REPORT_REASONS = ("illegal_content",)


def _parse_execute_count(result: str) -> int:
    parts = result.split()
    if len(parts) >= 2 and parts[0] in ("DELETE", "UPDATE"):
        return int(parts[1])
    return 0


class RetentionRepository:
    def __init__(self, pool, config: RetentionConfig, *, batch_size: int = 5000):
        self.pool = pool
        self.config = config
        self.batch_size = batch_size

    @staticmethod
    def _cutoff(days: int) -> datetime:
        return datetime.now(timezone.utc) - timedelta(days=days)

    @staticmethod
    def _day_cutoff(days: int) -> date:
        return datetime.now(timezone.utc).date() - timedelta(days=days)

    async def count_interactions_to_purge(self, conn) -> int:
        cutoff = self._cutoff(self.config.interactions_retention_days)
        return await conn.fetchval(
            """
            SELECT COUNT(*)
            FROM interactions
            WHERE type = ANY($1::text[])
              AND created_at < $2
            """,
            list(self.config.interactions_purge_types),
            cutoff,
        )

    async def purge_interactions_batch(self, conn) -> int:
        cutoff = self._cutoff(self.config.interactions_retention_days)
        result = await conn.execute(
            """
            DELETE FROM interactions
            WHERE id IN (
                SELECT id
                FROM interactions
                WHERE type = ANY($1::text[])
                  AND created_at < $2
                LIMIT $3
            )
            """,
            list(self.config.interactions_purge_types),
            cutoff,
            self.batch_size,
        )
        return _parse_execute_count(result)

    async def count_training_events_to_anonymize(self, conn) -> int:
        cutoff = self._cutoff(self.config.training_events_anonymize_after_days)
        return await conn.fetchval(
            """
            SELECT COUNT(*)
            FROM topic_training_events
            WHERE user_id IS NOT NULL
              AND created_at < $1
            """,
            cutoff,
        )

    async def anonymize_training_events_batch(self, conn) -> int:
        cutoff = self._cutoff(self.config.training_events_anonymize_after_days)
        result = await conn.execute(
            """
            UPDATE topic_training_events
            SET user_id = NULL
            WHERE id IN (
                SELECT id
                FROM topic_training_events
                WHERE user_id IS NOT NULL
                  AND created_at < $1
                LIMIT $2
            )
            """,
            cutoff,
            self.batch_size,
        )
        return _parse_execute_count(result)

    async def count_training_events_to_delete(self, conn) -> int:
        cutoff = self._cutoff(self.config.training_events_delete_after_days)
        return await conn.fetchval(
            """
            SELECT COUNT(*)
            FROM topic_training_events
            WHERE user_id IS NULL
              AND created_at < $1
            """,
            cutoff,
        )

    async def delete_anonymized_training_events_batch(self, conn) -> int:
        cutoff = self._cutoff(self.config.training_events_delete_after_days)
        result = await conn.execute(
            """
            DELETE FROM topic_training_events
            WHERE id IN (
                SELECT id
                FROM topic_training_events
                WHERE user_id IS NULL
                  AND created_at < $1
                LIMIT $2
            )
            """,
            cutoff,
            self.batch_size,
        )
        return _parse_execute_count(result)

    async def count_limit_table_rows(self, conn, table: str) -> int:
        day_cutoff = self._day_cutoff(self.config.limit_table_retention_days)
        return await conn.fetchval(
            f"SELECT COUNT(*) FROM {table} WHERE day < $1",
            day_cutoff,
        )

    async def purge_limit_table(self, conn, table: str) -> int:
        day_cutoff = self._day_cutoff(self.config.limit_table_retention_days)
        result = await conn.execute(
            f"DELETE FROM {table} WHERE day < $1",
            day_cutoff,
        )
        return _parse_execute_count(result)

    async def count_closed_reports_to_purge(self, conn) -> int:
        cutoff = self._cutoff(self.config.closed_report_retention_days)
        return await conn.fetchval(
            """
            SELECT COUNT(*)
            FROM content_reports
            WHERE status IN ('resolved', 'dismissed')
              AND legal_hold = FALSE
              AND reason <> ALL($1::text[])
              AND COALESCE(resolved_at, created_at) < $2
            """,
            list(_NON_PURGEABLE_REPORT_REASONS),
            cutoff,
        )

    async def purge_closed_reports_batch(self, conn) -> int:
        cutoff = self._cutoff(self.config.closed_report_retention_days)
        result = await conn.execute(
            """
            DELETE FROM content_reports
            WHERE id IN (
                SELECT id
                FROM content_reports
                WHERE status IN ('resolved', 'dismissed')
                  AND legal_hold = FALSE
                  AND reason <> ALL($1::text[])
                  AND COALESCE(resolved_at, created_at) < $2
                LIMIT $3
            )
            """,
            list(_NON_PURGEABLE_REPORT_REASONS),
            cutoff,
            self.batch_size,
        )
        return _parse_execute_count(result)
