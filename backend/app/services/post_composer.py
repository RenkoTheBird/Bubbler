"""Post-tier candidate selection within a topic bucket."""

from __future__ import annotations

import random
from typing import Any

from app.services.composition_utils import weighted_quotas

_GRAPH_EDGE_TYPES = frozenset({"similar", "topic", "bridge"})


class PostComposer:
    BUCKET_SIMILAR = "similar"
    BUCKET_OPPOSITE = "opposite"
    BUCKET_SURPRISE = "surprise"
    SURPRISE_JITTER = 0.15

    def __init__(self, repo):
        self.repo = repo

    async def select_posts_for_topic(
        self,
        topic: str,
        anchor_post_id: str,
        anchor_embedding: list[float],
        composition: dict[str, float],
        *,
        topic_bucket: str,
        blacklisted_user_ids: set[int],
        limit: int,
        conn=None,
    ) -> list[dict[str, Any]]:
        quotas = weighted_quotas(
            {
                self.BUCKET_SIMILAR: composition.get("similar", 0.0),
                self.BUCKET_OPPOSITE: composition.get("opposite", 0.0),
                self.BUCKET_SURPRISE: composition.get("surprise", 0.0),
            },
            limit,
        )

        per_bucket = max(limit, 4)
        buckets: dict[str, list[dict[str, Any]]] = {
            self.BUCKET_SIMILAR: [],
            self.BUCKET_OPPOSITE: [],
            self.BUCKET_SURPRISE: [],
        }

        if quotas[self.BUCKET_SIMILAR] > 0:
            similar_posts = await self.repo.get_posts_by_embedding_in_topic(
                anchor_embedding,
                topic,
                per_bucket,
                ascending=True,
                conn=conn,
            )
            for post in similar_posts:
                if post.get("user_id") in blacklisted_user_ids:
                    continue
                if post["id"] == anchor_post_id:
                    continue
                post["_post_bucket"] = self.BUCKET_SIMILAR
                post["_topic_bucket"] = topic_bucket
                buckets[self.BUCKET_SIMILAR].append(post)

            edges = await self.repo.get_outbound_edges_by_type(
                anchor_post_id, conn=conn
            )
            if edges:
                target_ids = [
                    edge.to_post_id
                    for edge in edges
                    if edge.type in _GRAPH_EDGE_TYPES
                ]
                graph_posts = await self.repo.get_posts_by_ids(target_ids, conn=conn)
                posts_by_id = {post["id"]: post for post in graph_posts}
                for edge in edges:
                    if edge.type not in _GRAPH_EDGE_TYPES:
                        continue
                    post = posts_by_id.get(edge.to_post_id)
                    if not post:
                        continue
                    post_topic = post.get("topic")
                    if not isinstance(post_topic, str) or post_topic.casefold() != topic.casefold():
                        continue
                    if post.get("user_id") in blacklisted_user_ids:
                        continue
                    if post["id"] == anchor_post_id:
                        continue
                    enriched = dict(post)
                    enriched["similarity"] = float(edge.weight or 0.0)
                    enriched["_post_bucket"] = self.BUCKET_SIMILAR
                    enriched["_topic_bucket"] = topic_bucket
                    buckets[self.BUCKET_SIMILAR].append(enriched)

        if quotas[self.BUCKET_OPPOSITE] > 0:
            opposite_posts = await self.repo.get_posts_by_embedding_in_topic(
                anchor_embedding,
                topic,
                per_bucket,
                ascending=False,
                conn=conn,
            )
            for post in opposite_posts:
                if post.get("user_id") in blacklisted_user_ids:
                    continue
                if post["id"] == anchor_post_id:
                    continue
                post["_post_bucket"] = self.BUCKET_OPPOSITE
                post["_topic_bucket"] = topic_bucket
                buckets[self.BUCKET_OPPOSITE].append(post)

        if quotas[self.BUCKET_SURPRISE] > 0:
            surprise_posts = await self.repo.get_random_posts_in_topic(
                topic, per_bucket, conn=conn
            )
            for post in surprise_posts:
                if post.get("user_id") in blacklisted_user_ids:
                    continue
                if post["id"] == anchor_post_id:
                    continue
                enriched = dict(post)
                enriched["similarity"] = 0.5
                enriched["score"] = 0.5 + random.random() * self.SURPRISE_JITTER
                enriched["_post_bucket"] = self.BUCKET_SURPRISE
                enriched["_topic_bucket"] = topic_bucket
                buckets[self.BUCKET_SURPRISE].append(enriched)

        selected: list[dict[str, Any]] = []
        seen: set[str] = set()

        def score_post(post: dict[str, Any], bucket: str) -> float:
            similarity = float(post.get("similarity", 0.0))
            if bucket == self.BUCKET_OPPOSITE:
                return (1.0 - similarity) / 2.0
            if bucket == self.BUCKET_SURPRISE:
                return float(post.get("score", 0.5))
            return max(similarity, 0.0)

        def take(bucket: str, count: int) -> None:
            pool = sorted(
                buckets[bucket],
                key=lambda p: score_post(p, bucket),
                reverse=True,
            )
            taken = 0
            for post in pool:
                if taken >= count:
                    break
                post_id = post["id"]
                if post_id in seen:
                    continue
                post["score"] = score_post(post, bucket)
                selected.append(post)
                seen.add(post_id)
                taken += 1

        for bucket, quota in quotas.items():
            take(bucket, quota)

        if len(selected) < limit:
            leftovers = []
            for bucket, posts in buckets.items():
                for post in posts:
                    if post["id"] not in seen:
                        leftovers.append((post, bucket))
            leftovers.sort(key=lambda item: score_post(item[0], item[1]), reverse=True)
            for post, bucket in leftovers:
                if len(selected) >= limit:
                    break
                if post["id"] in seen:
                    continue
                post["score"] = score_post(post, bucket)
                selected.append(post)
                seen.add(post["id"])

        return selected[:limit]

    async def select_posts_for_topics(
        self,
        topic_selections: list[tuple[str, str]],
        anchor_post_id: str,
        anchor_embedding: list[float],
        composition: dict[str, float],
        *,
        blacklisted_user_ids: set[int],
        limit: int,
        conn=None,
    ) -> list[dict[str, Any]]:
        if not topic_selections:
            return []

        per_topic = max(1, limit // len(topic_selections))
        merged: list[dict[str, Any]] = []
        seen: set[str] = set()

        for topic, topic_bucket in topic_selections:
            posts = await self.select_posts_for_topic(
                topic,
                anchor_post_id,
                anchor_embedding,
                composition,
                topic_bucket=topic_bucket,
                blacklisted_user_ids=blacklisted_user_ids,
                limit=per_topic + 1,
                conn=conn,
            )
            for post in posts:
                if post["id"] in seen:
                    continue
                seen.add(post["id"])
                merged.append(post)

        merged.sort(key=lambda p: p.get("score", 0.0), reverse=True)
        return merged[: limit * 2]
