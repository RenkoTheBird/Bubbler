from dataclasses import dataclass

@dataclass
class Topic:
    id: str
    name: str
    parent_topic_id: int