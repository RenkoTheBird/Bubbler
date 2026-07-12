from pydantic import BaseModel, Field, field_serializer
from typing import Optional, Literal
import datetime

from app.db.datetime_utils import ensure_utc, utc_iso_z


class PostTopic(BaseModel):
    post_id: str
    topic_name: str
    weight: float
    source: Literal["user", "ai"] = "user"
    confidence: float = Field(default=1.0, ge=0, le=1)


class PostTopicMutation(BaseModel):
    topic: str = Field(min_length=1)


class PostCreate(BaseModel):
    post: str = Field(min_length=1)
    topic: Optional[str] = None


class PostUpdate(BaseModel):
    post: str = Field(min_length=1)


class Post(BaseModel):
    id: str
    user_id: int
    content: str
    embedding: Optional[list[float]] = None
    created_at: datetime.datetime
    topic: Optional[str] = None

    def model_post_init(self, __context) -> None:
        object.__setattr__(self, "created_at", ensure_utc(self.created_at))

    @field_serializer("created_at")
    def serialize_created_at(self, value: datetime.datetime) -> str:
        return utc_iso_z(value)


class Interaction(BaseModel):
    id: str
    user_id: str
    post_id: str
    type: str # what they did
    created_at: datetime.datetime
    topic: str
    
    view_time: float
    liked: bool

    def model_post_init(self, __context) -> None:
        object.__setattr__(self, "created_at", ensure_utc(self.created_at))

    @field_serializer("created_at")
    def serialize_created_at(self, value: datetime.datetime) -> str:
        return utc_iso_z(value)

class InteractionCreate(BaseModel):
    post_id: str 
    type: Literal['like', 'skip', 'explore']
    view_time: float = Field(default=0.0, ge=0)

class Topic(BaseModel):
    id: str
    name: str
    parent_topic_id: Optional[str] = None