import logging
from collections.abc import Callable

from app.repositories.retention_repo import RetentionRepository

logger = logging.getLogger(__name__)

_LIMIT_TABLES = (
    "reporter_daily_limits",
    "user_report_limits",
    "user_data_export_limits",
)


class RetentionService:
    def __init__(self, repo: RetentionRepository):
        self.repo = repo

    async def _run_batched(
        self,
        conn,
        *,
        dry_run: bool,
        count_fn: Callable,
        purge_fn: Callable,
    ) -> int:
        if dry_run:
            return await count_fn(conn)

        total = 0
        while True:
            batch = await purge_fn(conn)
            total += batch
            if batch < self.repo.batch_size:
                break
        return total

    async def run(self, *, dry_run: bool = False) -> dict[str, int]:
        stats: dict[str, int] = {}

        async with self.repo.pool.acquire() as conn:
            async with conn.transaction():
                stats["interactions_explore_skip"] = await self._run_batched(
                    conn,
                    dry_run=dry_run,
                    count_fn=self.repo.count_interactions_to_purge,
                    purge_fn=self.repo.purge_interactions_batch,
                )
                stats["topic_training_anonymized"] = await self._run_batched(
                    conn,
                    dry_run=dry_run,
                    count_fn=self.repo.count_training_events_to_anonymize,
                    purge_fn=self.repo.anonymize_training_events_batch,
                )
                stats["topic_training_deleted"] = await self._run_batched(
                    conn,
                    dry_run=dry_run,
                    count_fn=self.repo.count_training_events_to_delete,
                    purge_fn=self.repo.delete_anonymized_training_events_batch,
                )

                for table in _LIMIT_TABLES:
                    if dry_run:
                        stats[table] = await self.repo.count_limit_table_rows(conn, table)
                    else:
                        stats[table] = await self.repo.purge_limit_table(conn, table)

                stats["content_reports_closed"] = await self._run_batched(
                    conn,
                    dry_run=dry_run,
                    count_fn=self.repo.count_closed_reports_to_purge,
                    purge_fn=self.repo.purge_closed_reports_batch,
                )
                stats["deleted_accounts"] = await self._run_batched(
                    conn,
                    dry_run=dry_run,
                    count_fn=self.repo.count_deleted_accounts_to_purge,
                    purge_fn=self.repo.purge_deleted_accounts_batch,
                )

        mode = "dry_run" if dry_run else "applied"
        logger.info("retention_complete mode=%s stats=%s", mode, stats)
        return stats
