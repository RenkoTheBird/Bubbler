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


def _normalize_topic(topic: str | None) -> str | None:
    if not isinstance(topic, str) or not topic.strip():
        return None
    return topic.strip().casefold()


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
            normalized_topic = _normalize_topic(post_topic)

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


# Target mix for graph "next" choices: deepen, bridge, jump, explore.
_NEXT_EDGE_QUOTA = (
    ("topic", 1),
    ("similar", 1),
    ("bridge", 1),
    ("opposite", 1),
)
_NEXT_CHOICE_LIMIT = 4
_EDGE_TYPE_SCORE_BONUS = {
    "bridge": 0.15,
    "opposite": 0.1,
    "similar": 0.05,
    "topic": 0.0,
}


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

    async def get_new_session_posts(self, user_id: int, *, diversify: bool = False):
        prefs = await self.user_repo.get_prefs(user_id)
        _, blacklisted = _topic_sets(prefs.topic_preferences)
        yesterday_post, liked_topic = await self._yesterday_liked_signal(user_id)

        candidates, seed_strategy, max_per_topic = await self.repo.get_new_session_posts(
            prefs.diversity_tolerance,
            yesterday_post,
            liked_topic,
            blacklisted_topics=blacklisted,
            diversify=diversify,
        )

        ranked = self.ranking_service.apply_preferences(prefs, candidates)
        selected = self._select_topic_diverse(
            ranked,
            limit=6,
            max_per_topic=max_per_topic,
        )

        posts = []
        for post in selected:
            public_post = {
                key: value
                for key, value in post.items()
                if not str(key).startswith("_") and key != "score"
            }
            posts.append(with_utc_created_at(public_post))

        return {
            "posts": posts,
            "seed_strategy": seed_strategy,
            "diversify": diversify,
        }

    @staticmethod
    def _select_topic_diverse(
        posts: list[dict],
        *,
        limit: int,
        max_per_topic: int,
    ) -> list[dict]:
        selected: list[dict] = []
        topic_counts: dict[str, int] = {}

        for post in posts:
            if len(selected) >= limit:
                break
            topic = _normalize_topic(post.get("topic"))
            key = topic if topic else f"_none:{post['id']}"
            if topic_counts.get(key, 0) >= max_per_topic:
                continue
            topic_counts[key] = topic_counts.get(key, 0) + 1
            selected.append(post)

        if len(selected) < limit:
            selected_ids = {p["id"] for p in selected}
            for post in posts:
                if len(selected) >= limit:
                    break
                if post["id"] in selected_ids:
                    continue
                selected.append(post)
                selected_ids.add(post["id"])

        return selected

    async def get_next_posts(self, user_id: int, post_id: str):
        prefs = await self.user_repo.get_prefs(user_id)
        preferred_topics, blacklisted_topics = _topic_sets(prefs.topic_preferences)

        async with self.repo.acquire() as conn:
            current_rows = await self.repo.get_posts_by_ids([post_id], conn=conn)
            current_topic = (
                _normalize_topic(current_rows[0].get("topic")) if current_rows else None
            )
            edges = await self.repo.get_outbound_edges_by_type(post_id, conn=conn)
            ids = [edge.to_post_id for edge in edges]
            posts = await self.repo.get_posts_by_ids(ids, conn=conn)

        posts_by_id = {post["id"]: post for post in posts}
        candidates: list[dict] = []
        for edge in edges:
            post = posts_by_id.get(edge.to_post_id)
            if not post:
                continue
            normalized_topic = _normalize_topic(post.get("topic"))
            if normalized_topic and normalized_topic in blacklisted_topics:
                continue

            weight = float(edge.weight) if edge.weight is not None else 0.0
            score = weight + _EDGE_TYPE_SCORE_BONUS.get(edge.type, 0.0)
            if normalized_topic and normalized_topic in preferred_topics:
                score += 0.3
            # Prefer different-topic hops for bridge/opposite, slight novelty for others.
            if current_topic and normalized_topic and normalized_topic != current_topic:
                score += 0.12
            elif edge.type in ("bridge", "opposite"):
                score += 0.05
            score += random.random() * prefs.randomness

            candidate = dict(post)
            candidate["similarity"] = weight
            candidate["score"] = score
            candidate["_edge_type"] = edge.type
            candidates.append(candidate)

        selected = self._select_next_quota(candidates, current_topic=current_topic)
        cleaned = []
        for post in selected:
            public_post = {
                key: value
                for key, value in post.items()
                if not str(key).startswith("_") and key != "score"
            }
            cleaned.append(with_utc_created_at(public_post))
        return cleaned

    def _select_next_quota(
        self,
        candidates: list[dict],
        *,
        current_topic: str | None,
        limit: int = _NEXT_CHOICE_LIMIT,
    ) -> list[dict]:
        by_type: dict[str, list[dict]] = {}
        for candidate in sorted(
            candidates, key=lambda p: p.get("score", 0), reverse=True
        ):
            edge_type = candidate.get("_edge_type", "similar")
            by_type.setdefault(edge_type, []).append(candidate)

        selected: list[dict] = []
        selected_ids: set[str] = set()
        same_topic_count = 0
        max_same_topic = max(1, limit // 2)

        def try_add(post: dict) -> bool:
            nonlocal same_topic_count
            if len(selected) >= limit:
                return False
            post_id = post["id"]
            if post_id in selected_ids:
                return False
            topic = _normalize_topic(post.get("topic"))
            is_same = bool(current_topic and topic and topic == current_topic)
            if is_same and same_topic_count >= max_same_topic:
                return False
            selected.append(post)
            selected_ids.add(post_id)
            if is_same:
                same_topic_count += 1
            return True

        for edge_type, quota in _NEXT_EDGE_QUOTA:
            taken = 0
            for post in by_type.get(edge_type, []):
                if taken >= quota:
                    break
                if try_add(post):
                    taken += 1

        if len(selected) < limit:
            leftovers = sorted(
                candidates, key=lambda p: p.get("score", 0), reverse=True
            )
            for post in leftovers:
                if len(selected) >= limit:
                    break
                try_add(post)

        return selected
