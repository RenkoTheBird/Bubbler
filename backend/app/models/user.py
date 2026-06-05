from pydantic import BaseModel
import datetime

class User(BaseModel):
    id: int
    username: str
    email: str
    password_hash: str
    created_at: datetime.datetime