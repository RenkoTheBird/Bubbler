import datetime
import unittest
from types import SimpleNamespace

from app.services.composition_utils import weighted_quotas
from app.services.feed import FeedService, PreferenceService, RankingService
from app.services.feed_preference_scoring import FeedPreferenceSignal, weighted_centroid, preference_score_adjustment
from app.services.post_composer import PostComposer


def preferences(**overrides):
    values = {
        "topic_preferences": [],
        "use_view_time": False,
        "view_time_weight": 0.1,
        "use_recency": False,
    }
    values.update(overrides)
    return SimpleNamespace(**values)


class PreferenceServiceTests(unittest.TestCase):
    def test_view_time_boosts_are_bounded_and_weighted(self):
        interactions = [
            SimpleNamespace(topic="Science", view_time=120),
            SimpleNamespace(topic="science", view_time=30),
            SimpleNamespace(topic="Sports", view_time=10),
        ]

        boosts = PreferenceService().view_time_topic_boosts(
            preferences(use_view_time=True, view_time_weight=0.5),
            interactions,
        )

        self.assertAlmostEqual(boosts["science"], 0.15)
        self.assertGreater(boosts["science"], boosts["sports"])

    def test_view_time_disabled_has_no_boosts(self):
        boosts = PreferenceService().view_time_topic_boosts(
            preferences(use_view_time=False),
            [SimpleNamespace(topic="science", view_time=120)],
        )

        self.assertEqual(boosts, {})


class RankingServiceTests(unittest.TestCase):
    def test_preference_ranking_preserves_strategy_score(self):
        posts = [
            {"id": "strong", "topic": "science", "score": 0.8, "similarity": 0.1},
            {"id": "weak", "topic": "sports", "score": 0.2, "similarity": 0.9},
        ]

        ranked = RankingService().apply_preferences(preferences(), posts)

        self.assertEqual([post["id"] for post in ranked], ["strong", "weak"])

    def test_recency_bonus_is_added_when_enabled(self):
        now = datetime.datetime.now(datetime.timezone.utc)
        posts = [
            {"id": "old", "topic": "science", "score": 0.4, "created_at": now - datetime.timedelta(days=30)},
            {"id": "new", "topic": "science", "score": 0.4, "created_at": now},
        ]

        ranked = RankingService().apply_preferences(
            preferences(use_recency=True),
            posts,
        )

        self.assertEqual(ranked[0]["id"], "new")

    def test_preferred_topic_bonus_wins_tie(self):
        preferred = SimpleNamespace(topic="science", preference_type="preferred")
        posts = [
            {"id": "preferred", "topic": "science", "score": 0.5},
            {"id": "other", "topic": "sports", "score": 0.5},
        ]

        ranked = RankingService().apply_preferences(
            preferences(topic_preferences=[preferred]),
            posts,
        )

        self.assertEqual(ranked[0]["id"], "preferred")


class GraphSelectionTests(unittest.TestCase):
    def setUp(self):
        self.service = FeedService(
            None, None, RankingService(), None, None, None, None, None, None
        )

    @staticmethod
    def candidate(post_id, topic, post_bucket, score):
        return {
            "id": post_id,
            "topic": topic,
            "_post_bucket": post_bucket,
            "score": score,
        }

    def test_high_surprise_caps_same_topic_at_one(self):
        candidates = [
            self.candidate("t1", "science", PostComposer.BUCKET_SIMILAR, 1.0),
            self.candidate("t2", "science", PostComposer.BUCKET_SIMILAR, 0.9),
            self.candidate("t3", "science", PostComposer.BUCKET_SIMILAR, 0.8),
            self.candidate("o1", "sports", PostComposer.BUCKET_OPPOSITE, 0.7),
            self.candidate("r1", "business", PostComposer.BUCKET_SURPRISE, 0.6),
        ]

        selected = self.service._select_next_composition(
            candidates,
            current_topic="science",
            topic_composition={"similar": 0.15, "opposite": 0.25, "surprise": 0.60},
            post_composition={"similar": 0.15, "opposite": 0.25, "surprise": 0.60},
        )

        self.assertLessEqual(
            sum(post["topic"] == "science" for post in selected),
            1,
        )

    def test_high_similar_allows_three_same_topic_posts(self):
        candidates = [
            self.candidate("t1", "science", PostComposer.BUCKET_SIMILAR, 1.0),
            self.candidate("t2", "science", PostComposer.BUCKET_SIMILAR, 0.9),
            self.candidate("t3", "science", PostComposer.BUCKET_SIMILAR, 0.8),
            self.candidate("o1", "sports", PostComposer.BUCKET_OPPOSITE, 0.7),
        ]

        selected = self.service._select_next_composition(
            candidates,
            current_topic="science",
            topic_composition={"similar": 0.55, "opposite": 0.15, "surprise": 0.30},
            post_composition={"similar": 1.0, "opposite": 0.0, "surprise": 0.0},
        )

        self.assertEqual(sum(post["topic"] == "science" for post in selected), 3)

    def test_post_composition_controls_bucket_quotas(self):
        quotas = weighted_quotas(
            {"similar": 0.0, "opposite": 1.0, "surprise": 0.0},
            4,
        )

        self.assertEqual(quotas["opposite"], 4)
        self.assertEqual(sum(quotas.values()), 4)


class FeedPreferenceScoringTests(unittest.TestCase):
    def _vector(self, value: float) -> list[float]:
        return [value, 0.0, 0.0]

    def test_weighted_centroid_uses_positive_preferences_only(self):
        signals = [
            FeedPreferenceSignal("a", 2, self._vector(1.0)),
            FeedPreferenceSignal("b", -2, self._vector(-1.0)),
        ]
        centroid = weighted_centroid(signals, min_preference=1)
        self.assertEqual(centroid, self._vector(1.0))

    def test_preference_score_adjustment_boosts_similar_positive_centroid(self):
        signals = [FeedPreferenceSignal("a", 2, self._vector(1.0))]
        centroid = weighted_centroid(signals)
        adjustment = preference_score_adjustment(
            self._vector(1.0),
            signals,
            positive_centroid=centroid,
        )
        self.assertGreater(adjustment, 0.0)

    def test_preference_score_adjustment_penalizes_similar_negative_posts(self):
        signals = [FeedPreferenceSignal("a", -2, self._vector(1.0))]
        adjustment = preference_score_adjustment(self._vector(1.0), signals)
        self.assertLess(adjustment, 0.0)

    def test_ranking_service_applies_feed_preference_adjustment(self):
        signals = [FeedPreferenceSignal("seed", 2, [1.0, 0.0, 0.0])]
        posts = [
            {"id": "near", "topic": "science", "score": 0.5},
            {"id": "far", "topic": "science", "score": 0.5},
        ]
        embeddings = {
            "near": [1.0, 0.0, 0.0],
            "far": [0.0, 1.0, 0.0],
        }

        ranked = RankingService().apply_preferences(
            preferences(),
            posts,
            feed_preference_signals=signals,
            post_embeddings=embeddings,
        )

        self.assertEqual(ranked[0]["id"], "near")
        self.assertGreater(ranked[0]["score"], ranked[1]["score"])


if __name__ == "__main__":
    unittest.main()
