from fastapi import HTTPException

from app.services.auth import check_password, hash_password


class UserService:
    def __init__(self, user_repo):
        self.user_repo = user_repo
        
    async def get_profile_info(self, user_id: int):
        profile = await self.user_repo.get_profile_info(user_id)
        if profile is None:
            raise HTTPException(status_code=404, detail="User not found")
        return profile

    async def get_profile_by_username(self, username: str, viewer_id: int | None = None):
        profile = await self.user_repo.get_profile_by_username(
            username,
            viewer_id=viewer_id,
        )
        if profile is None:
            raise HTTPException(status_code=404, detail="User not found")
        return profile

    async def put_email(self, email, user_id):
        updated = await self.user_repo.put_email(email, user_id)
        if updated is None:
            raise HTTPException(status_code=404, detail="User not found")
        return updated

    async def put_password(self, body, user_id: int):
        row = await self.user_repo.get_password_credentials(user_id)
        if row is None:
            raise HTTPException(status_code=404, detail="User not found")

        identity = body.email_or_username.strip().casefold()
        email_matches = row["email"].casefold() == identity
        username_matches = row["username"].casefold() == identity
        if not email_matches and not username_matches:
            raise HTTPException(
                status_code=400,
                detail="Email or username does not match this account",
            )

        if not check_password(body.current_password, row["password"]):
            # Use 400 (not 401) so clients don't treat this as an expired session.
            raise HTTPException(status_code=400, detail="Incorrect password")

        if check_password(body.new_password, row["password"]):
            raise HTTPException(
                status_code=400,
                detail="New password must be different from your current password",
            )

        updated = await self.user_repo.put_password(
            hash_password(body.new_password),
            user_id,
        )
        if not updated:
            raise HTTPException(status_code=404, detail="User not found")
        return {"detail": "Password updated"}
    
    async def get_prefs(self, user_id):
        return await self.user_repo.get_prefs(user_id)
    
    async def put_prefs(self, user_id, body):
        return await self.user_repo.put_prefs(user_id, body)

    async def list_blocked_users(self, user_id: int):
        return await self.user_repo.list_blocked_users(user_id)

    async def block_user(self, blocker_id: int, username: str):
        blocked_id = await self.user_repo.resolve_user_id_by_username(username)
        if blocked_id is None:
            raise HTTPException(status_code=404, detail="User not found")
        if blocked_id == blocker_id:
            raise HTTPException(status_code=400, detail="You cannot block yourself")

        await self.user_repo.block_user(blocker_id, blocked_id)
        return await self.get_profile_by_username(username, viewer_id=blocker_id)

    async def unblock_user(self, blocker_id: int, username: str):
        blocked_id = await self.user_repo.resolve_user_id_by_username(username)
        if blocked_id is None:
            raise HTTPException(status_code=404, detail="User not found")

        removed = await self.user_repo.unblock_user(blocker_id, blocked_id)
        if not removed:
            raise HTTPException(status_code=404, detail="User is not blocked")
        return await self.get_profile_by_username(username, viewer_id=blocker_id)

    async def delete_user(self, user_id):
        result = await self.user_repo.delete_user(user_id)
        if not result:
            raise HTTPException(status_code=404, detail="User not found")
        return result

    async def export_user_data(self, user_id: int):
        export = await self.user_repo.export_user_data(user_id)
        if export is None:
            raise HTTPException(status_code=404, detail="User not found")
        return export
