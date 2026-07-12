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
        topic_scores: dict[str, float] = {}

        for i in interactions:
            if not isinstance(i.topic, str) or not i.topic.strip():
                continue
            topic = i.topic.strip().casefold()

            if i.liked:
                topic_scores[topic] = topic_scores.get(topic, 0) + 1

            if prefs.use_view_time:
                topic_scores[topic] = topic_scores.get(topic, 0) + (
                    i.view_time * prefs.view_time_weight
                )

        sorted_topics = sorted(topic_scores.items(), key=lambda x: x[1], reverse=True)
        preferred, blacklisted = _topic_sets(prefs.topic_preferences)

        for name, _ in sorted_topics[:5]:
            if name not in blacklisted:
                preferred.add(name)

        prefs.topic_preferences = [
            TopicPreference(topic=topic, preference_type="preferred")
            for topic in sorted(preferred)
        ] + [
            TopicPreference(topic=topic, preference_type="blacklisted")
            for topic in sorted(blacklisted)
        ]

        return prefs


class RankingService:
    def score(self, post, similarity: float) -> float:
        created_at = post.get("created_at")
        if created_at is None:
            return similarity

        now = datetime.datetime.now(datetime.timezone.utc)
        if getattr(created_at, "tzinfo", None) is None:
            created_at = created_at.replace(tzinfo=datetime.timezone.utc)

        age_days = max((now - created_at).total_seconds() / 86400.0, 0.0)
        recency_boost = 1 / (1 + age_days)
        return similarity * 0.7 + recency_boost * 0.3

    def apply_preferences(self, prefs, posts: List[str]):
        filtered = []
        preferred_topics, blacklisted_topics = _topic_sets(prefs.topic_preferences)
        use_recency = getattr(prefs, "use_recency", True)

        for post in posts:
            post_topic = post.get("topic")
            normalized_topic = (
                post_topic.strip().casefold()
                if isinstance(post_topic, str) and post_topic.strip()
                else None
            )

            if normalized_topic and normalized_topic in blacklisted_topics:
                continue

            similarity = post.get("similarity", 0)
            score = self.score(post, similarity) if use_recency else similarity

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
        original_topics = {
            (pref.topic.strip().casefold(), pref.preference_type)
            for pref in prefs.topic_preferences
            if isinstance(pref.topic, str) and pref.topic.strip()
        }
        prefs = self.PreferenceService.update_from_interactions(prefs, interactions)
        updated_topics = {
            (pref.topic.strip().casefold(), pref.preference_type)
            for pref in prefs.topic_preferences
            if isinstance(pref.topic, str) and pref.topic.strip()
        }
        if updated_topics != original_topics:
            prefs = await self.PrefRepo.save_prefs(userId, prefs)

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
            ids = [n.to_post_id for n in neighbors]
            return await self.repo.get_posts_by_ids(ids, conn=conn)
