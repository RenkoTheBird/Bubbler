from typing import Optional

from pydantic import BaseModel


class Edge(BaseModel):
    id: str
    from_post_id: str
    to_post_id: str
    type: str  # similar, opposite, topic, bridge
    weight: Optional[float] = None
