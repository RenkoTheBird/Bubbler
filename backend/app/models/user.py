from dataclasses import dataclass
import datetime

@dataclass
class User:
    id: int
    username: str
    email: str
    created_at: datetime.datetime