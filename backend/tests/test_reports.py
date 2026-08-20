import datetime
import unittest
from unittest.mock import AsyncMock
from uuid import uuid4

from fastapi import HTTPException
from pydantic import ValidationError

from app.repositories.report_repo import (
    CannotReportOwnPost,
    DuplicateOpenReport,
    ReportRateLimited,
)
from app.schemas.report import DETAILS_MAX_LENGTH, Report, ReportCreate
from app.services.report import ReportService


def _report(**overrides) -> Report:
    values = {
        "id": str(uuid4()),
        "post_id": str(uuid4()),
        "reason": "spam",
        "details": None,
        "status": "open",
        "created_at": datetime.datetime.now(datetime.timezone.utc),
    }
    values.update(overrides)
    return Report(**values)


class ReportCreateSchemaTests(unittest.TestCase):
    def test_accepts_known_reason_and_optional_details(self):
        post_id = uuid4()
        body = ReportCreate(post_id=post_id, reason="harassment", details="  threats  ")
        self.assertEqual(body.post_id, post_id)
        self.assertEqual(body.reason, "harassment")
        self.assertEqual(body.details, "threats")

    def test_blank_details_become_none(self):
        body = ReportCreate(post_id=uuid4(), reason="spam", details="   ")
        self.assertIsNone(body.details)

    def test_rejects_unknown_reason(self):
        with self.assertRaises(ValidationError):
            ReportCreate(post_id=uuid4(), reason="not_a_reason")

    def test_rejects_oversized_details(self):
        with self.assertRaises(ValidationError):
            ReportCreate(
                post_id=uuid4(),
                reason="other",
                details="x" * (DETAILS_MAX_LENGTH + 1),
            )

    def test_strips_control_characters_from_details(self):
        body = ReportCreate(
            post_id=uuid4(),
            reason="other",
            details="hello\x00world\x07\nnext",
        )
        self.assertEqual(body.details, "helloworld\nnext")

    def test_accepts_severe_illegal_bucket_reason(self):
        body = ReportCreate(post_id=uuid4(), reason="illegal_content")
        self.assertEqual(body.reason, "illegal_content")


class ReportServiceTests(unittest.IsolatedAsyncioTestCase):
    def setUp(self):
        self.repo = AsyncMock()
        self.service = ReportService(self.repo)
        self.body = ReportCreate(post_id=uuid4(), reason="spam")

    async def test_create_returns_open_ticket(self):
        created = _report(post_id=str(self.body.post_id))
        self.repo.create_report.return_value = created

        result = await self.service.create_report(7, self.body)

        self.assertEqual(result.id, created.id)
        self.assertEqual(result.status, "open")
        self.repo.create_report.assert_awaited_once_with(
            7, self.body.post_id, "spam", None
        )

    async def test_missing_post_is_404(self):
        self.repo.create_report.return_value = None
        with self.assertRaises(HTTPException) as raised:
            await self.service.create_report(7, self.body)
        self.assertEqual(raised.exception.status_code, 404)

    async def test_own_post_is_400(self):
        self.repo.create_report.side_effect = CannotReportOwnPost()
        with self.assertRaises(HTTPException) as raised:
            await self.service.create_report(7, self.body)
        self.assertEqual(raised.exception.status_code, 400)

    async def test_duplicate_open_report_is_409(self):
        self.repo.create_report.side_effect = DuplicateOpenReport()
        with self.assertRaises(HTTPException) as raised:
            await self.service.create_report(7, self.body)
        self.assertEqual(raised.exception.status_code, 409)

    async def test_daily_quota_is_429(self):
        self.repo.create_report.side_effect = ReportRateLimited()
        with self.assertRaises(HTTPException) as raised:
            await self.service.create_report(7, self.body)
        self.assertEqual(raised.exception.status_code, 429)
        self.assertIn("Report limit", raised.exception.detail)
