import random
import datetime
from ..models.post import Post
from typing import List

class RankingService:

    def score(self, post: Post, similarity: float):
        recencyBoost = 1 / (1 + (datetime.datetime.now() - post["created_at"]))
        return similarity * 0.7 + recencyBoost * 0.3
    
    def applyPreferences(self, prefs, posts: List[str]):
        filtered = []

        for post in posts:
            if post["topic"] in prefs.blacklisted_topics:
                continue
        
            # NOTE: only similarity for now
            score = post.get("similarity", 0)

            if post["topic"] in prefs.preferred_topics:
                score += 0.3

            # add some randomness!
            score += random.random() * prefs.randomness

            post["score"] = score 
            filtered.append(post)

        return sorted(filtered, key=lambda p: p["score"], reverse=True)