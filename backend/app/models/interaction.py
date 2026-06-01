from dataclasses import dataclass
import datetime

@dataclass
class Interaction:
    id: str
    user_id: str
    post_id: str
    type: str
    created_at: datetime.datetime