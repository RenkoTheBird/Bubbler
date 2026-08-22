import datetime
from typing import Literal
from uuid import UUID

from pydantic import BaseModel, Field, field_serializer, model_validator

from app.db.datetime_utils import ensure_utc, utc_iso_z

AccountStatus = Literal["active", "suspended", "banned"]
AccountRestrictAction = Literal["suspend", "ban", "unsuspend", "unban"]
SanctionAction = Literal["suspend", "ban", "unsuspend", "unban", "remove_post"]


class AccountRestrictRequest(BaseModel):
    action: AccountRestrictAction
    reason_code: str | None = Field(default=None, max_length=80)
    staff_note: str | None = Field(default=None, max_length=2000)
    public_message: str | None = Field(default=None, max_length=500)
    suspension_days: int | None = Field(default=None, ge=1, le=3650)
    report_id: UUID | None = None

    @model_validator(mode="after")
    def validate_action_fields(self):
        if self.action == "suspend" and self.suspension_days is not None:
            if self.suspension_days < 1:
                raise ValueError("suspension_days must be at least 1")
        if self.action == "ban" and self.suspension_days is not None:
            raise ValueError("suspension_days is only valid for suspend")
        if self.action in {"unsuspend", "unban"} and self.suspension_days is not None:
            raise ValueError("suspension_days is only valid for suspend")
        return self


class AccountRestrictResult(BaseModel):
    user_id: int
    account_status: AccountStatus
    restricted_until: datetime.datetime | None = None
    sanction_id: UUID

    def model_post_init(self, __context) -> None:
        if self.restricted_until is not None:
            object.__setattr__(
                self, "restricted_until", ensure_utc(self.restricted_until)
            )

    @field_serializer("restricted_until")
    def serialize_restricted_until(
        self, value: datetime.datetime | None
    ) -> str | None:
        return utc_iso_z(value) if value is not None else None


class AccountSanction(BaseModel):
    id: UUID
    user_id: int
    action: SanctionAction
    reason_code: str | None = None
    staff_note: str | None = None
    public_message: str | None = None
    suspension_days: int | None = None
    restricted_until: datetime.datetime | None = None
    report_id: UUID | None = None
    post_id: UUID | None = None
    created_by: int | None = None
    created_at: datetime.datetime

    def model_post_init(self, __context) -> None:
        object.__setattr__(self, "created_at", ensure_utc(self.created_at))
        if self.restricted_until is not None:
            object.__setattr__(
                self, "restricted_until", ensure_utc(self.restricted_until)
            )

    @field_serializer("created_at", "restricted_until")
    def serialize_datetimes(
        self, value: datetime.datetime | None
    ) -> str | None:
        return utc_iso_z(value) if value is not None else None
