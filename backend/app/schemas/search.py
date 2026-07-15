from pydantic import BaseModel, Field

from app.schemas.post import Post


class SearchResponse(BaseModel):
    """Hybrid search: keyword/exact hits first, then related semantic neighbors."""

    query: str
    exact_matches: list[Post] = Field(default_factory=list)
    related: list[Post] = Field(default_factory=list)
