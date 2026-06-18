from pydantic import BaseModel, EmailStr
import datetime


class CreateUser(BaseModel):
    username: str
    email: EmailStr
    password: str
    
class UserLoggin(BaseModel):
    email: EmailStr
    password: str

# To load an user profile 
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
