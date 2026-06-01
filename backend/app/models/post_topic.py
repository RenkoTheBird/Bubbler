from dataclasses import dataclass

@dataclass
class PostTopic:
    post_id: str
    topic_id: str
    weight: float