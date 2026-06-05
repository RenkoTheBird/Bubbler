from pydantic import BaseModel

# this class is distinct from users, 
# preferences are located here 
class UserProfile(BaseModel):
    user_id: int
    diversity_tolerance: int