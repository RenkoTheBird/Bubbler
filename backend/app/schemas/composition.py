"""Feed composition presets and weight helpers for the two-tier recommender."""

from __future__ import annotations

from typing import Literal

from pydantic import BaseModel, Field, model_validator

FeedPresetId = Literal["stay_in_lane", "cross_pollinate", "wild_walk", "custom"]

DEFAULT_COMPOSITION: dict[str, float] = {
    "similar": 0.55,
    "opposite": 0.15,
    "surprise": 0.30,
}

FEED_PRESETS: dict[str, dict[str, dict[str, float]]] = {
    "stay_in_lane": {
        "topic_composition": {"similar": 0.55, "opposite": 0.15, "surprise": 0.30},
        "post_composition": {"similar": 0.55, "opposite": 0.15, "surprise": 0.30},
    },
    "cross_pollinate": {
        "topic_composition": {"similar": 0.15, "opposite": 0.55, "surprise": 0.30},
        "post_composition": {"similar": 0.55, "opposite": 0.15, "surprise": 0.30},
    },
    "wild_walk": {
        "topic_composition": {"similar": 0.15, "opposite": 0.25, "surprise": 0.60},
        "post_composition": {"similar": 0.15, "opposite": 0.25, "surprise": 0.60},
    },
}

PRESET_MATCH_EPSILON = 0.02


class CompositionWeights(BaseModel):
    similar: float = DEFAULT_COMPOSITION["similar"]
    opposite: float = DEFAULT_COMPOSITION["opposite"]
    surprise: float = DEFAULT_COMPOSITION["surprise"]

    @model_validator(mode="after")
    def clamp_values(self):
        self.similar = _clamp(self.similar)
        self.opposite = _clamp(self.opposite)
        self.surprise = _clamp(self.surprise)
        return self

    @property
    def total(self) -> float:
        return self.similar + self.opposite + self.surprise

    def normalized(self) -> CompositionWeights:
        clamped = CompositionWeights(
            similar=_clamp(self.similar),
            opposite=_clamp(self.opposite),
            surprise=_clamp(self.surprise),
        )
        total = clamped.total
        if total <= 0:
            return CompositionWeights(**DEFAULT_COMPOSITION)
        return CompositionWeights(
            similar=clamped.similar / total,
            opposite=clamped.opposite / total,
            surprise=clamped.surprise / total,
        )

    def as_dict(self) -> dict[str, float]:
        normalized = self.normalized()
        return {
            "similar": normalized.similar,
            "opposite": normalized.opposite,
            "surprise": normalized.surprise,
        }


def _clamp(value: float) -> float:
    return min(max(float(value), 0.0), 1.0)


def preset_compositions(preset_id: str) -> tuple[dict[str, float], dict[str, float]]:
    preset = FEED_PRESETS.get(preset_id, FEED_PRESETS["stay_in_lane"])
    return dict(preset["topic_composition"]), dict(preset["post_composition"])


def detect_preset(
    topic_composition: dict[str, float],
    post_composition: dict[str, float],
) -> FeedPresetId:
    topic = CompositionWeights(**topic_composition).normalized()
    post = CompositionWeights(**post_composition).normalized()
    for preset_id in ("stay_in_lane", "cross_pollinate", "wild_walk"):
        preset_topic, preset_post = preset_compositions(preset_id)
        pt = CompositionWeights(**preset_topic).normalized()
        pp = CompositionWeights(**preset_post).normalized()
        if (
            _distance(topic, pt) <= PRESET_MATCH_EPSILON
            and _distance(post, pp) <= PRESET_MATCH_EPSILON
        ):
            return preset_id  # type: ignore[return-value]
    return "custom"


def _distance(left: CompositionWeights, right: CompositionWeights) -> float:
    return (
        abs(left.similar - right.similar)
        + abs(left.opposite - right.opposite)
        + abs(left.surprise - right.surprise)
    )


def migrate_legacy_prefs(
    *,
    diversity_tolerance: float | None,
    randomness: float | None,
    strategy_weights: dict[str, float] | None,
) -> tuple[str, dict[str, float], dict[str, float]]:
    """Map legacy flat strategy prefs to two-tier composition + nearest preset."""
    diversity = _clamp(float(diversity_tolerance or 0.4))
    rand = _clamp(float(randomness or 0.4))
    weights = strategy_weights or {}
    similar = float(weights.get("similar", 0.4))
    graph = float(weights.get("graph", 0.25))
    opposite = float(weights.get("opposite", 0.2))
    random_w = float(weights.get("random", 0.15))

    surprise_raw = 0.4 * diversity + 0.4 * rand + 0.2 * random_w
    similar_raw = similar + 0.5 * graph
    opposite_raw = opposite

    total = similar_raw + opposite_raw + surprise_raw
    if total <= 0:
        composition = dict(DEFAULT_COMPOSITION)
    else:
        composition = {
            "similar": similar_raw / total,
            "opposite": opposite_raw / total,
            "surprise": surprise_raw / total,
        }

    preset = detect_preset(composition, composition)
    if preset != "custom":
        topic, post = preset_compositions(preset)
        return preset, topic, post
    return "custom", composition, composition
