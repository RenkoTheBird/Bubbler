from uuid import UUID

from fastapi import HTTPException

from app.repositories.moderation_repo import (
    CannotRestrictStaff,
    InvalidRestrictAction,
    ModerationRepository,
    PostNotFound,
    UserNotFound,
)
from app.schemas.moderation import AccountRestrictRequest, AccountRestrictResult


class ModerationService:
    def __init__(self, moderation_repo: ModerationRepository):
        self.moderation_repo = moderation_repo

    async def restrict_account(
        self,
        staff_id: int,
        user_id: int,
        body: AccountRestrictRequest,
    ) -> AccountRestrictResult:
        if staff_id == user_id:
            raise HTTPException(
                status_code=400,
                detail="You cannot restrict your own account",
            )

        try:
            sanction = await self.moderation_repo.restrict_account(
                staff_id=staff_id,
                user_id=user_id,
                action=body.action,
                reason_code=body.reason_code,
                staff_note=body.staff_note,
                public_message=body.public_message,
                suspension_days=body.suspension_days,
                report_id=body.report_id,
            )
        except UserNotFound:
            raise HTTPException(status_code=404, detail="User not found") from None
        except CannotRestrictStaff:
            raise HTTPException(
                status_code=403,
                detail="Staff accounts cannot be restricted",
            ) from None
        except InvalidRestrictAction:
            raise HTTPException(
                status_code=400,
                detail=f"Cannot {body.action} this account in its current state",
            ) from None

        access = await self.moderation_repo.resolve_account_access(user_id)
        return AccountRestrictResult(
            user_id=user_id,
            account_status=access.account_status if access else "active",
            restricted_until=access.restricted_until if access else None,
            sanction_id=sanction.id,
        )

    async def remove_post(
        self,
        staff_id: int,
        post_id: UUID,
        *,
        reason_code: str | None = None,
        staff_note: str | None = None,
        public_message: str | None = None,
        report_id: UUID | None = None,
    ) -> None:
        try:
            await self.moderation_repo.staff_remove_post(
                staff_id=staff_id,
                post_id=post_id,
                reason_code=reason_code,
                staff_note=staff_note,
                public_message=public_message,
                report_id=report_id,
            )
        except PostNotFound:
            raise HTTPException(status_code=404, detail="Post not found") from None
