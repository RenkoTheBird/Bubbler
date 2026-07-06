import datetime

from pydantic import BaseModel, EmailStr, Field

DEFAULT_STRATEGY_WEIGHTS: dict[str, float] = {
    "similar": 0.7,
    "graph": 0.2,
    "opposite": 0.0,
    "random": 0.1,
}


def default_user_prefs(user_id: int = 0) -> "UserProfile":
    return UserProfile(
        user_id=user_id,
        diversity_tolerance=0.4,
        randomness=0.3,
        preferred_topics=[],
        blacklisted_topics=[],
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
    preferred_topics: list[str]
    blacklisted_topics: list[str]
    use_view_time: bool = False
    view_time_weight: float = 0.1

    # feed composition, e.g. {"similar": 0.6, "opposite": 0.2, "random": 0.2}
    strategy_weights: dict[str, float]

# Update user preferences
class PrefsUpdate(BaseModel):
    # preferences (defaults removed)
    diversity_tolerance: float
    randomness: float
    preferred_topics: list[str]
    blacklisted_topics: list[str]
    use_view_time: bool
    view_time_weight: float

    # feed composition, e.g. {"similar": 0.6, "opposite": 0.2, "random": 0.2}
    strategy_weights: dict[str, float]
