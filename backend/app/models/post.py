from pydantic import BaseModel
from typing import List, Optional
import datetime

class Post(BaseModel):
    id: int
    user_id: int
    content: str
    embedding: Optional[List[float]] = None
    created_at: datetime.datetime
    topic: str

