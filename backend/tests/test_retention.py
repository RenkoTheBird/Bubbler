import datetime
import unittest
from contextlib import asynccontextmanager
from datetime import timedelta, timezone
from unittest.mock import AsyncMock, MagicMock
from uuid import uuid4

from config import RetentionConfig

from app.repositories.report_repo import ReportRepository
from app.repositories.retention_repo import RetentionRepository, _parse_execute_count
from app.services.retention import RetentionService


class ParseExecuteCountTests(unittest.TestCase):
    def test_parses_delete_and_update(self):
        self.assertEqual(_parse_execute_count("DELETE 12"), 12)
        self.assertEqual(_parse_execute_count("UPDATE 3"), 3)
        self.assertEqual(_parse_execute_count("DELETE 0"), 0)

    def test_unknown_result_is_zero(self):
        self.assertEqual(_parse_execute_count(""), 0)


class RetentionRepositorySqlTests(unittest.IsolatedAsyncioTestCase):
    def setUp(self):
        self.config = RetentionConfig()
        self.conn = AsyncMock()
        self.pool = MagicMock()

        @asynccontextmanager
        async def _acquire():
            yield self.conn

        self.pool.acquire = _acquire
        self.repo = RetentionRepository(self.pool, self.config, batch_size=100)

    async def test_purge_interactions_uses_explore_skip_types_only(self):
        self.conn.execute = AsyncMock(return_value="DELETE 2")

        deleted = await self.repo.purge_interactions_batch(self.conn)

        self.assertEqual(deleted, 2)
        sql = self.conn.execute.call_args[0][0]
        self.assertIn("type = ANY($1::text[])", sql)
        self.assertEqual(
            self.conn.execute.call_args[0][1],
            list(self.config.interactions_purge_types),
        )

    async def test_anonymize_training_events_clears_user_id(self):
        self.conn.execute = AsyncMock(return_value="UPDATE 4")

        updated = await self.repo.anonymize_training_events_batch(self.conn)

        self.assertEqual(updated, 4)
        sql = self.conn.execute.call_args[0][0]
        self.assertIn("SET user_id = NULL", sql)
        self.assertIn("user_id IS NOT NULL", sql)

    async def test_purge_closed_reports_skips_legal_hold_and_illegal_content(self):
        self.conn.execute = AsyncMock(return_value="DELETE 1")

        await self.repo.purge_closed_reports_batch(self.conn)

        sql = self.conn.execute.call_args[0][0]
        self.assertIn("legal_hold = FALSE", sql)
        self.assertIn("reason <> ALL($1::text[])", sql)
        self.assertEqual(self.conn.execute.call_args[0][1], ["illegal_content"])

    async def test_limit_table_purge_uses_day_cutoff(self):
        self.conn.execute = AsyncMock(return_value="DELETE 7")

        deleted = await self.repo.purge_limit_table(self.conn, "reporter_daily_limits")

        self.assertEqual(deleted, 7)
        sql = self.conn.execute.call_args[0][0]
        self.assertIn("reporter_daily_limits", sql)
        self.assertIn("day < $1", sql)


class RetentionServiceTests(unittest.IsolatedAsyncioTestCase):
    def setUp(self):
        self.config = RetentionConfig()
        self.conn = AsyncMock()
        self.pool = MagicMock()

        @asynccontextmanager
        async def _acquire():
            yield self.conn

        self.pool.acquire = _acquire
        self.repo = RetentionRepository(self.pool, self.config, batch_size=2)
        self.service = RetentionService(self.repo)

    async def test_dry_run_counts_without_mutating(self):
        self.conn.transaction = MagicMock()
        self.conn.transaction.return_value.__aenter__ = AsyncMock(return_value=None)
        self.conn.transaction.return_value.__aexit__ = AsyncMock(return_value=None)

        self.conn.fetchval = AsyncMock(
            side_effect=[5, 3, 2, 10, 4, 1, 6]
        )

        stats = await self.service.run(dry_run=True)

        self.assertEqual(stats["interactions_explore_skip"], 5)
        self.assertEqual(stats["topic_training_anonymized"], 3)
        self.assertEqual(stats["topic_training_deleted"], 2)
        self.assertEqual(stats["reporter_daily_limits"], 10)
        self.assertEqual(stats["user_report_limits"], 4)
        self.assertEqual(stats["user_data_export_limits"], 1)
        self.assertEqual(stats["content_reports_closed"], 6)
        self.conn.execute.assert_not_called()

    async def test_apply_loops_until_batch_exhausted(self):
        self.conn.transaction = MagicMock()
        self.conn.transaction.return_value.__aenter__ = AsyncMock(return_value=None)
        self.conn.transaction.return_value.__aexit__ = AsyncMock(return_value=None)

        self.conn.execute = AsyncMock(
            side_effect=[
                "DELETE 2",
                "DELETE 1",
                "UPDATE 2",
                "UPDATE 0",
                "DELETE 0",
                "DELETE 5",
                "DELETE 4",
                "DELETE 1",
                "DELETE 3",
                "DELETE 0",
            ]
        )

        stats = await self.service.run(dry_run=False)

        self.assertEqual(stats["interactions_explore_skip"], 3)
        self.assertEqual(stats["topic_training_anonymized"], 2)
        self.assertEqual(stats["topic_training_deleted"], 0)
        self.assertEqual(stats["reporter_daily_limits"], 5)
        self.assertEqual(stats["user_report_limits"], 4)
        self.assertEqual(stats["user_data_export_limits"], 1)
        self.assertEqual(stats["content_reports_closed"], 3)


class RetentionSchemaReferenceTests(unittest.TestCase):
    """Guardrails: reference schema must retain retention columns and indexes."""

    @classmethod
    def setUpClass(cls):
        from pathlib import Path

        cls.schema = (
            Path(__file__).resolve().parent.parent / "app" / "db" / "schema.sql"
        ).read_text()

    def test_topic_training_user_id_nullable(self):
        start = self.schema.index("CREATE TABLE topic_training_events")
        end = self.schema.index("CREATE INDEX topic_training_events_post_id_idx")
        block = self.schema[start:end]
        self.assertIn("user_id INTEGER REFERENCES users(id)", block)
        self.assertNotIn("user_id INTEGER NOT NULL", block)

    def test_content_reports_retention_columns(self):
        self.assertIn("legal_hold BOOLEAN NOT NULL DEFAULT FALSE", self.schema)
        self.assertIn("resolved_at TIMESTAMP", self.schema)

    def test_retention_indexes_present(self):
        self.assertIn("interactions_explore_skip_created_at_idx", self.schema)
        self.assertIn("topic_training_events_created_at_idx", self.schema)
        self.assertIn("content_reports_purge_candidates_idx", self.schema)


class ReportResolvedAtTests(unittest.IsolatedAsyncioTestCase):
    def setUp(self):
        self.conn = AsyncMock()
        self.pool = MagicMock()

        @asynccontextmanager
        async def _acquire():
            yield self.conn

        self.pool.acquire = _acquire
        self.repo = ReportRepository(self.pool)
        self.report_id = uuid4()

    def _staff_row(self, **overrides):
        now = datetime.datetime.now(timezone.utc)
        values = {
            "id": self.report_id,
            "reporter_id": 1,
            "post_id": uuid4(),
            "reported_user_id": 2,
            "reason": "spam",
            "details": None,
            "status": "resolved",
            "content_snapshot": "snap",
            "topic_snapshot": "topic",
            "author_username_snapshot": "author",
            "legal_hold": False,
            "resolved_at": now,
            "created_at": now - timedelta(days=1),
        }
        values.update(overrides)
        return values

    async def test_update_resolved_sets_resolved_at_in_sql(self):
        self.conn.fetchrow = AsyncMock(return_value=self._staff_row(status="resolved"))

        report = await self.repo.update_staff_report_status(self.report_id, "resolved")

        sql = self.conn.fetchrow.call_args[0][0]
        self.assertIn("resolved_at = CASE", sql)
        self.assertIn("COALESCE(resolved_at, NOW())", sql)
        self.assertIsNotNone(report.resolved_at)

    async def test_update_reopen_clears_resolved_at_in_sql(self):
        self.conn.fetchrow = AsyncMock(
            return_value=self._staff_row(status="open", resolved_at=None)
        )

        await self.repo.update_staff_report_status(self.report_id, "open")

        sql = self.conn.fetchrow.call_args[0][0]
        self.assertIn("ELSE NULL", sql)

    async def test_update_dismissed_preserves_existing_resolved_at(self):
        first = datetime.datetime(2024, 1, 2, tzinfo=timezone.utc)
        self.conn.fetchrow = AsyncMock(
            return_value=self._staff_row(status="dismissed", resolved_at=first)
        )

        report = await self.repo.update_staff_report_status(self.report_id, "dismissed")

        self.assertEqual(report.resolved_at, first)
