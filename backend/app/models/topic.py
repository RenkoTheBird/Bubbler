from pydantic import BaseModel

class Topic(BaseModel):
    id: str
    name: str
    parent_topic_id: int