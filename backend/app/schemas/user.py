import datetime
from typing import Literal

from pydantic import BaseModel, EmailStr, Field, field_serializer

from app.db.datetime_utils import ensure_utc, utc_iso_z

DEFAULT_STRATEGY_WEIGHTS: dict[str, float] = {
    "similar": 0.4,
    "graph": 0.25,
    "opposite": 0.2,
    "random": 0.15,
}


class TopicPreference(BaseModel):
    topic: str
    preference_type: Literal["preferred", "blacklisted"]


def default_user_prefs(user_id: int = 0) -> "UserProfile":
    return UserProfile(
        user_id=user_id,
        diversity_tolerance=0.4,
        randomness=0.4,
        topic_preferences=[],
        strategy_weights=dict(DEFAULT_STRATEGY_WEIGHTS),
    )


class UserInfo(BaseModel):
    id: int
    username: str
    email: EmailStr
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

    def model_post_init(self, __context) -> None:
        object.__setattr__(self, "created_at", ensure_utc(self.created_at))

    @field_serializer("created_at")
    def serialize_created_at(self, value: datetime.datetime) -> str:
        return utc_iso_z(value)


# Doesnt need ID or Register Time autofilled by DB 
class CreateUser(BaseModel):
    username: str = Field(min_length=1, max_length=20)
    email: EmailStr = Field(max_length=80)
    password: str = Field(min_length=5, max_length=40) ## logical limit at api side truly capped at 60 for hash at db 


class EmailUpdate(BaseModel):
    email: EmailStr = Field(max_length=80)


# Shared preference fields — used for both profile load and preference updates
class PrefsUpdate(BaseModel):
    diversity_tolerance: float
    randomness: float
    topic_preferences: list[TopicPreference]
    use_view_time: bool = False
    view_time_weight: float = 0.1
    use_recency: bool = True
    ai_topic_detection: bool = False

    # feed composition, e.g. {"similar": 0.6, "opposite": 0.2, "random": 0.2}
    strategy_weights: dict[str, float]


class UserProfile(PrefsUpdate):
    user_id: int
