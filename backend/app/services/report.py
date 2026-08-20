from uuid import UUID

from fastapi import HTTPException

from app.repositories.report_repo import (
    CannotReportOwnPost,
    DuplicateOpenReport,
    ReportRateLimited,
)
from app.schemas.report import (
    Report,
    ReportCreate,
    ReportReason,
    ReportStatus,
    StaffReport,
)


class ReportService:
    def __init__(self, report_repo):
        self.report_repo = report_repo

    async def create_report(self, reporter_id: int, body: ReportCreate) -> Report:
        try:
            report = await self.report_repo.create_report(
                reporter_id,
                body.post_id,
                body.reason,
                body.details,
            )
        except CannotReportOwnPost:
            raise HTTPException(
                status_code=400,
                detail="You cannot report your own post",
            ) from None
        except DuplicateOpenReport:
            # Own open ticket only — never reveal whether others reported this post.
            raise HTTPException(
                status_code=409,
                detail="You already have an open report for this post",
            ) from None
        except ReportRateLimited:
            raise HTTPException(
                status_code=429,
                detail="Report limit reached. Try again tomorrow.",
            ) from None
        if report is None:
            raise HTTPException(status_code=404, detail="Post not found")
        return report

    async def list_staff_reports(
        self,
        status: ReportStatus | None = None,
        reason: ReportReason | None = None,
    ) -> list[StaffReport]:
        return await self.report_repo.list_staff_reports(status=status, reason=reason)

    async def get_staff_report(self, report_id: UUID) -> StaffReport:
        report = await self.report_repo.get_staff_report(report_id)
        if report is None:
            raise HTTPException(status_code=404, detail="Report not found")
        return report

    async def update_staff_report_status(
        self,
        report_id: UUID,
        status: ReportStatus,
    ) -> StaffReport:
        report = await self.report_repo.update_staff_report_status(report_id, status)
        if report is None:
            raise HTTPException(status_code=404, detail="Report not found")
        return report
