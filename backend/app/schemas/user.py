import datetime
from typing import Literal

from pydantic import BaseModel, EmailStr, Field, field_serializer, model_validator

from app.db.datetime_utils import ensure_utc, utc_iso_z
from app.schemas.composition import (
    DEFAULT_COMPOSITION,
    CompositionWeights,
    FeedPresetId,
    detect_preset,
    preset_compositions,
)

UserRole = Literal["user", "staff"]
DEFAULT_USER_ROLE: UserRole = "user"
STAFF_ROLE: UserRole = "staff"


class TopicPreference(BaseModel):
    topic: str
    preference_type: Literal["preferred", "blacklisted"]


def default_user_prefs(user_id: int = 0) -> "UserProfile":
    """Conservative launch defaults — see docs/moderation.md § Default protections."""
    topic, post = preset_compositions("stay_in_lane")
    return UserProfile(
        user_id=user_id,
        feed_preset="stay_in_lane",
        topic_composition=CompositionWeights(**topic),
        post_composition=CompositionWeights(**post),
        topic_preferences=[],
        use_view_time=False,
        view_time_weight=0.1,
        use_recency=False,
        ai_topic_detection=False,
    )


class UserInfo(BaseModel):
    id: int
    username: str
    email: EmailStr
    role: UserRole = DEFAULT_USER_ROLE
    created_at: datetime.datetime

    def model_post_init(self, __context) -> None:
        object.__setattr__(self, "created_at", ensure_utc(self.created_at))

    @field_serializer("created_at")
    def serialize_created_at(self, value: datetime.datetime) -> str:
        return utc_iso_z(value)


class PublicUserInfo(BaseModel):
    """Profile data safe to show for any user (no email)."""

    id: int
    username: str
    created_at: datetime.datetime
    is_blocked: bool = False

    def model_post_init(self, __context) -> None:
        object.__setattr__(self, "created_at", ensure_utc(self.created_at))

    @field_serializer("created_at")
    def serialize_created_at(self, value: datetime.datetime) -> str:
        return utc_iso_z(value)


class BlockedUserInfo(BaseModel):
    """A user the current account has blocked."""

    id: int
    username: str
    blocked_at: datetime.datetime

    def model_post_init(self, __context) -> None:
        object.__setattr__(self, "blocked_at", ensure_utc(self.blocked_at))

    @field_serializer("blocked_at")
    def serialize_blocked_at(self, value: datetime.datetime) -> str:
        return utc_iso_z(value)


# Doesnt need ID or Register Time autofilled by DB
class CreateUser(BaseModel):
    username: str = Field(min_length=1, max_length=20)
    email: EmailStr = Field(max_length=80)
    password: str = Field(min_length=5, max_length=40) ## logical limit at api side truly capped at 60 for hash at db
    date_of_birth: datetime.date


class EmailUpdate(BaseModel):
    email: EmailStr = Field(max_length=80)


class PasswordUpdate(BaseModel):
    email_or_username: str = Field(min_length=1, max_length=80)
    current_password: str = Field(min_length=1, max_length=40)
    new_password: str = Field(min_length=5, max_length=40)
    confirm_new_password: str = Field(min_length=5, max_length=40)

    @model_validator(mode="after")
    def passwords_must_match(self):
        if self.new_password != self.confirm_new_password:
            raise ValueError("New passwords do not match")
        return self


# Shared preference fields — used for both profile load and preference updates
class PrefsUpdate(BaseModel):
    feed_preset: FeedPresetId = "stay_in_lane"
    topic_composition: CompositionWeights = Field(
        default_factory=lambda: CompositionWeights(**DEFAULT_COMPOSITION)
    )
    post_composition: CompositionWeights = Field(
        default_factory=lambda: CompositionWeights(**DEFAULT_COMPOSITION)
    )
    topic_preferences: list[TopicPreference]
    use_view_time: bool = False
    view_time_weight: float = 0.1
    use_recency: bool = False
    ai_topic_detection: bool = False

    @model_validator(mode="after")
    def sync_preset_and_compositions(self):
        if self.feed_preset != "custom":
            topic, post = preset_compositions(self.feed_preset)
            self.topic_composition = CompositionWeights(**topic)
            self.post_composition = CompositionWeights(**post)
        else:
            self.topic_composition = self.topic_composition.normalized()
            self.post_composition = self.post_composition.normalized()
            detected = detect_preset(
                self.topic_composition.as_dict(),
                self.post_composition.as_dict(),
            )
            if detected != "custom":
                self.feed_preset = detected
        return self


class UserProfile(PrefsUpdate):
    user_id: int
