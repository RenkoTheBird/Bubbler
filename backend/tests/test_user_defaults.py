import datetime
import unittest
from contextlib import asynccontextmanager
from unittest.mock import AsyncMock, MagicMock

from app.repositories.auth_repo import AuthRepository
from app.schemas.user import default_user_prefs


class DefaultUserPrefsTests(unittest.TestCase):
    def test_conservative_launch_defaults(self):
        prefs = default_user_prefs(user_id=42)

        self.assertEqual(prefs.user_id, 42)
        self.assertEqual(prefs.feed_preset, "stay_in_lane")
        self.assertEqual(prefs.topic_preferences, [])
        self.assertFalse(prefs.use_view_time)
        self.assertFalse(prefs.use_recency)
        self.assertFalse(prefs.ai_topic_detection)
        self.assertAlmostEqual(prefs.topic_composition.similar, 0.55)
        self.assertAlmostEqual(prefs.topic_composition.opposite, 0.15)
        self.assertAlmostEqual(prefs.topic_composition.surprise, 0.30)
        self.assertEqual(
            prefs.post_composition.as_dict(),
            prefs.topic_composition.as_dict(),
        )


class AuthRepositoryRegistrationTests(unittest.IsolatedAsyncioTestCase):
    def setUp(self):
        self.conn = AsyncMock()
        self.transaction = AsyncMock()
        self.transaction.__aenter__ = AsyncMock(return_value=None)
        self.transaction.__aexit__ = AsyncMock(return_value=None)
        self.conn.transaction = MagicMock(return_value=self.transaction)
        self.conn.fetchval = AsyncMock(return_value=99)
        self.conn.execute = AsyncMock()

        self.pool = MagicMock()

        @asynccontextmanager
        async def _acquire():
            yield self.conn

        self.pool.acquire = _acquire
        self.repo = AuthRepository(self.pool)

    async def test_registration_inserts_user_profiles_with_conservative_defaults(self):
        user_id = await self.repo.post_registration_info(
            "newbie",
            "newbie@example.com",
            "hashed-password",
            datetime.date(1990, 6, 15),
        )

        self.assertEqual(user_id, 99)
        self.conn.transaction.assert_called_once()
        self.conn.execute.assert_called_once()

        sql = self.conn.execute.call_args[0][0]
        self.assertIn("INSERT INTO user_profiles", sql)

        args = self.conn.execute.call_args[0][1:]
        self.assertEqual(args[0], 99)
        self.assertEqual(args[1], "stay_in_lane")
        self.assertEqual(args[4], False)  # use_view_time
        self.assertEqual(args[6], False)  # use_recency
        self.assertEqual(args[7], False)  # ai_topic_detection
