from pydantic import BaseModel

class PostTopic(BaseModel):
    post_id: str
    topic_id: str
    weight: float