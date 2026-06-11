from ..db.base import pool
'''
    GOAL: When viewing user profile, retrieve their data
    '''

class UserRepository:
    
    async def getProfileInfo(self, id: int):

        async with pool.acquire() as conn:
            data = await conn.fetch(
                """SELECT * FROM users WHERE id = $1""", id
            )

        return data

    '''
    GOAL: allow user to change their email
    '''
    async def putEmail(self, email: str, id: int):

        async with pool.acquire() as conn:
            data = await conn.fetch(
                """UPDATE users SET email = $1 WHERE id = $2""", email, id
            )

        return data
