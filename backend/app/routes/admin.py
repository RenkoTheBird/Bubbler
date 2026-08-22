from uuid import UUID

from fastapi import APIRouter, Depends, Query

from app.schemas.report import (
    ReportReason,
    ReportStatus,
    StaffReportLegalHoldUpdate,
    StaffReportStatusUpdate,
)
from app.services.report import ReportService


def create_admin_router(report_service: ReportService, require_staff):
    router = APIRouter()

    @router.get("/reports")
    async def list_reports(
        status: ReportStatus = Query(
            default="open",
            description="Filter by ticket status (open, in_review, resolved, dismissed)",
        ),
        reason: ReportReason | None = Query(
            default=None,
            description=(
                "Optional reason filter. Use illegal_content to isolate the "
                "severe-illegal / CSAM-bucket queue (escalation is L11)."
            ),
        ),
        _staff_id: int = Depends(require_staff),
    ):
        return await report_service.list_staff_reports(status=status, reason=reason)

    @router.get("/reports/{report_id}")
    async def get_report(
        report_id: UUID,
        _staff_id: int = Depends(require_staff),
    ):
        return await report_service.get_staff_report(report_id)

    @router.patch("/reports/{report_id}")
    async def update_report_status(
        report_id: UUID,
        body: StaffReportStatusUpdate,
        _staff_id: int = Depends(require_staff),
    ):
        return await report_service.update_staff_report_status(report_id, body.status)

    @router.patch("/reports/{report_id}/legal-hold")
    async def update_report_legal_hold(
        report_id: UUID,
        body: StaffReportLegalHoldUpdate,
        _staff_id: int = Depends(require_staff),
    ):
        return await report_service.update_staff_report_legal_hold(
            report_id, body.legal_hold
        )

    return router
