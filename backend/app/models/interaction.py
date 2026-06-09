from pydantic import BaseModel
import datetime

class Interaction(BaseModel):
    id: str
    user_id: str
    post_id: str
    type: str # what they did
    created_at: datetime.datetime
    topic: str
    
    view_time: float
    liked: bool