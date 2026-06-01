from dataclasses import dataclass

# this class is distinct from users, 
# preferences are located here 
@dataclass
class UserProfile:
    user_id: int
    diversity_tolerance: int