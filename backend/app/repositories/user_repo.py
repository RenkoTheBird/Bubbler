from backend.app.main import app
from typing import List
from app.models.post import Post
'''
GOAL: When viewing user profile, retrieve their data
'''

class UserRepository:

    def __init__(self, pool):
        self.pool = pool
    
    async def getProfileInfo(self, id: str):

        async with self.pool.acquire() as conn:
            data = await conn.fetch(
                """SELECT * FROM users WHERE id = $1""", id
            )

        return data

    '''
    GOAL: allow user to change their email
    '''
    async def putEmail(self, email: str, id: str):

        async with self.pool.acquire() as conn:
            data = await conn.fetch(
                """UPDATE users SET email = $1 WHERE id = $2""", email, id
            )

        return data
