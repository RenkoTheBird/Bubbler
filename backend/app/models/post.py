from dataclasses import dataclass
from typing import List, Optional

@dataclass
class Post:
    id: int
    user_id: int
    content: str
    embedding: Optional[List[float]] = None

