"""Score adjustments from per-post feed preferences (-2..+2)."""

from __future__ import annotations

import math
from dataclasses import dataclass


@dataclass(frozen=True)
class FeedPreferenceSignal:
    post_id: str
    feed_preference: int
    embedding: list[float]
    topic: str | None = None


POSITIVE_CENTROID_SCALE = 0.12
NEGATIVE_PENALTY_SCALE = 0.15


def cosine_similarity(left: list[float], right: list[float]) -> float:
    if not left or not right or len(left) != len(right):
        return 0.0
    dot = sum(a * b for a, b in zip(left, right))
    left_norm = math.sqrt(sum(a * a for a in left))
    right_norm = math.sqrt(sum(b * b for b in right))
    if left_norm <= 0.0 or right_norm <= 0.0:
        return 0.0
    return dot / (left_norm * right_norm)


def weighted_centroid(
    signals: list[FeedPreferenceSignal],
    *,
    min_preference: int = 1,
) -> list[float] | None:
    weighted_vectors: list[tuple[list[float], float]] = []
    for signal in signals:
        if signal.feed_preference < min_preference:
            continue
        weight = float(signal.feed_preference)
        weighted_vectors.append((signal.embedding, weight))

    if not weighted_vectors:
        return None

    dimension = len(weighted_vectors[0][0])
    total_weight = sum(weight for _, weight in weighted_vectors)
    if total_weight <= 0.0:
        return None

    centroid = [0.0] * dimension
    for vector, weight in weighted_vectors:
        if len(vector) != dimension:
            continue
        for index, value in enumerate(vector):
            centroid[index] += value * weight

    return [value / total_weight for value in centroid]


def dominant_topic(
    signals: list[FeedPreferenceSignal],
    *,
    min_preference: int = 1,
) -> str | None:
    topic_weights: dict[str, float] = {}
    for signal in signals:
        if signal.feed_preference < min_preference:
            continue
        topic = (signal.topic or "").strip().casefold()
        if not topic:
            continue
        topic_weights[topic] = topic_weights.get(topic, 0.0) + float(
            signal.feed_preference
        )

    if not topic_weights:
        return None
    return max(topic_weights, key=topic_weights.get)


def preference_score_adjustment(
    post_embedding: list[float] | None,
    signals: list[FeedPreferenceSignal],
    *,
    positive_centroid: list[float] | None = None,
) -> float:
    if not post_embedding or not signals:
        return 0.0

    centroid = positive_centroid or weighted_centroid(signals, min_preference=1)
    adjustment = 0.0

    if centroid is not None:
        similarity = max(cosine_similarity(post_embedding, centroid), 0.0)
        adjustment += POSITIVE_CENTROID_SCALE * similarity

    for signal in signals:
        if signal.feed_preference >= 0:
            continue
        similarity = max(cosine_similarity(post_embedding, signal.embedding), 0.0)
        adjustment -= NEGATIVE_PENALTY_SCALE * abs(signal.feed_preference) * similarity

    return adjustment
