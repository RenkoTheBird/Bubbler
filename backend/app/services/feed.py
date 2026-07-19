import random
import datetime
import math
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
    def view_time_topic_boosts(self, prefs, interactions) -> dict[str, float]:
        """Return bounded topic boosts from recent viewing behavior."""
        if not prefs.use_view_time:
            return {}

        topic_scores: dict[str, float] = {}
        for i in interactions:
            if not isinstance(i.topic, str) or not i.topic.strip():
                continue
            topic = i.topic.strip().casefold()
            topic_scores[topic] = topic_scores.get(topic, 0.0) + max(
                float(i.view_time), 0.0
            )

        if not topic_scores:
            return {}

        strongest = max(math.log1p(seconds) for seconds in topic_scores.values())
        if strongest <= 0:
            return {}

        weight = min(max(float(prefs.view_time_weight), 0.0), 1.0)
        return {
            topic: 0.3 * weight * (math.log1p(seconds) / strongest)
            for topic, seconds in topic_scores.items()
        }


class RankingService:
    RANDOMNESS_SCORE_SCALE = 0.15

    def recency_bonus(self, post, max_bonus: float = 0.3) -> float:
        created_at = post.get("created_at")
        if created_at is None:
            return 0.0

        now = datetime.datetime.now(datetime.timezone.utc)
        if getattr(created_at, "tzinfo", None) is None:
            created_at = created_at.replace(tzinfo=datetime.timezone.utc)

        age_days = max((now - created_at).total_seconds() / 86400.0, 0.0)
        return max_bonus / (1 + age_days)

    def apply_preferences(
        self,
        prefs,
        posts: List[dict],
        *,
        view_time_boosts: dict[str, float] | None = None,
    ):
        filtered = []
        preferred_topics, blacklisted_topics = _topic_sets(prefs.topic_preferences)
        use_recency = getattr(prefs, "use_recency", True)
        view_time_boosts = view_time_boosts or {}

        for post in posts:
            post_topic = post.get("topic")
            normalized_topic = _normalize_topic(post_topic)

            if normalized_topic and normalized_topic in blacklisted_topics:
                continue

            similarity = post.get("similarity", 0)
            score = post.get("score", similarity)
            if use_recency:
                score += self.recency_bonus(post)

            if normalized_topic and normalized_topic in preferred_topics:
                score += 0.3
            if normalized_topic:
                score += view_time_boosts.get(normalized_topic, 0.0)

            score += (
                random.random()
                * min(max(float(prefs.randomness), 0.0), 1.0)
                * self.RANDOMNESS_SCORE_SCALE
            )

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


_NEXT_CHOICE_LIMIT = 4
_EDGE_TYPE_SCORE_BONUS = {
    "bridge": 0.15,
    "opposite": 0.1,
    "similar": 0.05,
    "topic": 0.0,
    "random": 0.0,
}
_EDGE_STRATEGY = {
    "topic": "graph",
    "bridge": "graph",
    "similar": "similar",
    "opposite": "opposite",
    "random": "random",
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
        view_time_boosts = self.preference_service.view_time_topic_boosts(
            prefs, interactions
        )

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

        seed_posts = self._select_strategy_seeds(
            strategy_results,
            prefs.strategy_weights,
            limit=10,
        )
        async with self.repo.acquire() as conn:
            expanded_ids = await self.graph_service.expand_posts(seed_posts, conn=conn)
            all_ids = set(p["id"] for p in seed_posts) | set(expanded_ids)
            expanded_posts = await self.repo.get_posts_by_ids(list(all_ids), conn=conn)

        seed_map: dict[str, dict] = {}
        for post in seeds:
            strategy = post.get("_strategy", "graph")
            candidate_score = self._strategy_score(
                strategy,
                post.get("similarity"),
                prefs.strategy_weights,
            )
            current = seed_map.get(post["id"])
            if current is None or candidate_score > current["_strategy_score"]:
                mapped = dict(post)
                mapped["_strategy_score"] = candidate_score
                seed_map[post["id"]] = mapped

        for post in expanded_posts:
            if post["id"] in seed_map:
                post["similarity"] = seed_map[post["id"]].get("similarity", 0)
                post["_strategy"] = seed_map[post["id"]].get("_strategy", "graph")
                post["score"] = seed_map[post["id"]]["_strategy_score"]
            else:
                post["similarity"] = 0.3
                post["_strategy"] = "graph"
                post["score"] = self._strategy_score(
                    "graph", 0.3, prefs.strategy_weights
                )

        ranked = self.ranking_service.apply_preferences(
            prefs,
            expanded_posts,
            view_time_boosts=view_time_boosts,
        )

        return [with_utc_created_at(post) for post in ranked[:20]]

    async def get_new_session_posts(self, user_id: int, *, diversify: bool = False):
        prefs = await self.user_repo.get_prefs(user_id)
        _, blacklisted = _topic_sets(prefs.topic_preferences)
        yesterday_post, liked_topic = await self._yesterday_liked_signal(user_id)
        interactions = await self.interaction_repo.get_recent_interactions(user_id)
        view_time_boosts = self.preference_service.view_time_topic_boosts(
            prefs, interactions
        )

        candidates, seed_strategy, max_per_topic = await self.repo.get_new_session_posts(
            prefs.diversity_tolerance,
            yesterday_post,
            liked_topic,
            blacklisted_topics=blacklisted,
            diversify=diversify,
        )

        for post in candidates:
            strategy = post.get("_strategy", "random")
            post["score"] = self._strategy_score(
                strategy,
                post.get("similarity"),
                prefs.strategy_weights,
            )

        ranked = self.ranking_service.apply_preferences(
            prefs,
            candidates,
            view_time_boosts=view_time_boosts,
        )
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
        interactions = await self.interaction_repo.get_recent_interactions(user_id)
        view_time_boosts = self.preference_service.view_time_topic_boosts(
            prefs, interactions
        )

        async with self.repo.acquire() as conn:
            current_rows = await self.repo.get_posts_by_ids([post_id], conn=conn)
            current_topic = (
                _normalize_topic(current_rows[0].get("topic")) if current_rows else None
            )
            edges = await self.repo.get_outbound_edges_by_type(post_id, conn=conn)
            ids = [edge.to_post_id for edge in edges]
            posts = await self.repo.get_posts_by_ids(ids, conn=conn)
            random_posts = (
                await self.repo.get_random_posts(limit=8, conn=conn)
                if prefs.strategy_weights.get("random", 0) > 0
                else []
            )

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
            strategy = _EDGE_STRATEGY.get(edge.type, "graph")
            strategy_weight = max(
                float(prefs.strategy_weights.get(strategy, 0.0)), 0.0
            )
            score = self._strategy_score(
                strategy, weight, prefs.strategy_weights
            ) + (_EDGE_TYPE_SCORE_BONUS.get(edge.type, 0.0) * strategy_weight)
            if normalized_topic and normalized_topic in preferred_topics:
                score += 0.3
            if normalized_topic:
                score += view_time_boosts.get(normalized_topic, 0.0)
            if prefs.use_recency:
                score += self.ranking_service.recency_bonus(post)
            # Prefer different-topic hops for bridge/opposite, slight novelty for others.
            if current_topic and normalized_topic and normalized_topic != current_topic:
                score += 0.12
            elif edge.type in ("bridge", "opposite"):
                score += 0.05
            score += (
                random.random()
                * min(max(float(prefs.randomness), 0.0), 1.0)
                * self.ranking_service.RANDOMNESS_SCORE_SCALE
            )

            candidate = dict(post)
            candidate["similarity"] = weight
            candidate["score"] = score
            candidate["_edge_type"] = edge.type
            candidates.append(candidate)

        existing_ids = {post_id, *(candidate["id"] for candidate in candidates)}
        for post in random_posts:
            if post["id"] in existing_ids:
                continue
            normalized_topic = _normalize_topic(post.get("topic"))
            if normalized_topic and normalized_topic in blacklisted_topics:
                continue
            score = self._strategy_score("random", None, prefs.strategy_weights)
            if normalized_topic and normalized_topic in preferred_topics:
                score += 0.3
            if normalized_topic:
                score += view_time_boosts.get(normalized_topic, 0.0)
            if prefs.use_recency:
                score += self.ranking_service.recency_bonus(post)
            score += (
                random.random()
                * min(max(float(prefs.randomness), 0.0), 1.0)
                * self.ranking_service.RANDOMNESS_SCORE_SCALE
            )
            candidate = dict(post)
            candidate["similarity"] = 0.0
            candidate["score"] = score
            candidate["_edge_type"] = "random"
            candidates.append(candidate)
            existing_ids.add(post["id"])

        selected = self._select_next_quota(
            candidates,
            current_topic=current_topic,
            diversity_tolerance=prefs.diversity_tolerance,
            strategy_weights=prefs.strategy_weights,
        )
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
        diversity_tolerance: float,
        strategy_weights: dict[str, float],
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
        diversity = min(max(float(diversity_tolerance), 0.0), 1.0)
        if diversity >= 2 / 3:
            topic_quota = 0
            max_same_topic = 1
        elif diversity <= 1 / 3:
            topic_quota = min(2, limit)
            max_same_topic = min(3, limit)
        else:
            topic_quota = 1
            max_same_topic = min(2, limit)

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

        quotas: list[tuple[str, int]] = []
        if topic_quota:
            quotas.append(("topic", topic_quota))

        remaining = max(0, limit - topic_quota)
        strategy_quota = self._weighted_quotas(
            {
                "similar": strategy_weights.get("similar", 0.0),
                "bridge": strategy_weights.get("graph", 0.0),
                "opposite": strategy_weights.get("opposite", 0.0),
                "random": strategy_weights.get("random", 0.0),
            },
            remaining,
        )
        quotas.extend((edge_type, quota) for edge_type, quota in strategy_quota.items())

        for edge_type, quota in quotas:
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

    @staticmethod
    def _strategy_score(
        strategy: str,
        similarity: float | None,
        strategy_weights: dict[str, float],
    ) -> float:
        weight = max(float(strategy_weights.get(strategy, 0.0)), 0.0)
        if strategy == "opposite":
            relevance = (1.0 - float(similarity or 0.0)) / 2.0
        elif strategy == "random":
            relevance = 0.5
        else:
            relevance = max(float(similarity or 0.0), 0.0)
        return relevance * weight

    @staticmethod
    def _weighted_quotas(weights: dict[str, float], slots: int) -> dict[str, int]:
        if slots <= 0:
            return {key: 0 for key in weights}
        positive = {key: max(float(value), 0.0) for key, value in weights.items()}
        total = sum(positive.values())
        if total <= 0:
            positive = {key: 1.0 for key in weights}
            total = float(len(positive))

        raw = {key: slots * value / total for key, value in positive.items()}
        quotas = {key: int(value) for key, value in raw.items()}
        unassigned = slots - sum(quotas.values())
        order = sorted(
            raw,
            key=lambda key: (raw[key] - quotas[key], positive[key]),
            reverse=True,
        )
        for key in order[:unassigned]:
            quotas[key] += 1
        return quotas

    @classmethod
    def _select_strategy_seeds(
        cls,
        strategy_results: list[tuple[str, list[dict]]],
        strategy_weights: dict[str, float],
        *,
        limit: int,
    ) -> list[dict]:
        available = {name: posts for name, posts in strategy_results if posts}
        quotas = cls._weighted_quotas(
            {
                name: strategy_weights.get(name, 0.0)
                for name in available
            },
            limit,
        )
        selected: list[dict] = []
        seen: set[str] = set()

        for name, posts in available.items():
            taken = 0
            for post in posts:
                if taken >= quotas.get(name, 0):
                    break
                if post["id"] in seen:
                    continue
                selected.append(post)
                seen.add(post["id"])
                taken += 1

        if len(selected) < limit:
            leftovers = [
                post
                for _, posts in strategy_results
                for post in posts
                if post["id"] not in seen
            ]
            leftovers.sort(
                key=lambda post: cls._strategy_score(
                    post.get("_strategy", "graph"),
                    post.get("similarity"),
                    strategy_weights,
                ),
                reverse=True,
            )
            for post in leftovers:
                if len(selected) >= limit:
                    break
                if post["id"] in seen:
                    continue
                selected.append(post)
                seen.add(post["id"])

        return selected
