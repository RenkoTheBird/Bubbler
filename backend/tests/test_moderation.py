import datetime
import unittest
from unittest.mock import AsyncMock, patch
from uuid import uuid4

from fastapi import HTTPException
from pydantic import ValidationError

from app.repositories.moderation_repo import (
    AccountAccess,
    CannotRestrictStaff,
    InvalidRestrictAction,
    ModerationRepository,
    UserNotFound,
)
from app.schemas.moderation import AccountRestrictRequest
from app.services.auth import AuthService
from app.services.moderation import ModerationService


class AccountRestrictSchemaTests(unittest.TestCase):
    def test_suspend_accepts_optional_days(self):
        body = AccountRestrictRequest(action="suspend", suspension_days=7)
        self.assertEqual(body.suspension_days, 7)

    def test_ban_rejects_suspension_days(self):
        with self.assertRaises(ValidationError):
            AccountRestrictRequest(action="ban", suspension_days=7)


class ModerationServiceTests(unittest.IsolatedAsyncioTestCase):
    def setUp(self):
        self.repo = AsyncMock(spec=ModerationRepository)
        self.service = ModerationService(self.repo)

    async def test_restrict_self_is_400(self):
        body = AccountRestrictRequest(action="suspend", suspension_days=3)
        with self.assertRaises(HTTPException) as raised:
            await self.service.restrict_account(7, 7, body)
        self.assertEqual(raised.exception.status_code, 400)

    async def test_restrict_missing_user_is_404(self):
        self.repo.restrict_account.side_effect = UserNotFound
        body = AccountRestrictRequest(action="ban")
        with self.assertRaises(HTTPException) as raised:
            await self.service.restrict_account(1, 9, body)
        self.assertEqual(raised.exception.status_code, 404)

    async def test_restrict_staff_is_403(self):
        self.repo.restrict_account.side_effect = CannotRestrictStaff
        body = AccountRestrictRequest(action="ban")
        with self.assertRaises(HTTPException) as raised:
            await self.service.restrict_account(1, 2, body)
        self.assertEqual(raised.exception.status_code, 403)

    async def test_restrict_returns_current_status(self):
        sanction_id = uuid4()
        sanction = unittest.mock.Mock()
        sanction.id = sanction_id
        self.repo.restrict_account.return_value = sanction
        self.repo.resolve_account_access.return_value = AccountAccess(
            user_id=9,
            account_status="suspended",
            restricted_until=datetime.datetime.now(datetime.timezone.utc),
            public_message=None,
        )
        body = AccountRestrictRequest(action="suspend", suspension_days=5)

        result = await self.service.restrict_account(1, 9, body)

        self.assertEqual(result.user_id, 9)
        self.assertEqual(result.account_status, "suspended")
        self.assertEqual(result.sanction_id, sanction_id)

    async def test_unsuspend_invalid_state_is_400(self):
        self.repo.restrict_account.side_effect = InvalidRestrictAction
        body = AccountRestrictRequest(action="unsuspend")
        with self.assertRaises(HTTPException) as raised:
            await self.service.restrict_account(1, 9, body)
        self.assertEqual(raised.exception.status_code, 400)


class AuthServiceEnforcementTests(unittest.IsolatedAsyncioTestCase):
    def setUp(self):
        self.auth_repo = AsyncMock()
        self.moderation_repo = AsyncMock()
        self.service = AuthService(
            self.auth_repo,
            self.moderation_repo,
            "secret",
            "HS256",
            24,
        )

    async def test_login_rejects_banned_account(self):
        self.auth_repo.post_login_info.return_value = {
            "id": 9,
            "password": "hashed",
        }
        with patch("app.services.auth.check_password", return_value=True):
            self.moderation_repo.resolve_account_access.return_value = AccountAccess(
                user_id=9,
                account_status="banned",
                restricted_until=None,
                public_message="Policy violation",
            )
            with self.assertRaises(HTTPException) as raised:
                await self.service.post_login_info("user@example.com", "secret")
        self.assertEqual(raised.exception.status_code, 403)
        self.assertEqual(raised.exception.detail, "Policy violation")

    async def test_register_rejects_blocked_identity(self):
        self.moderation_repo.is_identity_blocked.return_value = True
        with self.assertRaises(HTTPException) as raised:
            await self.service.post_registration_info(
                "newuser",
                "blocked@example.com",
                "password",
                datetime.date(1990, 1, 1),
            )
        self.assertEqual(raised.exception.status_code, 409)
        self.assertEqual(raised.exception.detail, "username or email already taken")
