import datetime
import unittest
from unittest.mock import AsyncMock
from uuid import uuid4

from fastapi import HTTPException
from pydantic import ValidationError

from app.schemas.report import (
    StaffReport,
    StaffReportLegalHoldUpdate,
    StaffReportStatusUpdate,
)
from app.services.report import ReportService


def _staff_report(**overrides) -> StaffReport:
    values = {
        "id": str(uuid4()),
        "reporter_id": 3,
        "post_id": str(uuid4()),
        "reported_user_id": 9,
        "reason": "spam",
        "details": "looks automated",
        "status": "open",
        "content_snapshot": "Buy followers now",
        "topic_snapshot": "business",
        "author_username_snapshot": "spammer",
        "legal_hold": False,
        "resolved_at": None,
        "created_at": datetime.datetime.now(datetime.timezone.utc),
    }
    values.update(overrides)
    return StaffReport(**values)


class StaffReportSchemaTests(unittest.TestCase):
    def test_staff_ticket_includes_snapshots_and_ids(self):
        report = _staff_report()
        self.assertEqual(report.status, "open")
        self.assertEqual(report.reporter_id, 3)
        self.assertEqual(report.reported_user_id, 9)
        self.assertEqual(report.content_snapshot, "Buy followers now")
        self.assertEqual(report.author_username_snapshot, "spammer")

    def test_status_update_rejects_unknown(self):
        with self.assertRaises(ValidationError):
            StaffReportStatusUpdate(status="closed")

    def test_legal_hold_update_accepts_boolean(self):
        update = StaffReportLegalHoldUpdate(legal_hold=True)
        self.assertTrue(update.legal_hold)


class StaffReportServiceTests(unittest.IsolatedAsyncioTestCase):
    def setUp(self):
        self.repo = AsyncMock()
        self.service = ReportService(self.repo)
        self.report_id = uuid4()

    async def test_list_passes_status_filter(self):
        tickets = [_staff_report()]
        self.repo.list_staff_reports.return_value = tickets

        result = await self.service.list_staff_reports(status="open")

        self.assertEqual(result, tickets)
        self.repo.list_staff_reports.assert_awaited_once_with(
            status="open", reason=None
        )

    async def test_list_passes_severe_illegal_reason_filter(self):
        tickets = [_staff_report(reason="illegal_content")]
        self.repo.list_staff_reports.return_value = tickets

        result = await self.service.list_staff_reports(
            status="open", reason="illegal_content"
        )

        self.assertEqual(result, tickets)
        self.repo.list_staff_reports.assert_awaited_once_with(
            status="open", reason="illegal_content"
        )

    async def test_get_missing_is_404(self):
        self.repo.get_staff_report.return_value = None
        with self.assertRaises(HTTPException) as raised:
            await self.service.get_staff_report(self.report_id)
        self.assertEqual(raised.exception.status_code, 404)

    async def test_get_returns_ticket(self):
        ticket = _staff_report(id=str(self.report_id))
        self.repo.get_staff_report.return_value = ticket

        result = await self.service.get_staff_report(self.report_id)

        self.assertEqual(result.id, str(self.report_id))
        self.repo.get_staff_report.assert_awaited_once_with(self.report_id)

    async def test_update_status_triages(self):
        updated = _staff_report(id=str(self.report_id), status="in_review")
        self.repo.update_staff_report_status.return_value = updated

        result = await self.service.update_staff_report_status(
            self.report_id, "in_review"
        )

        self.assertEqual(result.status, "in_review")
        self.repo.update_staff_report_status.assert_awaited_once_with(
            self.report_id, "in_review"
        )

    async def test_update_missing_is_404(self):
        self.repo.update_staff_report_status.return_value = None
        with self.assertRaises(HTTPException) as raised:
            await self.service.update_staff_report_status(self.report_id, "dismissed")
        self.assertEqual(raised.exception.status_code, 404)

    async def test_update_legal_hold(self):
        updated = _staff_report(id=str(self.report_id), legal_hold=True)
        self.repo.update_staff_report_legal_hold.return_value = updated

        result = await self.service.update_staff_report_legal_hold(
            self.report_id, True
        )

        self.assertTrue(result.legal_hold)
        self.repo.update_staff_report_legal_hold.assert_awaited_once_with(
            self.report_id, True
        )

    async def test_update_legal_hold_missing_is_404(self):
        self.repo.update_staff_report_legal_hold.return_value = None
        with self.assertRaises(HTTPException) as raised:
            await self.service.update_staff_report_legal_hold(self.report_id, False)
        self.assertEqual(raised.exception.status_code, 404)
