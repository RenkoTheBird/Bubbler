from pydantic import BaseModel, Field
from typing import Optional, Literal
import datetime


class PostTopic(BaseModel):
    post_id: str
    topic_name: str
    weight: float
    source: Literal["user", "ai"] = "user"
    confidence: float = Field(default=1.0, ge=0, le=1)


class PostTopicMutation(BaseModel):
    topic: str = Field(min_length=1)


class Post(BaseModel):
    id: str
    user_id: int
    content: str
    embedding: Optional[list[float]] = None
    created_at: datetime.datetime
    topic: Optional[str] = None


class Interaction(BaseModel):
    id: str
    user_id: str
    post_id: str
    type: str # what they did
    created_at: datetime.datetime
    topic: str
    
    view_time: float
    liked: bool

class InteractionCreate(BaseModel):
    post_id: str 
    type: Literal['like', 'skip', 'explore']
    view_time: float = Field(default=0.0, ge=0)

class Topic(BaseModel):
    id: str
    name: str
    parent_topic_id: Optional[str] = None