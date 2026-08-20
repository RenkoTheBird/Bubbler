import unittest
from unittest.mock import AsyncMock

from fastapi import HTTPException

from app.deps import create_require_staff


class RequireStaffTests(unittest.IsolatedAsyncioTestCase):
    def setUp(self):
        self.repo = AsyncMock()
        self.require_staff = create_require_staff(self.repo)

    async def test_staff_user_passes(self):
        self.repo.is_staff.return_value = True

        user_id = await self.require_staff(user_id=7)

        self.assertEqual(user_id, 7)
        self.repo.is_staff.assert_awaited_once_with(7)

    async def test_non_staff_is_403(self):
        self.repo.is_staff.return_value = False

        with self.assertRaises(HTTPException) as raised:
            await self.require_staff(user_id=7)

        self.assertEqual(raised.exception.status_code, 403)
        self.assertEqual(raised.exception.detail, "Staff access required")
