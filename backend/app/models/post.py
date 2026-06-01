from dataclasses import dataclass
from typing import List, Optional
import datetime

@dataclass
class Post:
    id: int
    user_id: int
    content: str
    embedding: Optional[List[float]] = None
    created_at: datetime.datetime
    topic: str

