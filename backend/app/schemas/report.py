import datetime
from typing import Literal, Optional
from uuid import UUID

from pydantic import BaseModel, Field, field_serializer, field_validator

from app.db.datetime_utils import ensure_utc, utc_iso_z

# Cap for untrusted reporter notes; matches content_reports_details_length_check.
DETAILS_MAX_LENGTH = 2000

# Severe-illegal bucket for CSAM / hard-illegal isolation (L11 escalation; not auto-action).
SEVERE_ILLEGAL_REASON = "illegal_content"

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


def sanitize_report_details(value: str | None) -> str | None:
    """Normalize untrusted reporter notes: strip, drop controls, enforce emptiness → None."""
    if value is None:
        return None

    def _keep(ch: str) -> bool:
        if ch in "\n\t":
            return True
        code = ord(ch)
        # Drop C0/C1 controls and DEL; keep printable ASCII + Unicode.
        if code < 32 or code == 127 or 128 <= code <= 159:
            return False
        return True

    cleaned = "".join(ch for ch in value if _keep(ch))
    stripped = cleaned.strip()
    return stripped or None


class ReportCreate(BaseModel):
    post_id: UUID
    reason: ReportReason
    details: Optional[str] = Field(default=None, max_length=DETAILS_MAX_LENGTH)

    @field_validator("details")
    @classmethod
    def normalize_details(cls, value: str | None) -> str | None:
        return sanitize_report_details(value)


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
    legal_hold: bool = False
    resolved_at: Optional[datetime.datetime] = None
    created_at: datetime.datetime

    def model_post_init(self, __context) -> None:
        object.__setattr__(self, "created_at", ensure_utc(self.created_at))
        if self.resolved_at is not None:
            object.__setattr__(self, "resolved_at", ensure_utc(self.resolved_at))

    @field_serializer("created_at")
    def serialize_created_at(self, value: datetime.datetime) -> str:
        return utc_iso_z(value)

    @field_serializer("resolved_at")
    def serialize_resolved_at(self, value: datetime.datetime | None) -> str | None:
        return utc_iso_z(value)


class StaffReportStatusUpdate(BaseModel):
    """Triage / close a ticket without enforcement actions (those stay L7)."""

    status: ReportStatus


class StaffReportLegalHoldUpdate(BaseModel):
    """Retention hold — prevents auto-purge; syncs deleted_accounts tombstones."""

    legal_hold: bool
