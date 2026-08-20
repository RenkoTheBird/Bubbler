import datetime
from typing import Literal, Optional
from uuid import UUID

from pydantic import BaseModel, Field, field_serializer, field_validator

from app.db.datetime_utils import ensure_utc, utc_iso_z

# Cap for untrusted reporter notes; matches content_reports_details_length_check.
DETAILS_MAX_LENGTH = 2000

REPORT_REASONS = (
    "illegal_content",
    "severe_violence",
    "non_consensual_sexual_content",
    "harassment",
    "spam",
    "other",
)

ReportReason = Literal[
    "illegal_content",
    "severe_violence",
    "non_consensual_sexual_content",
    "harassment",
    "spam",
    "other",
]

ReportStatus = Literal["open", "in_review", "resolved", "dismissed"]


class ReportCreate(BaseModel):
    post_id: UUID
    reason: ReportReason
    details: Optional[str] = Field(default=None, max_length=DETAILS_MAX_LENGTH)

    @field_validator("details")
    @classmethod
    def normalize_details(cls, value: str | None) -> str | None:
        if value is None:
            return None
        stripped = value.strip()
        return stripped or None


class Report(BaseModel):
    """Reporter-facing ticket. Snapshots stay server-side for staff review."""

    id: str
    post_id: str
    reason: ReportReason
    details: Optional[str] = None
    status: ReportStatus
    created_at: datetime.datetime

    def model_post_init(self, __context) -> None:
        object.__setattr__(self, "created_at", ensure_utc(self.created_at))

    @field_serializer("created_at")
    def serialize_created_at(self, value: datetime.datetime) -> str:
        return utc_iso_z(value)


class StaffReport(BaseModel):
    """Staff review ticket with frozen snapshots and identity fields."""

    id: str
    reporter_id: Optional[int] = None
    post_id: Optional[str] = None
    reported_user_id: Optional[int] = None
    reason: ReportReason
    details: Optional[str] = None
    status: ReportStatus
    content_snapshot: str
    topic_snapshot: Optional[str] = None
    author_username_snapshot: Optional[str] = None
    created_at: datetime.datetime

    def model_post_init(self, __context) -> None:
        object.__setattr__(self, "created_at", ensure_utc(self.created_at))

    @field_serializer("created_at")
    def serialize_created_at(self, value: datetime.datetime) -> str:
        return utc_iso_z(value)


class StaffReportStatusUpdate(BaseModel):
    """Triage / close a ticket without enforcement actions (those stay L7)."""

    status: ReportStatus
