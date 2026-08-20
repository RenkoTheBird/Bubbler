from fastapi import HTTPException

from app.repositories.report_repo import (
    CannotReportOwnPost,
    DuplicateOpenReport,
    ReportRateLimited,
)
from app.schemas.report import Report, ReportCreate


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
            raise HTTPException(
                status_code=409,
                detail="You already have an open report for this post",
            ) from None
        except ReportRateLimited:
            raise HTTPException(
                status_code=429,
                detail="You can only report this user once per day. Try again tomorrow.",
            ) from None
        if report is None:
            raise HTTPException(status_code=404, detail="Post not found")
        return report
