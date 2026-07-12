import datetime
from typing import Literal

from pydantic import BaseModel, EmailStr, Field

DEFAULT_STRATEGY_WEIGHTS: dict[str, float] = {
    "similar": 0.7,
    "graph": 0.2,
    "opposite": 0.0,
    "random": 0.1,
}


class TopicPreference(BaseModel):
    topic: str
    preference_type: Literal["preferred", "blacklisted"]


def default_user_prefs(user_id: int = 0) -> "UserProfile":
    return UserProfile(
        user_id=user_id,
        diversity_tolerance=0.4,
        randomness=0.3,
        topic_preferences=[],
        strategy_weights=dict(DEFAULT_STRATEGY_WEIGHTS),
    )


class UserInfo(BaseModel):
    id: int
    username: str
    email: EmailStr
    created_at: datetime.datetime


# Doesnt need ID or Register Time autofilled by DB 
class CreateUser(BaseModel):
    username: str = Field(min_length=1, max_length=20)
    email: EmailStr = Field(max_length=80)
    password: str = Field(min_length=5, max_length=40) ## logical limit at api side truly capped at 60 for hash at db 


# To load a user profile 
class UserProfile(BaseModel):
    user_id: int
    
    # preferences
    diversity_tolerance: float
    randomness: float
    topic_preferences: list[TopicPreference]
    use_view_time: bool = False
    view_time_weight: float = 0.1
    use_recency: bool = True
    ai_topic_detection: bool = False

    # feed composition, e.g. {"similar": 0.6, "opposite": 0.2, "random": 0.2}
    strategy_weights: dict[str, float]

# Update user preferences
class PrefsUpdate(BaseModel):
    # preferences (defaults removed)
    diversity_tolerance: float
    randomness: float
    topic_preferences: list[TopicPreference]
    use_view_time: bool
    view_time_weight: float
    use_recency: bool
    ai_topic_detection: bool

    # feed composition, e.g. {"similar": 0.6, "opposite": 0.2, "random": 0.2}
    strategy_weights: dict[str, float]
