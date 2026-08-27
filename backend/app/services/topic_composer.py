"""Topic-tier candidate selection for the two-tier feed composer."""

from __future__ import annotations

import random
from typing import Any

from app.db.topics import KNOWN_TOPICS
from app.services.composition_utils import weighted_quotas


class TopicComposer:
    BUCKET_SIMILAR = "similar"
    BUCKET_OPPOSITE = "opposite"
    BUCKET_SURPRISE = "surprise"

    def __init__(self, repo, embedding_service):
        self.repo = repo
        self.embedding_service = embedding_service

    async def _anchor_embedding(self, current_topic: str | None, *, conn) -> list[float]:
        if current_topic:
            stored = await self.repo.get_topic_embedding(current_topic, conn=conn)
            if stored is not None:
                return stored
            return self.embedding_service.embed_text(current_topic)
        return self.embedding_service.embed_text("general")

    async def select_topics(
        self,
        current_topic: str | None,
        composition: dict[str, float],
        *,
        blacklisted: set[str],
        preferred: set[str],
        limit: int,
        conn=None,
    ) -> list[tuple[str, str]]:
        """Return (topic_name, bucket) pairs sized to ``limit``."""
        anchor = await self._anchor_embedding(current_topic, conn=conn)
        exclude = set(blacklisted)
        if current_topic:
            exclude.discard(current_topic.casefold())

        quotas = weighted_quotas(
            {
                self.BUCKET_SIMILAR: composition.get("similar", 0.0),
                self.BUCKET_OPPOSITE: composition.get("opposite", 0.0),
                self.BUCKET_SURPRISE: composition.get("surprise", 0.0),
            },
            limit,
        )

        buckets: dict[str, list[str]] = {
            self.BUCKET_SIMILAR: [],
            self.BUCKET_OPPOSITE: [],
            self.BUCKET_SURPRISE: [],
        }

        per_bucket = max(limit, 4)
        if quotas[self.BUCKET_SIMILAR] > 0:
            similar_rows = await self.repo.get_similar_topics(
                anchor,
                per_bucket,
                exclude_topics=list(exclude),
                conn=conn,
            )
            for row in similar_rows:
                topic = row["topic"]
                if topic.casefold() in blacklisted:
                    continue
                buckets[self.BUCKET_SIMILAR].append(topic)
            if current_topic and current_topic.casefold() not in blacklisted:
                if current_topic not in buckets[self.BUCKET_SIMILAR]:
                    buckets[self.BUCKET_SIMILAR].insert(0, current_topic)

        if quotas[self.BUCKET_OPPOSITE] > 0:
            opposite_exclude = list(exclude)
            if current_topic:
                opposite_exclude.append(current_topic.casefold())
            opposite_rows = await self.repo.get_opposite_topics(
                anchor,
                per_bucket,
                exclude_topics=opposite_exclude,
                conn=conn,
            )
            for row in opposite_rows:
                topic = row["topic"]
                if topic.casefold() in blacklisted:
                    continue
                if current_topic and topic.casefold() == current_topic.casefold():
                    continue
                buckets[self.BUCKET_OPPOSITE].append(topic)

        if quotas[self.BUCKET_SURPRISE] > 0:
            surprise_rows = await self.repo.get_random_topics(
                per_bucket,
                exclude_topics=list(blacklisted),
                conn=conn,
            )
            buckets[self.BUCKET_SURPRISE] = [
                row["topic"]
                for row in surprise_rows
                if row["topic"].casefold() not in blacklisted
            ]

        if not any(buckets.values()):
            buckets[self.BUCKET_SURPRISE] = [
                t for t in sorted(KNOWN_TOPICS) if t.casefold() not in blacklisted
            ]

        selected: list[tuple[str, str]] = []
        seen: set[str] = set()

        def take(bucket: str, count: int) -> None:
            pool = buckets[bucket][:]
            random.shuffle(pool)
            taken = 0
            for topic in pool:
                if taken >= count:
                    break
                key = topic.casefold()
                if key in seen or key in blacklisted:
                    continue
                if preferred and key not in preferred and bucket == self.BUCKET_SIMILAR:
                    # Still allow, preferred is a ranking boost downstream.
                    pass
                selected.append((topic, bucket))
                seen.add(key)
                taken += 1

        for bucket, quota in quotas.items():
            take(bucket, quota)

        if len(selected) < limit:
            leftovers: list[tuple[str, str]] = []
            for bucket, topics in buckets.items():
                for topic in topics:
                    key = topic.casefold()
                    if key in seen or key in blacklisted:
                        continue
                    leftovers.append((topic, bucket))
            random.shuffle(leftovers)
            for item in leftovers:
                if len(selected) >= limit:
                    break
                key = item[0].casefold()
                if key in seen:
                    continue
                selected.append(item)
                seen.add(key)

        return selected[:limit]
