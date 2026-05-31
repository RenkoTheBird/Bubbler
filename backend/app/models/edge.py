from dataclasses import dataclass

@dataclass
class Edge:
    id: str
    from_post_id: str
    to_post_id: str
    type: str # similarity, opposite, etc...