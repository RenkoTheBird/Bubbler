from pydantic import BaseModel
import datetime

class Interaction(BaseModel):
    id: str
    user_id: str
    post_id: str
    type: str
    created_at: datetime.datetime