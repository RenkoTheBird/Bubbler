import random
import datetime
from typing import List

from app.db.datetime_utils import with_utc_created_at
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
        """Optionally boost preferred topics from view time only.

        Likes never auto-prefer a topic — preferred/blacklisted topics are
        managed explicitly via user preference updates.
        """
        if not prefs.use_view_time:
            return prefs

        topic_scores: dict[str, float] = {}

        for i in interactions:
            if not isinstance(i.topic, str) or not i.topic.strip():
                continue
            topic = i.topic.strip().casefold()
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
    def __init__(self, repo):
        self.repo = repo  # FeedRepository

    async def get_candidates(self, embedding, prefs):
        strategies = []
        weights = prefs.strategy_weights

        async with self.repo.acquire() as conn:
            # Similar fetch also seeds graph when similar weight is 0.
            # Expansion happens once in FeedService.get_feed — not here.
            if weights.get("similar", 0) > 0 or weights.get("graph", 0) > 0:
                similar_posts = await self.repo.get_similar_posts(
                    embedding, limit=10, conn=conn
                )
                if weights.get("similar", 0) > 0:
                    strategies.append(("similar", similar_posts))
                elif weights.get("graph", 0) > 0:
                    strategies.append(("graph", similar_posts[:5]))

            if weights.get("opposite", 0) > 0:
                opposite = await self.repo.get_opposite_posts(
                    embedding, limit=10, conn=conn
                )
                strategies.append(("opposite", opposite))

            if weights.get("random", 0) > 0:
                random_posts = await self.repo.get_random_posts(limit=10, conn=conn)
                strategies.append(("random", random_posts))

        return strategies


class FeedService:
    def __init__(
        self,
        repo,
        graph_service,
        ranking_service: RankingService,
        embedding_service,
        strategy_service: StrategyService,
        preference_service: PreferenceService,
        user_repo,
        interaction_repo,
    ):
        self.repo = repo  # FeedRepository
        self.graph_service = graph_service
        self.ranking_service = ranking_service
        self.embedding_service = embedding_service
        self.strategy_service = strategy_service
        self.preference_service = preference_service
        self.user_repo = user_repo  # UserRepository (prefs)
        self.interaction_repo = interaction_repo
        # Per-user seed for session diversity: (utc_date, embedding, topic).
        # Refreshed when the UTC calendar day changes.
        self._yesterday_liked: dict[
            int, tuple[datetime.date, list[float] | None, str | None]
        ] = {}

    async def _yesterday_liked_signal(
        self, user_id: int
    ) -> tuple[list[float] | None, str | None]:
        today = datetime.datetime.now(datetime.timezone.utc).date()
        cached = self._yesterday_liked.get(user_id)
        if cached is not None and cached[0] == today:
            return cached[1], cached[2]

        # Drop stale day entries so the cache resets each day.
        self._yesterday_liked = {
            uid: entry
            for uid, entry in self._yesterday_liked.items()
            if entry[0] == today
        }

        embedding, topic = await self.interaction_repo.get_yesterday_liked_post(user_id)
        self._yesterday_liked[user_id] = (today, embedding, topic)
        return embedding, topic

    async def get_feed(self, user_id: int, user_input: str):
        prefs = await self.user_repo.get_prefs(user_id)
        interactions = await self.interaction_repo.get_recent_interactions(user_id)
        original_topics = {
            (pref.topic.strip().casefold(), pref.preference_type)
            for pref in prefs.topic_preferences
            if isinstance(pref.topic, str) and pref.topic.strip()
        }
        prefs = self.preference_service.update_from_interactions(prefs, interactions)
        updated_topics = {
            (pref.topic.strip().casefold(), pref.preference_type)
            for pref in prefs.topic_preferences
            if isinstance(pref.topic, str) and pref.topic.strip()
        }
        if updated_topics != original_topics:
            prefs = await self.user_repo.save_prefs(user_id, prefs)

        # Prefer an explicit query; otherwise embed preferred topics as user context.
        query_text = user_input.strip() if isinstance(user_input, str) else ""
        if not query_text:
            preferred, _ = _topic_sets(prefs.topic_preferences)
            query_text = " ".join(sorted(preferred))
        embedding = self.embedding_service.embed_text(query_text)

        strategy_results = await self.strategy_service.get_candidates(embedding, prefs)

        seeds = []
        for strategy_name, posts in strategy_results:
            for p in posts:
                p["_strategy"] = strategy_name
                seeds.append(p)

        seed_posts = seeds[:10]
        async with self.repo.acquire() as conn:
            expanded_ids = await self.graph_service.expand_posts(seed_posts, conn=conn)
            all_ids = set(p["id"] for p in seed_posts) | set(expanded_ids)
            expanded_posts = await self.repo.get_posts_by_ids(list(all_ids), conn=conn)

        seed_map = {p["id"]: p for p in seeds}

        for post in expanded_posts:
            if post["id"] in seed_map:
                post["similarity"] = seed_map[post["id"]].get("similarity", 0)
                post["_strategy"] = seed_map[post["id"]].get("_strategy", "graph")
            else:
                post["similarity"] = 0.3
                post["_strategy"] = "graph"

        weighted = []
        for post in expanded_posts:
            strategy = post.get("_strategy", "graph")
            weight = prefs.strategy_weights.get(strategy, 0.1)
            post["score"] = post["similarity"] * weight
            weighted.append(post)

        ranked = self.ranking_service.apply_preferences(prefs, weighted)

        return [with_utc_created_at(post) for post in ranked[:20]]

    async def get_new_session_posts(self, user_id: int):
        prefs = await self.user_repo.get_prefs(user_id)
        yesterday_post, liked_topic = await self._yesterday_liked_signal(user_id)
        posts = await self.repo.get_new_session_posts(
            prefs.diversity_tolerance, yesterday_post, liked_topic
        )
        return [with_utc_created_at(post) for post in posts]

    async def get_next_posts(self, user_id: int, post_id: str):
        prefs = await self.user_repo.get_prefs(user_id)
        # Over-fetch neighbors so blacklist / preference filtering still leaves choices.
        async with self.repo.acquire() as conn:
            neighbors = await self.repo.get_neighbors(post_id, limit=20, conn=conn)
            ids = [n.to_post_id for n in neighbors]
            posts = await self.repo.get_posts_by_ids(ids, conn=conn)

        weight_by_id = {
            n.to_post_id: float(n.weight) if n.weight is not None else 0.0
            for n in neighbors
        }
        for post in posts:
            post["similarity"] = weight_by_id.get(post["id"], 0.0)

        ranked = self.ranking_service.apply_preferences(prefs, posts)
        return [with_utc_created_at(post) for post in ranked[:4]]
