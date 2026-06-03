import math
import datetime
from ..models.post import Post
from typing import List

class RankingService:

    def score(self, post: Post, similarity: float):
        recencyBoost = 1 / (1 + (datetime.datetime.now() - post["created_at"]))
        return similarity * 0.7 + recencyBoost * 0.3
    
    def rank(self, posts):
        return sorted(posts, key=lambda p: p["score"], reverse=True)