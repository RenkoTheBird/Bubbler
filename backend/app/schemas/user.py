from pydantic import BaseModel, EmailStr , Field

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
