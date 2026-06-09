from pydantic import BaseModel
from typing import List, Dict

# this class is distinct from users, 
# preferences are located here 
class UserProfile(BaseModel):
    user_id: int
    
    # preferences
    diversity_tolerance: float
    randomness: float
    preferred_topics: List[str]
    blacklisted_topics: List[str]
    use_view_time: bool = False
    view_time_weight: float = 0.1

    # feed composition, e.g. {"similar": 0.6, "opposite": 0.2, "random": 0.2}
    strategy_weights: Dict[str, float]

