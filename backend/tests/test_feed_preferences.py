import datetime
import unittest
from types import SimpleNamespace
from unittest.mock import patch

from app.services.feed import FeedService, PreferenceService, RankingService


def preferences(**overrides):
    values = {
        "topic_preferences": [],
        "use_view_time": False,
        "view_time_weight": 0.1,
        "use_recency": False,
        "randomness": 0.0,
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

    def test_randomness_cannot_outweigh_preferred_topic_bonus(self):
        preferred = SimpleNamespace(topic="science", preference_type="preferred")
        posts = [
            {"id": "preferred", "topic": "science", "score": 0.5},
            {"id": "other", "topic": "sports", "score": 0.5},
        ]

        with patch("app.services.feed.random.random", side_effect=[0.0, 1.0]):
            ranked = RankingService().apply_preferences(
                preferences(topic_preferences=[preferred], randomness=1.0),
                posts,
            )

        self.assertEqual(ranked[0]["id"], "preferred")


class GraphSelectionTests(unittest.TestCase):
    def setUp(self):
        self.service = FeedService(None, None, RankingService(), None, None, None, None, None)

    @staticmethod
    def candidate(post_id, topic, edge_type, score):
        return {
            "id": post_id,
            "topic": topic,
            "_edge_type": edge_type,
            "score": score,
        }

    def test_high_diversity_caps_same_topic_at_one(self):
        candidates = [
            self.candidate("t1", "science", "topic", 1.0),
            self.candidate("t2", "science", "similar", 0.9),
            self.candidate("t3", "science", "bridge", 0.8),
            self.candidate("o1", "sports", "opposite", 0.7),
            self.candidate("r1", "business", "random", 0.6),
        ]

        selected = self.service._select_next_quota(
            candidates,
            current_topic="science",
            diversity_tolerance=1.0,
            strategy_weights={
                "similar": 0.4,
                "graph": 0.25,
                "opposite": 0.2,
                "random": 0.15,
            },
        )

        self.assertLessEqual(
            sum(post["topic"] == "science" for post in selected),
            1,
        )

    def test_low_diversity_allows_three_same_topic_posts(self):
        candidates = [
            self.candidate("t1", "science", "topic", 1.0),
            self.candidate("t2", "science", "topic", 0.9),
            self.candidate("t3", "science", "similar", 0.8),
            self.candidate("o1", "sports", "opposite", 0.7),
        ]

        selected = self.service._select_next_quota(
            candidates,
            current_topic="science",
            diversity_tolerance=0.0,
            strategy_weights={
                "similar": 1.0,
                "graph": 0.0,
                "opposite": 0.0,
                "random": 0.0,
            },
        )

        self.assertEqual(sum(post["topic"] == "science" for post in selected), 3)

    def test_strategy_weights_control_non_topic_quotas(self):
        quotas = self.service._weighted_quotas(
            {"similar": 0.0, "bridge": 0.0, "opposite": 1.0, "random": 0.0},
            4,
        )

        self.assertEqual(quotas["opposite"], 4)
        self.assertEqual(sum(quotas.values()), 4)


if __name__ == "__main__":
    unittest.main()
