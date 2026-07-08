import random
import datetime
from typing import List

from app.schemas.user import TopicPreference


def _topic_sets(topic_preferences: list[TopicPreference]) -> tuple[set[str], set[str]]:
    preferred: set[str] = set()
    blacklisted: set[str] = set()
    for pref in topic_preferences:
        if not isinstance(pref.topic, str) or not pref.topic.strip():
            continue
        normalized = pref.topic.strip().casefold()
        if pref.preference_type == "preferred":
            preferred.add(normalized)
        elif pref.preference_type == "blacklisted":
            blacklisted.add(normalized)
    return preferred, blacklisted


class PreferenceService:
    def update_from_interactions(self, prefs, interactions):
        topicScores = {}

        for i in interactions:
            if i.liked:
                topicScores[i.topic] = topicScores.get(i.topic, 0) + 1

            if prefs.use_view_time:
                topicScores[i.topic] = topicScores.get(i.topic, 0) + (i.view_time * prefs.view_time_weight)

        sortedTopics = sorted(topicScores.items(), key=lambda x: x[1], reverse=True)

        blacklisted = [
            pref for pref in prefs.topic_preferences
            if pref.preference_type == "blacklisted"
        ]
        preferred = [
            TopicPreference(topic=name, preference_type="preferred")
            for name, _ in sortedTopics[:5]
            if isinstance(name, str) and name.strip()
        ]
        prefs.topic_preferences = blacklisted + preferred

        return prefs


class RankingService:
    def score(self, post, similarity: float):
        recencyBoost = 1 / (1 + (datetime.datetime.now() - post["created_at"]))
        return similarity * 0.7 + recencyBoost * 0.3

    def apply_preferences(self, prefs, posts: List[str]):
        filtered = []
        preferred_topics, blacklisted_topics = _topic_sets(prefs.topic_preferences)

        for post in posts:
            post_topic = post.get("topic")
            normalized_topic = (
                post_topic.strip().casefold()
                if isinstance(post_topic, str) and post_topic.strip()
                else None
            )

            if normalized_topic and normalized_topic in blacklisted_topics:
                continue

            score = post.get("similarity", 0)

            if normalized_topic and normalized_topic in preferred_topics:
                score += 0.3

            score += random.random() * prefs.randomness

            post["score"] = score
            filtered.append(post)

        return sorted(filtered, key=lambda p: p["score"], reverse=True)


class StrategyService:
    def __init__(self, repo, service):
        self.repo = repo # feed repo
        self.service = service # graph service

    async def get_candidates(self, embedding, prefs):
        strategies = []
        weights = prefs.strategy_weights

        async with self.repo.acquire() as conn:
            similar_posts = None
            if weights.get("similar", 0) > 0 or weights.get("graph", 0) > 0:
                similar_posts = await self.repo.get_similar_posts(
                    embedding, limit=10, conn=conn
                )
                if weights.get("similar", 0) > 0:
                    strategies.append(("similar", similar_posts))

            if weights.get("opposite", 0) > 0:
                opposite = await self.repo.get_opposite_posts(
                    embedding, limit=10, conn=conn
                )
                strategies.append(("opposite", opposite))

            if weights.get("graph", 0) > 0:
                base = (similar_posts or await self.repo.get_similar_posts(
                    embedding, limit=5, conn=conn
                ))[:5]
                expanded_ids = await self.service.expand_posts(base, conn=conn)
                graph_posts = await self.repo.get_posts_by_ids(expanded_ids, conn=conn)
                strategies.append(("graph", graph_posts))

            if weights.get("random", 0) > 0:
                random_posts = await self.repo.get_random_posts(limit=10, conn=conn)
                strategies.append(("random", random_posts))

        return strategies


class FeedService:
    def __init__(self,
                 repo,
                 GraphService,
                 RankingService: RankingService,
                 EmbeddingService,
                 StrategyService: StrategyService,
                 PreferenceService: PreferenceService,
                 PrefRepo,
                 InteractionRepo
                 ):
        self.repo = repo
        self.GraphService = GraphService
        self.RankingService = RankingService
        self.EmbeddingService = EmbeddingService
        self.StrategyService = StrategyService
        self.PreferenceService = PreferenceService
        self.PrefRepo = PrefRepo
        self.InteractionRepo = InteractionRepo

    async def get_feed(self, userId: int, userInput: str):
        prefs = await self.PrefRepo.get_prefs(userId)
        interactions = await self.InteractionRepo.get_recent_interactions(userId)
        prefs = self.PreferenceService.update_from_interactions(prefs, interactions)

        embedding = self.EmbeddingService.embed_text(userInput)

        strategyResults = await self.StrategyService.get_candidates(embedding, prefs)

        seeds = []
        for strategyName, posts in strategyResults:
            for p in posts:
                p["_strategy"] = strategyName
                seeds.append(p)

        seedPosts = seeds[:10]
        async with self.repo.acquire() as conn:
            expandedIds = await self.GraphService.expand_posts(seedPosts, conn=conn)
            allIds = set(p["id"] for p in seedPosts) | set(expandedIds)
            expandedPosts = await self.repo.get_posts_by_ids(list(allIds), conn=conn)

        seedMap = {p["id"]: p for p in seeds}

        for post in expandedPosts:
            if post["id"] in seedMap:
                post["similarity"] = seedMap[post["id"]].get("similarity", 0)
                post["_strategy"] = seedMap[post["id"]].get("_strategy", "graph")
            else:
                post["similarity"] = 0.3
                post["_strategy"] = "graph"

        weighted = []
        for post in expandedPosts:
            strategy = post.get("_strategy", "graph")
            weight = prefs.strategy_weights.get(strategy, 0.1)
            post["score"] = post["similarity"] * weight
            weighted.append(post)

        ranked = self.RankingService.apply_preferences(prefs, weighted)

        return ranked[:20]

    async def get_new_session_posts(self, userId: int):
        prefs = await self.PrefRepo.get_prefs(userId)
        return await self.repo.get_new_session_posts(prefs.diversity_tolerance, None, None)
    
    async def get_next_posts(self, post_id):
        async with self.repo.acquire() as conn:
            neighbors = await self.repo.get_neighbors(post_id, limit=4, conn=conn)
            ids = [n["to_post_id"] for n in neighbors]
            return await self.repo.get_posts_by_ids(ids, conn=conn)
