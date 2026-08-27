import datetime
import math
from typing import List

from app.db.datetime_utils import with_utc_created_at
from app.schemas.user import TopicPreference
from app.services.composition_utils import weighted_quotas
from app.services.post_composer import PostComposer
from app.services.topic_composer import TopicComposer


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


def _without_blocked_users(
    posts: list[dict],
    blocked_user_ids: set[int] | None,
) -> list[dict]:
    if not blocked_user_ids:
        return posts
    return [post for post in posts if post.get("user_id") not in blocked_user_ids]


def _normalize_topic(topic: str | None) -> str | None:
    if not isinstance(topic, str) or not topic.strip():
        return None
    return topic.strip().casefold()


def _composition_dict(composition) -> dict[str, float]:
    if hasattr(composition, "as_dict"):
        return composition.as_dict()
    return dict(composition)


def _max_per_topic_from_composition(topic_composition: dict[str, float]) -> int:
    surprise = float(topic_composition.get("surprise", 0.3))
    if surprise >= 0.6:
        return 1
    if surprise <= 0.25:
        return 3
    return 2


def _same_topic_cap(topic_composition: dict[str, float], limit: int) -> int:
    surprise = float(topic_composition.get("surprise", 0.3))
    similar = float(topic_composition.get("similar", 0.55))
    if surprise >= 0.5:
        return 1
    if similar >= 0.5:
        return min(3, limit)
    return min(2, limit)


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
        blocked_user_ids: set[int] | None = None,
    ):
        filtered = []
        preferred_topics, blacklisted_topics = _topic_sets(prefs.topic_preferences)
        use_recency = getattr(prefs, "use_recency", True)
        view_time_boosts = view_time_boosts or {}
        blocked_user_ids = blocked_user_ids or set()

        for post in posts:
            if post.get("user_id") in blocked_user_ids:
                continue

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

            post["score"] = score
            filtered.append(post)

        return sorted(filtered, key=lambda p: p["score"], reverse=True)


_NEXT_CHOICE_LIMIT = 4
_SESSION_LIMIT = 6


class FeedService:
    def __init__(
        self,
        repo,
        graph_service,
        ranking_service: RankingService,
        embedding_service,
        topic_composer: TopicComposer,
        post_composer: PostComposer,
        preference_service: PreferenceService,
        user_repo,
        interaction_repo,
    ):
        self.repo = repo
        self.graph_service = graph_service
        self.ranking_service = ranking_service
        self.embedding_service = embedding_service
        self.topic_composer = topic_composer
        self.post_composer = post_composer
        self.preference_service = preference_service
        self.user_repo = user_repo
        self.interaction_repo = interaction_repo
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

        self._yesterday_liked = {
            uid: entry
            for uid, entry in self._yesterday_liked.items()
            if entry[0] == today
        }

        embedding, topic = await self.interaction_repo.get_yesterday_liked_post(user_id)
        self._yesterday_liked[user_id] = (today, embedding, topic)
        return embedding, topic

    async def _compose_candidates(
        self,
        *,
        anchor_post_id: str | None,
        anchor_embedding: list[float],
        current_topic: str | None,
        topic_composition: dict[str, float],
        post_composition: dict[str, float],
        preferred_topics: set[str],
        blacklisted_topics: set[str],
        blocked_user_ids: set[int],
        topic_limit: int,
        post_limit: int,
        conn=None,
    ) -> list[dict]:
        topic_selections = await self.topic_composer.select_topics(
            current_topic,
            topic_composition,
            blacklisted=blacklisted_topics,
            preferred=preferred_topics,
            limit=topic_limit,
            conn=conn,
        )
        if anchor_post_id:
            return await self.post_composer.select_posts_for_topics(
                topic_selections,
                anchor_post_id,
                anchor_embedding,
                post_composition,
                blacklisted_user_ids=blocked_user_ids,
                limit=post_limit,
                conn=conn,
            )

        merged: list[dict] = []
        seen: set[str] = set()
        per_topic = max(1, post_limit // max(len(topic_selections), 1))
        for topic, topic_bucket in topic_selections:
            posts = await self.post_composer.select_posts_for_topic(
                topic,
                "",
                anchor_embedding,
                post_composition,
                topic_bucket=topic_bucket,
                blacklisted_user_ids=blocked_user_ids,
                limit=per_topic + 1,
                conn=conn,
            )
            for post in posts:
                if post["id"] in seen:
                    continue
                seen.add(post["id"])
                merged.append(post)
        merged.sort(key=lambda p: p.get("score", 0.0), reverse=True)
        return merged[: post_limit * 2]

    async def get_feed(self, user_id: int, user_input: str):
        prefs = await self.user_repo.get_prefs(user_id)
        blocked_user_ids = await self.user_repo.get_blocked_user_ids(user_id)
        preferred_topics, blacklisted_topics = _topic_sets(prefs.topic_preferences)
        interactions = await self.interaction_repo.get_recent_interactions(user_id)
        view_time_boosts = self.preference_service.view_time_topic_boosts(
            prefs, interactions
        )

        query_text = user_input.strip() if isinstance(user_input, str) else ""
        if not query_text:
            preferred, _ = _topic_sets(prefs.topic_preferences)
            query_text = " ".join(sorted(preferred)) or "general"
        embedding = self.embedding_service.embed_text(query_text)

        topic_comp = _composition_dict(prefs.topic_composition)
        post_comp = _composition_dict(prefs.post_composition)

        async with self.repo.acquire() as conn:
            similar_topics = await self.repo.get_similar_topics(
                embedding, 1, exclude_topics=list(blacklisted_topics), conn=conn
            )
            anchor_topic = similar_topics[0]["topic"] if similar_topics else None

            candidates = await self._compose_candidates(
                anchor_post_id=None,
                anchor_embedding=embedding,
                current_topic=anchor_topic,
                topic_composition=topic_comp,
                post_composition=post_comp,
                preferred_topics=preferred_topics,
                blacklisted_topics=blacklisted_topics,
                blocked_user_ids=blocked_user_ids,
                topic_limit=4,
                post_limit=10,
                conn=conn,
            )

            seed_posts = candidates[:10]
            expanded_ids = await self.graph_service.expand_posts(seed_posts, conn=conn)
            all_ids = set(p["id"] for p in seed_posts) | set(expanded_ids)
            expanded_posts = await self.repo.get_posts_by_ids(list(all_ids), conn=conn)

        seed_scores = {post["id"]: post.get("score", 0.0) for post in seed_posts}
        for post in expanded_posts:
            if post["id"] in seed_scores:
                post["score"] = seed_scores[post["id"]]
            else:
                post["score"] = 0.3

        ranked = self.ranking_service.apply_preferences(
            prefs,
            expanded_posts,
            view_time_boosts=view_time_boosts,
            blocked_user_ids=blocked_user_ids,
        )

        return [with_utc_created_at(post) for post in ranked[:20]]

    async def get_new_session_posts(self, user_id: int, *, diversify: bool = False):
        prefs = await self.user_repo.get_prefs(user_id)
        blocked_user_ids = await self.user_repo.get_blocked_user_ids(user_id)
        preferred_topics, blacklisted_topics = _topic_sets(prefs.topic_preferences)
        yesterday_post, liked_topic = await self._yesterday_liked_signal(user_id)
        interactions = await self.interaction_repo.get_recent_interactions(user_id)
        view_time_boosts = self.preference_service.view_time_topic_boosts(
            prefs, interactions
        )

        topic_comp = _composition_dict(prefs.topic_composition)
        post_comp = _composition_dict(prefs.post_composition)
        if diversify:
            topic_comp = {"similar": 0.10, "opposite": 0.25, "surprise": 0.65}
            seed_strategy = "diversify"
        elif yesterday_post:
            seed_strategy = "soft_prior"
        else:
            seed_strategy = "random"

        max_per_topic = _max_per_topic_from_composition(topic_comp)
        anchor_embedding = yesterday_post or self.embedding_service.embed_text(
            liked_topic or "general"
        )
        anchor_topic = liked_topic

        async with self.repo.acquire() as conn:
            candidates = await self._compose_candidates(
                anchor_post_id=None,
                anchor_embedding=anchor_embedding,
                current_topic=anchor_topic,
                topic_composition=topic_comp,
                post_composition=post_comp,
                preferred_topics=preferred_topics,
                blacklisted_topics=blacklisted_topics,
                blocked_user_ids=blocked_user_ids,
                topic_limit=4,
                post_limit=40,
                conn=conn,
            )

            if not candidates:
                random_posts = await self.repo.get_random_posts(
                    limit=40, conn=conn
                )
                candidates = [
                    {**post, "similarity": 0.3, "score": 0.3, "_post_bucket": "surprise"}
                    for post in random_posts
                    if _normalize_topic(post.get("topic")) not in blacklisted_topics
                ]
                if diversify:
                    seed_strategy = "diversify_fallback"
                elif yesterday_post:
                    seed_strategy = "soft_prior_fallback"

        ranked = self.ranking_service.apply_preferences(
            prefs,
            candidates,
            view_time_boosts=view_time_boosts,
            blocked_user_ids=blocked_user_ids,
        )
        selected = self._select_topic_diverse(
            ranked,
            limit=_SESSION_LIMIT,
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
        blocked_user_ids = await self.user_repo.get_blocked_user_ids(user_id)
        preferred_topics, blacklisted_topics = _topic_sets(prefs.topic_preferences)
        interactions = await self.interaction_repo.get_recent_interactions(user_id)
        view_time_boosts = self.preference_service.view_time_topic_boosts(
            prefs, interactions
        )

        topic_comp = _composition_dict(prefs.topic_composition)
        post_comp = _composition_dict(prefs.post_composition)

        async with self.repo.acquire() as conn:
            current_rows = await self.repo.get_posts_by_ids([post_id], conn=conn)
            current_topic_raw = current_rows[0].get("topic") if current_rows else None
            current_topic = _normalize_topic(current_topic_raw)
            anchor_embedding = await self.repo.get_post_embedding(post_id, conn=conn)
            if anchor_embedding is None and current_rows:
                anchor_embedding = self.embedding_service.embed_text(
                    current_rows[0].get("content", "")
                )
            if anchor_embedding is None:
                anchor_embedding = self.embedding_service.embed_text("general")

            candidates = await self._compose_candidates(
                anchor_post_id=post_id,
                anchor_embedding=anchor_embedding,
                current_topic=current_topic_raw,
                topic_composition=topic_comp,
                post_composition=post_comp,
                preferred_topics=preferred_topics,
                blacklisted_topics=blacklisted_topics,
                blocked_user_ids=blocked_user_ids,
                topic_limit=_NEXT_CHOICE_LIMIT,
                post_limit=_NEXT_CHOICE_LIMIT * 2,
                conn=conn,
            )

        ranked = self.ranking_service.apply_preferences(
            prefs,
            candidates,
            view_time_boosts=view_time_boosts,
            blocked_user_ids=blocked_user_ids,
        )
        selected = self._select_next_composition(
            ranked,
            current_topic=current_topic,
            topic_composition=topic_comp,
            post_composition=post_comp,
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

    def _select_next_composition(
        self,
        candidates: list[dict],
        *,
        current_topic: str | None,
        topic_composition: dict[str, float],
        post_composition: dict[str, float],
        limit: int = _NEXT_CHOICE_LIMIT,
    ) -> list[dict]:
        by_post_bucket: dict[str, list[dict]] = {}
        for candidate in sorted(
            candidates, key=lambda p: p.get("score", 0), reverse=True
        ):
            bucket = candidate.get("_post_bucket", PostComposer.BUCKET_SIMILAR)
            by_post_bucket.setdefault(bucket, []).append(candidate)

        post_quotas = weighted_quotas(
            {
                PostComposer.BUCKET_SIMILAR: post_composition.get("similar", 0.0),
                PostComposer.BUCKET_OPPOSITE: post_composition.get("opposite", 0.0),
                PostComposer.BUCKET_SURPRISE: post_composition.get("surprise", 0.0),
            },
            limit,
        )

        max_same_topic = _same_topic_cap(topic_composition, limit)
        selected: list[dict] = []
        selected_ids: set[str] = set()
        same_topic_count = 0

        def try_add(post: dict) -> bool:
            nonlocal same_topic_count
            if len(selected) >= limit:
                return False
            if post["id"] in selected_ids:
                return False
            topic = _normalize_topic(post.get("topic"))
            is_same = bool(current_topic and topic and topic == current_topic)
            if is_same and same_topic_count >= max_same_topic:
                return False
            selected.append(post)
            selected_ids.add(post["id"])
            if is_same:
                same_topic_count += 1
            return True

        for bucket, quota in post_quotas.items():
            taken = 0
            for post in by_post_bucket.get(bucket, []):
                if taken >= quota:
                    break
                if try_add(post):
                    taken += 1

        if len(selected) < limit:
            for post in sorted(candidates, key=lambda p: p.get("score", 0), reverse=True):
                if len(selected) >= limit:
                    break
                try_add(post)

        return selected
